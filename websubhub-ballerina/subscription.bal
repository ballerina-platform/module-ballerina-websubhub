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
import ballerina/log;
import ballerina/lang.'string as strings;
import ballerina/uuid;

isolated function createSubscriptionMessage(string hubUrl, int defaultHubLeaseSeconds, map<string> params) returns Subscription|error {
    string topic = check retrieveParameter(params, HUB_TOPIC);
    string hubCallback = check retrieveParameter(params, HUB_CALLBACK);
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
                                      HttpToWebsubhubAdaptor adaptor, boolean isAvailable) returns http:Response|Redirect {
    if !isAvailable {
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
                                                  boolean isSubscriptionValidationAvailable, ClientConfiguration config) returns error? {
    error? validationResult = validateSubscription(isSubscriptionValidationAvailable, message, headers, adaptor);
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

isolated function sendNotification(string callbackUrl, [string, string?][] params, ClientConfiguration config) returns http:Response|error {
    string queryParams = generateQueryString(callbackUrl, params);
    http:Client httpClient = check  new(callbackUrl, retrieveHttpClientConfig(config));
    return httpClient->get(queryParams);
}

# Processes the unsubscription request.
# 
# + request - Received `http:Request` instance
# + caller - The `http:Caller` reference of the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
# + isUnsubscriptionAvailable - Flag to notify whether an `onUnsubscription` is implemented in the `websubhub:Service`
# + isUnsubscriptionValidationAvailable - Flag to notify whether an `onUnsubscriptionValidation` is implemented in the `websubhub:Service`
# + config - The `websubhub:ClientConfiguration` to be used in the `http:Client` used for the subscription intent verification
isolated function processUnsubscriptionRequestAndRespond(http:Request request, http:Caller caller, http:Response response, 
                                                         http:Headers headers, map<string> params, HttpToWebsubhubAdaptor adaptor,
                                                         boolean isUnsubscriptionAvailable, boolean isUnsubscriptionValidationAvailable, 
                                                         ClientConfiguration config) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is ()) {
        return;
    }
    string? hubCallback = getEncodedValueOrUpdatedErrorResponse(params, HUB_CALLBACK, response);
    if (hubCallback is ()) {
        return;
    } 

    Unsubscription message = {
        hubMode: MODE_UNSUBSCRIBE,
        hubCallback: <string> hubCallback,
        hubTopic: <string> topic,
        hubSecret: params.removeIfHasKey(HUB_SECRET)
    };
    
    foreach var ['key, value] in params.entries() {
        message['key] = value;
    }

    if (!isUnsubscriptionAvailable) {
        response.statusCode = http:STATUS_ACCEPTED;
        respondToRequest(caller, response);
    } else {
        UnsubscriptionAccepted|BadUnsubscriptionError
            |InternalUnsubscriptionError|error onUnsubscriptionResult = adaptor.callOnUnsubscriptionMethod(
                                                                            message, headers);
        if (onUnsubscriptionResult is UnsubscriptionAccepted) {
            response.statusCode = http:STATUS_ACCEPTED;
            respondToRequest(caller, response);
            error? result = proceedToUnsubscriptionVerification(request, headers, adaptor, message, isUnsubscriptionValidationAvailable, config);
            if result is error {
                log:printError("Error occurred while unsubscription verification ", err = result.message());
            }
        } else if (onUnsubscriptionResult is BadUnsubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            var errorDetails = onUnsubscriptionResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onUnsubscriptionResult.message());
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            var errorDetails = onUnsubscriptionResult is InternalUnsubscriptionError ? onUnsubscriptionResult.detail(): INTERNAL_UNSUBSCRIPTION_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onUnsubscriptionResult.message());
            respondToRequest(caller, response);
        } 
    }
}

# Processes the unsubscription validation request.
#
# + initialRequest - Original `http:Request` instance
# + headers - The `http:Headers` received from the original `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor`
# + message - Subscriber details for the unsubscription request
# + isUnsubscriptionValidationAvailable - Flag to notify whether an `onSubscriptionValidation` is implemented in the `websubhub:Service`
# + config - The `websubhub:ClientConfiguration` to be used in the `http:Client` used for the subscription intent verification
# + return - `error` if there is any error in execution or else `()`
isolated function proceedToUnsubscriptionVerification(http:Request initialRequest, http:Headers headers, HttpToWebsubhubAdaptor adaptor,
                                                      Unsubscription message, boolean isUnsubscriptionValidationAvailable, 
                                                      ClientConfiguration config) returns error? {
    UnsubscriptionDeniedError|error? validationResult = ();
    if (isUnsubscriptionValidationAvailable) {
        validationResult = adaptor.callOnUnsubscriptionValidationMethod(message, headers);
    } else {
        if (!message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://")) {
            validationResult = error UnsubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (!message.hubTopic.startsWith("http://") && !message.hubTopic.startsWith("https://")) {
            validationResult = error UnsubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    if (validationResult is UnsubscriptionDeniedError|| validationResult is error) {
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=denied"
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + "hub.reason" + "=" + validationResult.message();
        http:Response validationFailureRequest = check sendSubscriptionNotification(message.hubCallback, queryParams, config);
    } else {
        string challenge = uuid:createType4AsString();
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                                + HUB_MODE + "=" + MODE_UNSUBSCRIBE
                                + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                                + "&" + HUB_CHALLENGE + "=" + challenge;
        http:Response subscriberResponse = check sendSubscriptionNotification(message.hubCallback, queryParams, config);
        var respStringPayload = subscriberResponse.getTextPayload();
        if (respStringPayload is string) {
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
}

isolated function sendSubscriptionNotification(string url, string queryString, ClientConfiguration config) returns http:Response|error {
    http:Client httpClient = check  new(url, retrieveHttpClientConfig(config));
    return httpClient->get(queryString);
}
