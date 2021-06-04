import ballerina/websubhub;
import ballerina/log;
import ballerina/http;
import ballerinax/kafka;

isolated map<string> registeredTopics = {};
isolated map<boolean> subscribers = {};
configurable boolean securityOn = ?;

websubhub:Service hubService = service object {
    # Registers a `topic` in the hub.
    # 
    # + message - Details related to the topic-registration
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:TopicRegistrationSuccess` if topic registration is successful, `websubhub:TopicRegistrationError`
    #            if topic registration failed or `error` if there is any unexpected error
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message, http:Headers headers)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error {
        if (securityOn) {
            check authorize(headers, ["register_topic"]);
        }
        check self.registerTopic(message);
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    isolated function registerTopic(websubhub:TopicRegistration message) returns websubhub:TopicRegistrationError? {
        log:printInfo("Received topic-registration request ", request = message);
        string topicName = generateTopicName(message.topic);
        lock {
            if (registeredTopics.hasKey(topicName)) {
                return error websubhub:TopicRegistrationError("Topic has already registered with the Hub");
            }
            registeredTopics[topicName] = message.topic;
        }
        error? persistingResult = persistTopicRegistrations(message);
        if (persistingResult is error) {
            log:printError("Error occurred while persisting the topic-registration ", err = persistingResult.message());
        }
    }

    # Deregisters a `topic` in the hub.
    # 
    # + message - Details related to the topic-deregistration
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:TopicDeregistrationSuccess` if topic deregistration is successful, `websubhub:TopicDeregistrationError`
    #            if topic deregistration failed or `error` if there is any unexpected error
    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message, http:Headers headers)
                        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError|error {
        if (securityOn) {
            check authorize(headers, ["deregister_topic"]);
        }
        self.deregisterTopic(message);
        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    isolated function deregisterTopic(websubhub:TopicRegistration message) {
        log:printInfo("Received topic-deregistration request ", request = message);
        string topicName = generateTopicName(message.topic);
        lock {
            if (registeredTopics.hasKey(topicName)) {
                string removedTopic = registeredTopics.remove(topicName);
            }
        }
        error? persistingResult = persistTopicDeregistration(message);
        if (persistingResult is error) {
            log:printError("Error occurred while persisting the topic-deregistration ", err = persistingResult.message());
        }
    }

    # Publishes content to the hub.
    # 
    # + message - Details of the published content
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:Acknowledgement` if publish content is successful, `websubhub:UpdateMessageError`
    #            if publish content failed or `error` if there is any unexpected error
    isolated remote function onUpdateMessage(websubhub:UpdateMessage message, http:Headers headers)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError|error {  
        if (securityOn) {
            check authorize(headers, ["update_content"]);
        }
        check self.updateMessage(message);
        return websubhub:ACKNOWLEDGEMENT;
    }

    isolated function updateMessage(websubhub:UpdateMessage msg) returns websubhub:UpdateMessageError? {
        log:printInfo("Received content-update request ", request = msg.toString());
        string topicName = generateTopicName(msg.hubTopic);
        boolean isTopicAvailable = false;
        lock {
            isTopicAvailable = registeredTopics.hasKey(topicName);
        }
        if (isTopicAvailable) {
            error? errorResponse = publishContent(msg, topicName);
            if (errorResponse is websubhub:UpdateMessageError) {
                return errorResponse;
            } else if (errorResponse is error) {
                log:printError("Error occurred while publishing the content ", errorMessage = errorResponse.message());
                return error websubhub:UpdateMessageError(errorResponse.message());
            }
        } else {
            return error websubhub:UpdateMessageError("Topic [" + msg.hubTopic + "] is not registered with the Hub");
        }
    }
    
    # Subscribes a consumer to the hub.
    # 
    # + message - Details of the subscription
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:SubscriptionAccepted` if subscription is accepted from the hub, `websubhub:BadSubscriptionError`
    #            if subscription is denied from the hub or `error` if there is any unexpected error
    isolated remote function onSubscription(websubhub:Subscription message, http:Headers headers)
                returns websubhub:SubscriptionAccepted|websubhub:BadSubscriptionError|error {
        if (securityOn) {
            check authorize(headers, ["subscribe"]);
        }
        return websubhub:SUBSCRIPTION_ACCEPTED;
    }

    # Validates whether `topic` to which the subscriber wants to subscribe is available and whether subscriber has already subscribed.
    # 
    # + message - Details of the subscription
    # + return - `websubhub:SubscriptionDeniedError` if the subscription is denied by the hub or else `()`
    isolated remote function onSubscriptionValidation(websubhub:Subscription message)
                returns websubhub:SubscriptionDeniedError? {
        log:printInfo("Received subscription-validation request ", request = message.toString());
        string topicName = generateTopicName(message.hubTopic);
        string groupName = generateGroupName(message.hubTopic, message.hubCallback);
        boolean isTopicAvailable = false;
        boolean isSubscriberAvailable = false;
        lock {
            isTopicAvailable = registeredTopics.hasKey(topicName);
        }
        if (!isTopicAvailable) {
            return error websubhub:SubscriptionDeniedError("Topic [" + message.hubTopic + "] is not registered with the Hub");
        } else {
            lock {
                isSubscriberAvailable = subscribers.hasKey(groupName);
            }
            if (isSubscriberAvailable) {
                return error websubhub:SubscriptionDeniedError("Subscriber has already registered with the Hub");
            }
        }
    }

    # Processes a verified subscription request.
    # 
    # + message - Details of the subscription
    # + return - `error` if there is any unexpected error or else `()`
    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) returns error? {
        log:printInfo("Received subscription-intent-verification request ", request = message.toString());
        check self.subscribe(message);
    }

    isolated function subscribe(websubhub:VerifiedSubscription message) returns error? {
        log:printInfo("Received subscription request ", request = message);
        string groupName = generateGroupName(message.hubTopic, message.hubCallback);
        kafka:Consumer consumerEp = check createMessageConsumer(message);
        websubhub:HubClient hubClientEp = check new (message);
        error? persistingResult = persistSubscription(message);
        if (persistingResult is error) {
            log:printError("Error occurred while persisting the subscription ", err = persistingResult.message());
        }
        boolean shouldRunNotification = true;
        lock {
            subscribers[groupName] = shouldRunNotification;
        }
        error? notificationError = notifySubscriber(hubClientEp, consumerEp, groupName);
    }

    # Unsubscribes a consumer from the hub.
    # 
    # + message - Details of the unsubscription
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:UnsubscriptionAccepted` if unsubscription is accepted from the hub, `websubhub:BadUnsubscriptionError`
    #            if unsubscription is denied from the hub or `error` if there is any unexpected error
    isolated remote function onUnsubscription(websubhub:Unsubscription message, http:Headers headers)
               returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|error {
        if (securityOn) {
            check authorize(headers, ["subscribe"]);
        }
        return websubhub:UNSUBSCRIPTION_ACCEPTED;
    }

    # Validates a incomming unsubscription request.
    # 
    # + message - Details of the unsubscription
    # + return - `websubhub:UnsubscriptionDeniedError` if the unsubscription is denied by the hub or else `()`
    isolated remote function onUnsubscriptionValidation(websubhub:Unsubscription message)
                returns websubhub:UnsubscriptionDeniedError? {
        log:printInfo("Received unsubscription-validation request ", request = message.toString());
        string topicName = generateTopicName(message.hubTopic);
        boolean isTopicAvailable = false;
        boolean isSubscriberAvailable = false;
        lock {
            isTopicAvailable = registeredTopics.hasKey(topicName);
        }
        if (!isTopicAvailable) {
            return error websubhub:UnsubscriptionDeniedError("Topic [" + message.hubTopic + "] is not registered with the Hub");
        } else {
            string groupName = generateGroupName(message.hubTopic, message.hubCallback);
            lock {
                isSubscriberAvailable = subscribers.hasKey(groupName);
            }
            if (!isSubscriberAvailable) {
                return error websubhub:UnsubscriptionDeniedError("Could not find a valid subscriber for Topic [" 
                                + message.hubTopic + "] and Callback [" + message.hubCallback + "]");
            }
        }       
    }

    # Processes a verified unsubscription request.
    # 
    # + message - Details of the unsubscription
    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription message) {
        log:printInfo("Received unsubscription-intent-verification request ", request = message.toString());
        string groupName = generateGroupName(message.hubTopic, message.hubCallback);
        lock {
            boolean? isOn = subscribers[groupName];
            if (isOn is boolean) {
                isOn = false;
            }
        }
        var persistingResult = persistUnsubscription(message);
        if (persistingResult is error) {
            log:printError("Error occurred while persisting the unsubscription ", err = persistingResult.message());
        }  
    }
};
