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

import ballerina/http;
import ballerina/uuid;

isolated class SubscriptionHandler {
    private final HttpToWebsubhubAdaptor adaptor;
    private final Controller hubController;
    private final readonly & ClientConfiguration clientConfig;

    private final boolean isOnSubscriptionAvailable;
    private final boolean isOnSubscriptionValidationAvailable;
    private final boolean isOnUnsubscriptionAvailable;
    private final boolean isOnUnsubscriptionValidationAvailable;

    isolated function init(HttpToWebsubhubAdaptor adaptor, boolean autoVerifySubscription,
            ClientConfiguration clientConfig) {
        self.adaptor = adaptor;
        self.hubController = new (autoVerifySubscription);
        self.clientConfig = clientConfig.cloneReadOnly();
        string[] methodNames = adaptor.getServiceMethodNames();
        self.isOnSubscriptionAvailable = methodNames.indexOf("onSubscription") is int;
        self.isOnSubscriptionValidationAvailable = methodNames.indexOf("onSubscriptionValidation") is int;
        self.isOnUnsubscriptionAvailable = methodNames.indexOf("onUnsubscription") is int;
        self.isOnUnsubscriptionValidationAvailable = methodNames.indexOf("onUnsubscriptionValidation") is int;
    }

    isolated function intiateSubscription(Subscription message, http:Headers headers) returns http:Response|Redirect {
        if !self.isOnSubscriptionAvailable {
            http:Response response = new;
            response.statusCode = http:STATUS_ACCEPTED;
            return response;
        }

        SubscriptionAccepted|Redirect|error result = self.adaptor.callOnSubscriptionMethod(
            message, headers, self.hubController);
        if result is Redirect {
            return result;
        }

        return processOnSubscriptionResult(result);
    }

    isolated function verifySubscription(Subscription message, http:Headers headers) returns error? {
        error? validationResult = self.validateSubscription(message, headers);
        if validationResult is error {
            [string, string?][] params = [
                [HUB_MODE, MODE_DENIED],
                [HUB_TOPIC, message.hubTopic],
                [HUB_REASON, validationResult.message()]
            ];
            _ = check sendNotification(message.hubCallback, params, self.clientConfig);
            return;
        }

        boolean skipIntentVerification = self.hubController.skipSubscriptionVerification(message);
        if !skipIntentVerification {
            string challenge = uuid:createType4AsString();
            [string, string?][] params = [
                [HUB_MODE, MODE_SUBSCRIBE],
                [HUB_TOPIC, message.hubTopic],
                [HUB_CHALLENGE, challenge],
                [HUB_LEASE_SECONDS, message.hubLeaseSeconds]
            ];
            http:Response subscriberResponse = check sendNotification(message.hubCallback, params, self.clientConfig);
            string responsePayload = check subscriberResponse.getTextPayload();
            if challenge != responsePayload {
                return;
            }
        }

        VerifiedSubscription verifiedSubscription = {
            ...message
        };
        check self.adaptor.callOnSubscriptionIntentVerifiedMethod(verifiedSubscription, headers);
    }

    isolated function validateSubscription(Subscription message, http:Headers headers) returns error? {
        if self.isOnSubscriptionValidationAvailable {
            return self.adaptor.callOnSubscriptionValidationMethod(message, headers);
        }

        if !message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://") {
            return error SubscriptionDeniedError(
                "Invalid hub.callback param in the request.", statusCode = http:STATUS_NOT_ACCEPTABLE);
        }
    }

    isolated function initiateUnsubscription(Unsubscription message, http:Headers headers) returns http:Response {
        if !self.isOnUnsubscriptionAvailable {
            http:Response response = new;
            response.statusCode = http:STATUS_ACCEPTED;
            return response;
        }

        UnsubscriptionAccepted|error result = self.adaptor.callOnUnsubscriptionMethod(
            message, headers, self.hubController);
        return processOnUnsubscriptionResult(result);
    }

    isolated function verifyUnsubscription(Unsubscription message, http:Headers headers) returns error? {
        error? validationResult = self.validateUnsubscription(message, headers);
        if validationResult is error {
            [string, string?][] params = [
                [HUB_MODE, MODE_DENIED],
                [HUB_TOPIC, message.hubTopic],
                [HUB_REASON, validationResult.message()]
            ];
            _ = check sendNotification(message.hubCallback, params, self.clientConfig);
        }

        boolean skipIntentVerification = self.hubController.skipSubscriptionVerification(message);
        if !skipIntentVerification {
            string challenge = uuid:createType4AsString();
            [string, string?][] params = [
                [HUB_MODE, MODE_UNSUBSCRIBE],
                [HUB_TOPIC, message.hubTopic],
                [HUB_CHALLENGE, challenge]
            ];
            http:Response subscriberResponse = check sendNotification(message.hubCallback, params, self.clientConfig);
            string responsePayload = check subscriberResponse.getTextPayload();
            if challenge != responsePayload {
                return;
            }
        }

        VerifiedUnsubscription verifiedUnsubscription = {
            ...message
        };
        check self.adaptor.callOnUnsubscriptionIntentVerifiedMethod(verifiedUnsubscription, headers);
    }

    isolated function validateUnsubscription(Unsubscription message, http:Headers headers) returns error? {
        if self.isOnUnsubscriptionValidationAvailable {
            return self.adaptor.callOnUnsubscriptionValidationMethod(message, headers);
        }

        if !message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://") {
            return error SubscriptionDeniedError(
                "Invalid hub.callback param in the request.", statusCode = http:STATUS_NOT_ACCEPTABLE);
        }
    }
}

isolated function createSubscriptionMessage(string hubUrl, int defaultLeaseSeconds, map<string> params)
returns Subscription|error {

    string topic = check retrieveQueryParameter(params, HUB_TOPIC);
    string hubCallback = check retrieveQueryParameter(params, HUB_CALLBACK);
    int leaseSeconds = retrieveLeaseSeconds(params, defaultLeaseSeconds);
    Subscription message = {
        hub: hubUrl,
        hubMode: MODE_SUBSCRIBE,
        hubCallback: hubCallback,
        hubTopic: topic,
        hubLeaseSeconds: leaseSeconds.toString(),
        hubSecret: params.removeIfHasKey(HUB_SECRET)
    };
    foreach var ['key, value] in params.entries() {
        message['key] = value;
    }
    return message;
}

isolated function retrieveLeaseSeconds(map<string> params, int defaultLeaseSeconds) returns int {
    var hubLeaseSeconds = params.removeIfHasKey(HUB_LEASE_SECONDS);
    if hubLeaseSeconds is string {
        var retrievedLeaseSeconds = 'int:fromString(hubLeaseSeconds);
        if retrievedLeaseSeconds is int {
            return retrievedLeaseSeconds;
        }
    }
    return defaultLeaseSeconds;
}

isolated function processOnSubscriptionResult(SubscriptionAccepted|error result) returns http:Response|Redirect {
    http:Response response = new;
    if result is SubscriptionAccepted {
        updateSuccessResponse(response, result.statusCode, result?.body, result?.headers);
        return response;
    } else if result is BadSubscriptionError {
        CommonResponse errorDetails = result.detail();
        updateErrorResponse(response, errorDetails, result.message());
        return response;
    } else {
        CommonResponse errorDetails = result is InternalSubscriptionError ?
            result.detail() : INTERNAL_SUBSCRIPTION_ERROR.detail();
        updateErrorResponse(response, errorDetails, result.message());
        return response;
    }
}

isolated function createUnsubscriptionMessage(map<string> params) returns Unsubscription|error {
    string topic = check retrieveQueryParameter(params, HUB_TOPIC);
    string hubCallback = check retrieveQueryParameter(params, HUB_CALLBACK);
    Unsubscription message = {
        hubMode: MODE_UNSUBSCRIBE,
        hubCallback: hubCallback,
        hubTopic: topic,
        hubSecret: params.removeIfHasKey(HUB_SECRET)
    };
    foreach var ['key, value] in params.entries() {
        message['key] = value;
    }
    return message;
}

isolated function processOnUnsubscriptionResult(UnsubscriptionAccepted|error result) returns http:Response {
    http:Response response = new;
    if result is UnsubscriptionAccepted {
        updateSuccessResponse(response, result.statusCode, result?.body, result?.headers);
        return response;
    } else if result is BadUnsubscriptionError {
        CommonResponse errorDetails = result.detail();
        updateErrorResponse(response, errorDetails, result.message());
        return response;
    } else {
        CommonResponse errorDetails = result is InternalSubscriptionError ?
            result.detail() : INTERNAL_UNSUBSCRIPTION_ERROR.detail();
        updateErrorResponse(response, errorDetails, result.message());
        return response;
    }
}
