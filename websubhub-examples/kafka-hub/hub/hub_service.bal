// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/websubhub;
import ballerina/log;
import ballerina/http;
import ballerinax/kafka;
import kafkaHub.security;
import kafkaHub.persistence as ps;
import kafkaHub.config;
import kafkaHub.util;
import kafkaHub.connections as conn;

isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};
isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

websubhub:Service hubService = service object {

    # Registers a `topic` in the hub.
    # 
    # + message - Details related to the topic-registration
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:TopicRegistrationSuccess` if topic registration is successful, `websubhub:TopicRegistrationError`
    #            if topic registration failed or `error` if there is any unexpected error
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message, http:Headers headers)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error {
        if config:SECURITY_ON {
            check security:authorize(headers, ["register_topic"]);
        }
        check self.registerTopic(message);
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    isolated function registerTopic(websubhub:TopicRegistration message) returns websubhub:TopicRegistrationError? {
        log:printInfo("Received topic-registration request ", request = message);
        string topicName = util:sanitizeTopicName(message.topic);
        lock {
            if registeredTopicsCache.hasKey(topicName) {
                return error websubhub:TopicRegistrationError("Topic has already registered with the Hub");
            }
            error? persistingResult = ps:persistTopicRegistrations(registeredTopicsCache, message.cloneReadOnly());
            if persistingResult is error {
                log:printError("Error occurred while persisting the topic-registration ", err = persistingResult.message());
            }
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
        if config:SECURITY_ON {
            check security:authorize(headers, ["deregister_topic"]);
        }
        check self.deregisterTopic(message);
        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    isolated function deregisterTopic(websubhub:TopicRegistration message) returns websubhub:TopicDeregistrationError? {
        log:printInfo("Received topic-deregistration request ", request = message);
        string topicName = util:sanitizeTopicName(message.topic);
        lock {
            if !registeredTopicsCache.hasKey(topicName) {
                return error websubhub:TopicDeregistrationError("Topic has not been registered in the Hub");
            }
            error? persistingResult = ps:persistTopicDeregistration(registeredTopicsCache, message.cloneReadOnly());
            if persistingResult is error {
                log:printError("Error occurred while persisting the topic-deregistration ", err = persistingResult.message());
            }
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
        if config:SECURITY_ON {
            check security:authorize(headers, ["update_content"]);
        }
        check self.updateMessage(message);
        return websubhub:ACKNOWLEDGEMENT;
    }

    isolated function updateMessage(websubhub:UpdateMessage msg) returns websubhub:UpdateMessageError? {
        log:printInfo("Received content-update request ", request = msg.toString());
        string topicName = util:sanitizeTopicName(msg.hubTopic);
        boolean isTopicAvailable = false;
        lock {
            isTopicAvailable = registeredTopicsCache.hasKey(topicName);
        }
        if isTopicAvailable {
            error? errorResponse = self.publishContent(msg, topicName);
            if errorResponse is websubhub:UpdateMessageError {
                return errorResponse;
            } else if errorResponse is error {
                log:printError("Error occurred while publishing the content ", errorMessage = errorResponse.message());
                return error websubhub:UpdateMessageError(errorResponse.message());
            }
        } else {
            return error websubhub:UpdateMessageError("Topic [" + msg.hubTopic + "] is not registered with the Hub");
        }
    }

    isolated function publishContent(websubhub:UpdateMessage message, string topicName) returns error? {
        log:printInfo("Distributing content to ", Topic = topicName);
        json payload = <json>message.content;
        byte[] content = payload.toJsonString().toBytes();
        check conn:updateMessageProducer->send({ topic: topicName, value: content });
        check conn:updateMessageProducer->'flush();
    }
    
    # Subscribes a consumer to the hub.
    # 
    # + message - Details of the subscription
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:SubscriptionAccepted` if subscription is accepted from the hub, `websubhub:BadSubscriptionError`
    #            if subscription is denied from the hub or `error` if there is any unexpected error
    isolated remote function onSubscription(websubhub:Subscription message, http:Headers headers)
                returns websubhub:SubscriptionAccepted|websubhub:BadSubscriptionError|error {
        if config:SECURITY_ON {
            check security:authorize(headers, ["subscribe"]);
        }
        return websubhub:SUBSCRIPTION_ACCEPTED;
    }

    # Validates a incomming subscription request.
    # 
    # + message - Details of the subscription
    # + return - `websubhub:SubscriptionDeniedError` if the subscription is denied by the hub or else `()`
    isolated remote function onSubscriptionValidation(websubhub:Subscription message)
                returns websubhub:SubscriptionDeniedError? {
        log:printInfo("Received subscription-validation request ", request = message.toString());
        string topicName = util:sanitizeTopicName(message.hubTopic);
        boolean isTopicAvailable = false;
        lock {
            isTopicAvailable = registeredTopicsCache.hasKey(topicName);
        }
        if !isTopicAvailable {
            return error websubhub:SubscriptionDeniedError("Topic [" + message.hubTopic + "] is not registered with the Hub");
        } else {
            string groupName = util:generateGroupName(message.hubTopic, message.hubCallback);
            boolean isSubscriberAvailable = false;
            lock {
                isSubscriberAvailable = subscribersCache.hasKey(groupName);
            }
            if isSubscriberAvailable {
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
        string groupName = util:generateGroupName(message.hubTopic, message.hubCallback);
        kafka:Consumer consumerEp = check conn:createMessageConsumer(message);
        websubhub:HubClient hubClientEp = check new (message);
        lock {
            error? persistingResult = ps:persistSubscription(subscribersCache, message.cloneReadOnly());
            if persistingResult is error {
                log:printError("Error occurred while persisting the subscription ", err = persistingResult.message());
            }
        }
    }

    # Unsubscribes a consumer from the hub.
    # 
    # + message - Details of the unsubscription
    # + headers - `http:Headers` of the original `http:Request`
    # + return - `websubhub:UnsubscriptionAccepted` if unsubscription is accepted from the hub, `websubhub:BadUnsubscriptionError`
    #            if unsubscription is denied from the hub or `error` if there is any unexpected error
    isolated remote function onUnsubscription(websubhub:Unsubscription message, http:Headers headers)
               returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|error {
        if config:SECURITY_ON {
            check security:authorize(headers, ["subscribe"]);
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
        string topicName = util:sanitizeTopicName(message.hubTopic);
        boolean isTopicAvailable = false;
        boolean isSubscriberAvailable = false;
        lock {
            isTopicAvailable = registeredTopicsCache.hasKey(topicName);
        }
        if !isTopicAvailable {
            return error websubhub:UnsubscriptionDeniedError("Topic [" + message.hubTopic + "] is not registered with the Hub");
        } else {
            string groupName = util:generateGroupName(message.hubTopic, message.hubCallback);
            lock {
                isSubscriberAvailable = subscribersCache.hasKey(groupName);
            }
            if !isSubscriberAvailable {
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
        string groupName = util:generateGroupName(message.hubTopic, message.hubCallback);
        lock {
            var persistingResult = ps:persistUnsubscription(subscribersCache, message.cloneReadOnly());
            if (persistingResult is error) {
                log:printError("Error occurred while persisting the unsubscription ", err = persistingResult.message());
            } 
        } 
    }
};

