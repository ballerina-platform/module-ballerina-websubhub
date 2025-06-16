// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

import jmshub.common;
import jmshub.persistence as persist;

import ballerina/http;
import ballerina/websubhub;

websubhub:Service hubService = service object {

    # Registers a `topic` in the hub.
    #
    # + message - Details related to the topic-registration
    # + return - `websubhub:TopicRegistrationSuccess` if topic registration is successful, `websubhub:TopicRegistrationError`
    # if topic registration failed or `error` if there is any unexpected error
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
        returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {

        string topic = message.topic;
        if isTopicAvailable(topic) {
            return error websubhub:TopicRegistrationError(
                string `Topic ${topic} has already registered with the Hub`, statusCode = http:STATUS_CONFLICT);
        }

        error? persistResult = persist:addRegsiteredTopic(message);
        if persistResult is error {
            string errorMessage = string `Failed to persist the websub topic registration for topic: ${topic}`;
            common:logError(errorMessage, persistResult, severity = "FATAL");
            return error websubhub:TopicRegistrationError(
                errorMessage, persistResult, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    # Deregisters a `topic` in the hub.
    #
    # + message - Details related to the topic-deregistration
    # + return - `websubhub:TopicDeregistrationSuccess` if topic deregistration is successful, `websubhub:TopicDeregistrationError`
    # if topic deregistration failed or `error` if there is any unexpected error
    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message)
        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {

        string topic = message.topic;
        if !isTopicAvailable(topic) {
            return error websubhub:TopicDeregistrationError(
                string `Topic ${topic} has not been registered in the Hub`, statusCode = http:STATUS_NOT_FOUND);
        }

        error? persistResult = persist:removeRegsiteredTopic(message);
        if persistResult is error {
            string errorMessage = string `Failed to persist the websub topic deregistration for topic: ${topic}`;
            common:logError(errorMessage, persistResult, severity = "FATAL");
            return error websubhub:TopicDeregistrationError(
                errorMessage, persistResult, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    # Validates a incomming subscription request.
    #
    # + message - Details of the subscription
    # + return - `websubhub:SubscriptionDeniedError` if the subscription is denied by the hub or else `()`
    isolated remote function onSubscriptionValidation(websubhub:Subscription message) returns websubhub:SubscriptionDeniedError? {
        string topic = message.hubTopic;
        if !isTopicAvailable(topic) {
            return error websubhub:SubscriptionDeniedError(
                string `Topic ${topic} is not registered with the Hub`, statusCode = http:STATUS_NOT_ACCEPTABLE);
        }

        string subscriberId = common:generateSubscriberId(topic, message.hubCallback);
        websubhub:VerifiedSubscription? subscription = getSubscription(subscriberId);
        if subscription is () {
            return;
        }
        if subscription.hasKey(STATUS) && subscription.get(STATUS) is STALE_STATE {
            return;
        }

        return error websubhub:SubscriptionDeniedError(
            "Subscriber has already registered with the Hub", statusCode = http:STATUS_NOT_ACCEPTABLE);
    }

    # Processes a verified subscription request.
    #
    # + message - Details of the subscription
    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) {
        websubhub:VerifiedSubscription subscription = self.prepareSubscriptionToBePersisted(message);
        error? persistResult = persist:addSubscription(subscription.cloneReadOnly());
        if persistResult is error {
            common:logError("Error occurred while persisting the subscription", persistResult, severity = "FATAL");
        }
    }

    isolated function prepareSubscriptionToBePersisted(websubhub:VerifiedSubscription message)
        returns websubhub:VerifiedSubscription {

        string subscriberId = common:generateSubscriberId(message.hubTopic, message.hubCallback);
        websubhub:VerifiedSubscription? subscription = getSubscription(subscriberId);
        // if we have a stale subscription, remove the `status` flag from the subscription and persist it again
        if subscription is websubhub:Subscription {
            websubhub:VerifiedSubscription updatedSubscription = {
                ...subscription
            };
            _ = updatedSubscription.removeIfHasKey(STATUS);
            return updatedSubscription;
        }

        // todo: identify the correct logic for this

        // if !message.hasKey(CONSUMER_GROUP) {
        //     string consumerGroup = util:generateGroupName(message.hubTopic, message.hubCallback);
        //     message[CONSUMER_GROUP] = consumerGroup;
        // }
        // message[SERVER_ID] = config:SERVER_ID;
        return message;
    }

    # Validates a incomming unsubscription request.
    #
    # + message - Details of the unsubscription
    # + return - `websubhub:UnsubscriptionDeniedError` if the unsubscription is denied by the hub or else `()`
    isolated remote function onUnsubscriptionValidation(websubhub:Unsubscription message)
        returns websubhub:UnsubscriptionDeniedError? {

        string topic = message.hubTopic;
        if !isTopicAvailable(topic) {
            return error websubhub:UnsubscriptionDeniedError(
                string `Topic ${topic} is not registered with the Hub`, statusCode = http:STATUS_NOT_ACCEPTABLE);
        }

        string subscriberId = common:generateSubscriberId(message.hubTopic, message.hubCallback);
        if !isValidSubscription(subscriberId) {
            return error websubhub:UnsubscriptionDeniedError(
                string `Could not find a valid subscriber for Topic ${topic} and Callback ${message.hubCallback}`,
                statusCode = http:STATUS_NOT_ACCEPTABLE
            );
        }
    }

    # Processes a verified unsubscription request.
    #
    # + message - Details of the unsubscription
    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription message) {
        error? persistResult = persist:removeSubscription(message.cloneReadOnly());
        if persistResult is error {
            common:logError("Error occurred while persisting the unsubscription", persistResult, severity = "FATAL");
        }
    }

    # Publishes content to the hub.
    #
    # + message - Details of the published content
    # + return - `websubhub:Acknowledgement` if publish content is successful, `websubhub:UpdateMessageError`
    # if publish content failed or `error` if there is any unexpected error
    isolated remote function onUpdateMessage(websubhub:UpdateMessage message)
        returns websubhub:Acknowledgement|websubhub:UpdateMessageError {

        string topic = message.hubTopic;
        if !isTopicAvailable(topic) {
            return error websubhub:UpdateMessageError(
                string `Topic ${topic} is not registered with the Hub`, statusCode = http:STATUS_NOT_FOUND);
        }

        error? persistResult = persist:addUpdateMessage(topic, message);
        if persistResult is error {
            string errorMessage = string `
                Error occurred while publishing upates for topic ${topic}: ${persistResult.message()}`;
            common:logError(errorMessage, persistResult, severity = "FATAL");
            return error websubhub:UpdateMessageError(errorMessage, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        return websubhub:ACKNOWLEDGEMENT;
    }
};

