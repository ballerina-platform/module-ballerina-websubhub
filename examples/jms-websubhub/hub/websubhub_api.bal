// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
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
import jmshub.config;
import jmshub.persistence as persist;

import ballerina/http;
import ballerina/mime;
import ballerina/uuid;
import ballerina/websubhub;

import wso2/mi;

@mi:Operation
public isolated function isTopicExist(string topic) returns boolean {
    return isTopicAvailable(topic);
}

@mi:Operation
public isolated function onRegisterTopic(json request) returns json {
    do {
        websubhub:TopicRegistration topicRegistration = check request.fromJsonWithType();
        websubhub:TopicDeregistrationSuccess response = check registerTopic(topicRegistration);
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
        };
    } on fail error e {
        if e is websubhub:TopicRegistrationError {
            websubhub:CommonResponse response = e.detail();
            return {
                statusCode: response.statusCode,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
            };
        }
        string errMsg = string `Error occurred while processing topic registration: ${e.message()}`;
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": errMsg})
        };
    }
}

isolated function registerTopic(websubhub:TopicRegistration message)
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

@mi:Operation
public isolated function onDeregisterTopic(json request) returns json {
    do {
        websubhub:TopicDeregistration topicDeregistration = check request.fromJsonWithType();
        websubhub:TopicDeregistrationSuccess response = check deregisterTopic(topicDeregistration);
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
        };
    } on fail error e {
        if e is websubhub:TopicDeregistrationError {
            websubhub:CommonResponse response = e.detail();
            return {
                statusCode: response.statusCode,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
            };
        }
        string errMsg = string `Error occurred while processing topic deregistration: ${e.message()}`;
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": errMsg})
        };
    }
}

isolated function deregisterTopic(websubhub:TopicDeregistration message)
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

@mi:Operation
public isolated function onUpdateMessage(json request) returns json {
    do {
        websubhub:UpdateMessage updateMsg = check request.fromJsonWithType();
        websubhub:Acknowledgement response = check updateMessage(updateMsg);
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
        };
    } on fail error e {
        if e is websubhub:UpdateMessageError {
            websubhub:CommonResponse response = e.detail();
            return {
                statusCode: response.statusCode,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
            };
        }
        string errMsg = string `Error occurred while processing content update message: ${e.message()}`;
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": errMsg})
        };
    }
}

isolated function updateMessage(websubhub:UpdateMessage message)
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

@mi:Operation
public isolated function onSubscription(json request) returns json {
    _ = start verifyAndValidateSubscription(request.cloneReadOnly());
    return {
        statusCode: http:STATUS_ACCEPTED,
        mediaType: mime:APPLICATION_FORM_URLENCODED,
        body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
    };
}

isolated function verifyAndValidateSubscription(json request) {
    record {|
        int statusCode;
        string mediaType;
        string body;
    |}|error validateResponse = onSubscriptionValidation(request).fromJsonWithType();
    if validateResponse is error {
        return;
    }
    if validateResponse.statusCode !is http:STATUS_ACCEPTED {
        return;
    }

    onSubscriptionVerification(request);
}

public isolated function onSubscriptionValidation(json request) returns json {
    do {
        websubhub:Subscription subscription = check request.fromJsonWithType();
        websubhub:SubscriptionDeniedError? subscriptionDenied = check validateSubscription(subscription);
        if subscriptionDenied is () {
            return {
                statusCode: http:STATUS_ACCEPTED,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
            };
        }

        map<string> params = {
            "hub.mode": "denied",
            "hub.topic": subscription.hubTopic,
            "hub.reason": subscriptionDenied.message()
        };
        _ = check common:sendNotification(subscription.hubCallback, params);
        websubhub:CommonResponse response = subscriptionDenied.detail();
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": subscriptionDenied.message()})
        };
    } on fail error e {
        common:logError("Unexpected error occurred while validating the subscription", e);
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
        };
    }
}

isolated function validateSubscription(websubhub:Subscription message) returns websubhub:SubscriptionDeniedError? {
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

public isolated function onSubscriptionVerification(json request) {
    do {
        websubhub:Subscription subscription = check request.fromJsonWithType();
        string challenge = uuid:createType4AsString();
        map<string?> params = {
            "hub.mode": "subscribe",
            "hub.topic": subscription.hubTopic,
            "hub.challenge": challenge,
            "hub.lease_seconds": subscription.hubLeaseSeconds
        };
        http:Response subscriberResponse = check common:sendNotification(subscription.hubCallback, params);
        string responsePayload = check subscriberResponse.getTextPayload();
        if challenge != responsePayload {
            return;
        }

        websubhub:VerifiedSubscription verifiedSubscription = {
            ...subscription
        };
        onSubscriptionIntentVerified(verifiedSubscription);
    } on fail error e {
        common:logError("Error occurred while processing subscription verification", e);
    }
}

isolated function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) {
    websubhub:VerifiedSubscription subscription = prepareSubscriptionToBePersisted(message);
    error? persistingResult = persist:addSubscription(subscription.cloneReadOnly());
    if persistingResult is error {
        common:logError("Error occurred while persisting the subscription", persistingResult);
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

    string subscriptionName = common:generateSubscriptionName(message.hubTopic, message.hubCallback);
    message[SUBSCRIPTION_NAME] = subscriptionName;
    return message;
}

@mi:Operation
public isolated function onUnsubscription(json request) returns json {
    _ = start verifyAndValidateUnsubscription(request.cloneReadOnly());
    return {
        statusCode: http:STATUS_ACCEPTED,
        mediaType: mime:APPLICATION_FORM_URLENCODED,
        body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
    };
}

isolated function verifyAndValidateUnsubscription(json request) {
    record {|
        int statusCode;
        string mediaType;
        string body;
    |}|error validateResponse = onUnsubscriptionValidation(request).fromJsonWithType();
    if validateResponse is error {
        return;
    }
    if validateResponse.statusCode !is http:STATUS_ACCEPTED {
        return;
    }

    onUnsubscriptionVerification(request);
}

public isolated function onUnsubscriptionValidation(json request) returns json {
    do {
        websubhub:Unsubscription unsubscription = check request.fromJsonWithType();
        websubhub:UnsubscriptionDeniedError? unsubscriptionDenied = validateUnsubscription(unsubscription);
        if unsubscriptionDenied is () {
            return {
                statusCode: http:STATUS_ACCEPTED,
                mediaType: mime:APPLICATION_FORM_URLENCODED,
                body: common:getFormUrlEncodedPayload({"hub.mode": "accepted"})
            };
        }

        map<string> params = {
            "hub.mode": "denied",
            "hub.topic": unsubscription.hubTopic,
            "hub.reason": unsubscriptionDenied.message()
        };
        _ = check common:sendNotification(unsubscription.hubCallback, params);
        websubhub:CommonResponse response = unsubscriptionDenied.detail();
        return {
            statusCode: response.statusCode,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": unsubscriptionDenied.message()})
        };
    } on fail error e {
        common:logError("Unexpected error occurred while validating the unsubscription", e);
        return {
            statusCode: http:STATUS_INTERNAL_SERVER_ERROR,
            mediaType: mime:APPLICATION_FORM_URLENCODED,
            body: common:getFormUrlEncodedPayload({"hub.mode": "denied", "hub.reason": e.message()})
        };
    }
}

isolated function validateUnsubscription(websubhub:Unsubscription message) returns websubhub:UnsubscriptionDeniedError? {
    string topic = message.hubTopic;
    if !isTopicAvailable(topic) {
        return error websubhub:UnsubscriptionDeniedError(
                string `Topic ${topic} is not registered with the Hub`, statusCode = http:STATUS_NOT_ACCEPTABLE);
    }

    string subscriberId = common:generateSubscriberId(message.hubTopic, message.hubCallback);
    if !isSubscriptionAvailable(subscriberId) {
        return error websubhub:UnsubscriptionDeniedError(
                string `Could not find a valid subscriber for Topic ${topic} and Callback ${message.hubCallback}`,
                statusCode = http:STATUS_NOT_ACCEPTABLE
            );
    }
}

public isolated function onUnsubscriptionVerification(json request) {
    do {
        websubhub:Subscription subscription = check request.fromJsonWithType();
        string challenge = uuid:createType4AsString();
        map<string?> params = {
            "hub.mode": "unsubscribe",
            "hub.topic": subscription.hubTopic,
            "hub.challenge": challenge,
            "hub.lease_seconds": subscription.hubLeaseSeconds
        };
        http:Response subscriberResponse = check common:sendNotification(subscription.hubCallback, params);
        string responsePayload = check subscriberResponse.getTextPayload();
        if challenge != responsePayload {
            return;
        }

        websubhub:VerifiedUnsubscription verifiedUnsubscription = {
            ...subscription
        };
        onUnsubscriptionIntentVerified(verifiedUnsubscription);
    } on fail error e {
        common:logError("Error occurred while processing unsubscription verification", e);
    }
}

isolated function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription message) {
    error? persistResult = persist:removeSubscription(message.cloneReadOnly());
    if persistResult is error {
        common:logError("Error occurred while persisting the unsubscription", persistResult, severity = "FATAL");
    }
}
