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

isolated function createSubscriptionMessage(string hubUrl, int defaultHubLeaseSeconds, map<string> params) returns Subscription|error {
    string topic = check retrieveQueryParameter(params, HUB_TOPIC);
    string hubCallback = check retrieveQueryParameter(params, HUB_CALLBACK);
    int leaseSeconds = retrieveLeaseSeconds(params, defaultHubLeaseSeconds);
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

isolated function retrieveLeaseSeconds(map<string> params, int defaultHubLeaseSeconds) returns int {
    var hubLeaseSeconds = params.removeIfHasKey(HUB_LEASE_SECONDS);
    if hubLeaseSeconds is string {
        var retrievedLeaseSeconds = 'int:fromString(hubLeaseSeconds);
        if retrievedLeaseSeconds is int {
            return retrievedLeaseSeconds;
        }
    }
    return defaultHubLeaseSeconds;
}

isolated function processSubscription(Subscription message, http:Headers headers, 
                                      HttpToWebsubhubAdaptor adaptor, boolean onSubscriptionMethodAvailable) returns http:Response|Redirect {
    if !onSubscriptionMethodAvailable {
        http:Response response = new;
        response.statusCode = http:STATUS_ACCEPTED;
        return response;
    } else {
        SubscriptionAccepted|Redirect|error result = adaptor.callOnSubscriptionMethod(message, headers);
        if result is Redirect {
            return result;
        }
        return processOnSubscriptionResult(result);
    }
}

isolated function processOnSubscriptionResult(SubscriptionAccepted|error result) returns http:Response|Redirect {
    http:Response response = new;
    if result is SubscriptionAccepted {
        response.statusCode = http:STATUS_ACCEPTED;
        return response;
    } else if result is BadSubscriptionError {
        response.statusCode = http:STATUS_BAD_REQUEST;
        var errorDetails = result.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        return response;
    } else {
        response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
        var errorDetails = result is InternalSubscriptionError ? result.detail() : INTERNAL_SUBSCRIPTION_ERROR.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        return response;
    }
}

isolated function processSubscriptionVerification(http:Headers headers, HttpToWebsubhubAdaptor adaptor, Subscription message, 
                                                  boolean subscriptionValidationMethodAvailable, ClientConfiguration config) returns error? {
    error? validationResult = validateSubscription(subscriptionValidationMethodAvailable, message, headers, adaptor);
    if validationResult is error {
        [string, string?][] params = [
            [HUB_MODE, MODE_DENIED],
            [HUB_TOPIC, message.hubTopic],
            [HUB_REASON, validationResult.message()]
        ];
        _ = check sendNotification(message.hubCallback, params, config);
    } else {
        string challenge = uuid:createType4AsString();
        [string, string?][] params = [
            [HUB_MODE, MODE_SUBSCRIBE],
            [HUB_TOPIC, message.hubTopic],
            [HUB_CHALLENGE, challenge],
            [HUB_LEASE_SECONDS, message.hubLeaseSeconds]
        ];
        http:Response subscriberResponse = check sendNotification(message.hubCallback, params, config);
        string respStringPayload = check subscriberResponse.getTextPayload();
        if (respStringPayload == challenge) {
            VerifiedSubscription verifiedMessage = {
                hub: message.hub,
                hubMode: message.hubMode,
                hubCallback: message.hubCallback,
                hubTopic: message.hubTopic,
                hubLeaseSeconds: message.hubLeaseSeconds,
                hubSecret: message.hubSecret
            };
            check adaptor.callOnSubscriptionIntentVerifiedMethod(verifiedMessage, headers);
        }
    }
}

isolated function validateSubscription(boolean isRemoteMethodAvailable, Subscription message, 
                                       http:Headers headers, HttpToWebsubhubAdaptor adaptor) returns error? {
    if isRemoteMethodAvailable {
        return adaptor.callOnSubscriptionValidationMethod(message, headers);
    } else {
        if !message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://") {
            return error SubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
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

isolated function processUnsubscription(Unsubscription message, http:Headers headers, 
                                        HttpToWebsubhubAdaptor adaptor, boolean onUnsubscriptionMethodAvailable) returns http:Response {
    if !onUnsubscriptionMethodAvailable {
        http:Response response = new;
        response.statusCode = http:STATUS_ACCEPTED;
        return response;
    } else {
        UnsubscriptionAccepted|error result = adaptor.callOnUnsubscriptionMethod(message, headers);
        return processOnUnsubscriptionResult(result);
    }
}

isolated function processOnUnsubscriptionResult(UnsubscriptionAccepted|error result) returns http:Response {
    http:Response response = new;
    if result is UnsubscriptionAccepted {
        response.statusCode = http:STATUS_ACCEPTED;
        return response;
    } else if result is BadUnsubscriptionError {
        response.statusCode = http:STATUS_BAD_REQUEST;
        var errorDetails = result.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        return response;
    } else {
        response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
        var errorDetails = result is InternalSubscriptionError ? result.detail() : INTERNAL_UNSUBSCRIPTION_ERROR.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        return response;
    }
}

isolated function processUnSubscriptionVerification(http:Headers headers, HttpToWebsubhubAdaptor adaptor, Unsubscription message, 
                                                    boolean unsubscriptionValidationMethodAvailable, ClientConfiguration config) returns error? {
    error? validationResult = validateUnsubscription(unsubscriptionValidationMethodAvailable, message, headers, adaptor);
    if validationResult is error {
        [string, string?][] params = [
            [HUB_MODE, MODE_DENIED],
            [HUB_TOPIC, message.hubTopic],
            [HUB_REASON, validationResult.message()]
        ];
        _ = check sendNotification(message.hubCallback, params, config);
    } else {
        string challenge = uuid:createType4AsString();
        [string, string?][] params = [
            [HUB_MODE, MODE_UNSUBSCRIBE],
            [HUB_TOPIC, message.hubTopic],
            [HUB_CHALLENGE, challenge]
        ];
        http:Response subscriberResponse = check sendNotification(message.hubCallback, params, config);
        string respStringPayload = check subscriberResponse.getTextPayload();
        if (respStringPayload == challenge) {
            VerifiedUnsubscription verifiedMessage = {
                hubMode: message.hubMode,
                hubCallback: message.hubCallback,
                hubTopic: message.hubTopic,
                hubSecret: message.hubSecret
            };
            check adaptor.callOnUnsubscriptionIntentVerifiedMethod(verifiedMessage, headers);
        }
    }
}

isolated function validateUnsubscription(boolean isRemoteMethodAvailable, Unsubscription message, 
                                         http:Headers headers, HttpToWebsubhubAdaptor adaptor) returns error? {
    if isRemoteMethodAvailable {
        return adaptor.callOnUnsubscriptionValidationMethod(message, headers);
    } else {
        if !message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://") {
            return error SubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
    }
}
