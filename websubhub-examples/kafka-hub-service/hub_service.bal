import ballerina/websubhub;
import ballerina/crypto;
import ballerina/log;
import ballerinax/kafka;
import ballerina/http;
import ballerina/jwt;

map<string> registeredTopics = {};
map<future<error?>> registeredConsumers = {};

kafka:ProducerConfiguration mainProducerConfig = {
    clientId: "main-producer",
    acks: "1",
    retryCount: 3
};

kafka:Producer mainProducer = check new ("localhost:9092", mainProducerConfig);

listener websubhub:Listener hubListener = new websubhub:Listener(9090);

http:JwtValidatorConfig config = {
    audience: "[<client-id1>, <client-id2>]",
    signatureConfig: {
        trustStoreConfig: {
            trustStore: {
                path: "<trust-store-path>",
                password: "<trust-store-password>"
            },
            certAlias: "<trust-store-alias>"
        }
    }
};
http:ListenerJwtAuthHandler handler = new(config);

websubhub:Service hubService = service object {
    remote function onRegisterTopic(websubhub:TopicRegistration message, http:Headers headers)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        var authHeader = headers.getHeader(http:AUTH_HEADER);
        if (authHeader is string) {
            jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
            if (auth is jwt:Payload && validateJwt(auth, ["register_topic"])) {
                log:printInfo("Received topic-registration request ", request = message);
                registerTopic(message);
                return websubhub:TOPIC_REGISTRATION_SUCCESS;
            } else {
                log:printError("Authentication credentials invalid");
                return error websubhub:TopicRegistrationError("Not authorized");   
            }
        } else {
            log:printError("Authorization header not found");
            return error websubhub:TopicRegistrationError("Not authorized");
        }
    }

    remote function onDeregisterTopic(websubhub:TopicDeregistration message, http:Headers headers)
                        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {
        var authHeader = headers.getHeader(http:AUTH_HEADER);
        if (authHeader is string) {
            jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
            if (auth is jwt:Payload && validateJwt(auth, ["deregister_topic"])) {
                log:printInfo("Received topic-deregistration request ", request = message);
                string topicId = crypto:hashSha1(message.topic.toBytes()).toBase64();
                if (registeredTopics.hasKey(topicId)) {
                    string deletedTopic = registeredTopics.remove(topicId);
                }
                var persistingResult = persistTopicDeregistration(message);
                if (persistingResult is error) {
                    log:printError("Error occurred while persisting the topic-deregistration ", err = persistingResult.message());
                }
                return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
            } else {
                log:printError("Authentication credentials invalid");
                return error websubhub:TopicDeregistrationError("Not authorized");   
            }
        } else {
            log:printError("Authorization header not found");
            return error websubhub:TopicDeregistrationError("Not authorized");
        }
    }

    remote function onUpdateMessage(websubhub:UpdateMessage msg, http:Headers headers)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError {   
        var authHeader = headers.getHeader(http:AUTH_HEADER);
        if (authHeader is string) {
            jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
            if (auth is jwt:Payload && validateJwt(auth, ["update_content"])) {
                log:printInfo("Received content-update request ", request = msg.toString());
                error? errorResponse = publishContent(msg);
                if (errorResponse is websubhub:UpdateMessageError) {
                    return errorResponse;
                } else if (errorResponse is error) {
                    log:printError("Error occurred while publishing the content ", errorMessage = errorResponse.message());
                    return error websubhub:UpdateMessageError(errorResponse.message());
                } else {
                    return websubhub:ACKNOWLEDGEMENT;
                }
            } else {
                log:printError("Authentication credentials invalid");
                return error websubhub:UpdateMessageError("Not authorized");   
            }
        } else {
            log:printError("Authorization header not found");
            return error websubhub:UpdateMessageError("Not authorized");
        }
    }
    
    remote function onSubscription(websubhub:Subscription message, http:Headers headers)
                returns websubhub:SubscriptionAccepted|websubhub:BadSubscriptionError {
        var authHeader = headers.getHeader(http:AUTH_HEADER);
        if (authHeader is string) {
            jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
            if (auth is jwt:Payload && validateJwt(auth, ["subscribe"])) {
                log:printInfo("Received subscription-request ", request = message.toString());
                return websubhub:SUBSCRIPTION_ACCEPTED;
            } else {
                log:printError("Authentication credentials invalid");
                return error websubhub:BadSubscriptionError("Not authorized");   
            }
        } else {
            log:printError("Authorization header not found");
            return error websubhub:BadSubscriptionError("Not authorized");
        }
    }

    remote function onSubscriptionValidation(websubhub:Subscription message)
                returns websubhub:SubscriptionDeniedError? {
        log:printInfo("Received subscription-validation request ", request = message.toString());

        string topicId = crypto:hashSha1(message.hubTopic.toBytes()).toBase64();
        if (!registeredTopics.hasKey(topicId)) {
            return error websubhub:SubscriptionDeniedError("Topic [" + message.hubTopic + "] is not registered with the Hub");
        }
    }

    remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) returns error? {
        log:printInfo("Received subscription-intent-verification request ", request = message.toString());
        check subscribe(message);
    }

    remote function onUnsubscription(websubhub:Unsubscription message, http:Headers headers)
               returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|websubhub:InternalUnsubscriptionError {
        var authHeader = headers.getHeader(http:AUTH_HEADER);
        if (authHeader is string) {
            jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
            if (auth is jwt:Payload && validateJwt(auth, ["subscribe"])) {
                log:printInfo("Received unsubscription request ", request = message.toString());
                return websubhub:UNSUBSCRIPTION_ACCEPTED;
            } else {
                log:printError("Authentication credentials invalid");
                return error websubhub:BadUnsubscriptionError("Not authorized");   
            }
        } else {
            log:printError("Authorization header not found");
            return error websubhub:BadUnsubscriptionError("Not authorized");
        }
    }

    remote function onUnsubscriptionValidation(websubhub:Unsubscription message)
                returns websubhub:UnsubscriptionDeniedError? {
        log:printInfo("Received unsubscription-validation request ", request = message.toString());

        string topicId = crypto:hashSha1(message.hubTopic.toBytes()).toBase64();
        if (!registeredTopics.hasKey(topicId)) {
            return error websubhub:UnsubscriptionDeniedError("Topic [" + message.hubTopic + "] is not registered with the Hub");
        } else {
            string groupId = generateGroupId(message.hubTopic, message.hubCallback);
            if (!registeredConsumers.hasKey(groupId)) {
                return error websubhub:UnsubscriptionDeniedError("Could not find a valid subscriber for Topic [" 
                                + message.hubTopic + "] and Callback [" + message.hubCallback + "]");
            }
        }       
    }

    remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription message) {
        log:printInfo("Received unsubscription-intent-verification request ", request = message.toString());

        string groupId = generateGroupId(message.hubTopic, message.hubCallback);
        var registeredConsumer = registeredConsumers[groupId];
        if (registeredConsumer is future<error?>) {
             _ = registeredConsumer.cancel();
            var result = registeredConsumers.remove(groupId);
        }  

        var persistingResult = persistUnsubscription(message);
        if (persistingResult is error) {
            log:printError("Error occurred while persisting the unsubscription ", err = persistingResult.message());
        }  
    }
};
