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

# Processes the subscription request.
# 
# + request - Received `http:Request` instance
# + caller - The `http:Caller` reference of the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
# + isAvailable - Flag to notify whether an `onSubscription` is implemented in the `websubhub:Service`
# + isSubscriptionValidationAvailable - Flag to notify whether an `onSubscriptionValidation` is implemented in the `websubhub:Service`
# + hubUrl - Public URL in which the `hub` is running
# + defaultHubLeaseSeconds - The default subscription active timeout for the `hub`
# + config - The `websubhub:ClientConfiguration` to be used in the `http:Client` used for the subscription intent verification
isolated function processSubscriptionRequestAndRespond(http:Request request, http:Caller caller, http:Response response,
                                                       http:Headers headers, map<string> params, HttpToWebsubhubAdaptor adaptor,
                                                       boolean isAvailable, boolean isSubscriptionValidationAvailable, 
                                                       string hubUrl, int defaultHubLeaseSeconds, ClientConfiguration config) {

    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is ()) {
        respondToRequest(caller, response);
        return;
    }
    string? hubCallback = getEncodedValueOrUpdatedErrorResponse(params, HUB_CALLBACK, response);
    if (hubCallback is ()) {
        respondToRequest(caller, response);
        return;
    }
    var hubLeaseSeconds = params.removeIfHasKey(HUB_LEASE_SECONDS);
    if (hubLeaseSeconds is ()) {
        hubLeaseSeconds = defaultHubLeaseSeconds.toString();
    } else {
        var retrievedLeaseSeconds = 'int:fromString(hubLeaseSeconds);
        if (retrievedLeaseSeconds is error || retrievedLeaseSeconds == 0) {
            hubLeaseSeconds = defaultHubLeaseSeconds.toString();
        }
    }

    Subscription message = {
        hub: hubUrl,
        hubMode: MODE_SUBSCRIBE,
        hubCallback: <string> hubCallback,
        hubTopic: <string> topic,
        hubLeaseSeconds: hubLeaseSeconds,
        hubSecret: params[HUB_SECRET]
    };
    
    foreach var ['key, value] in params.entries() {
        message['key] = value;
    }

    if (!isAvailable) {
        response.statusCode = http:STATUS_ACCEPTED;
        respondToRequest(caller, response);
    } else {
        SubscriptionAccepted|SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect|
        BadSubscriptionError|InternalSubscriptionError|error onSubscriptionResult = adaptor.callOnSubscriptionMethod(
                                                                                        message, headers);
        if (onSubscriptionResult is SubscriptionTemporaryRedirect) {
            http:ListenerError? result = caller->redirect(
                response, http:REDIRECT_TEMPORARY_REDIRECT_307, onSubscriptionResult.redirectUrls);
        } else if (onSubscriptionResult is SubscriptionPermanentRedirect) {
           SubscriptionPermanentRedirect redirMsg = <SubscriptionPermanentRedirect> onSubscriptionResult;
           http:ListenerError? result = caller->redirect(
               response, http:REDIRECT_PERMANENT_REDIRECT_308, redirMsg.redirectUrls);
        } else if (onSubscriptionResult is SubscriptionAccepted) {
            response.statusCode = http:STATUS_ACCEPTED;
            respondToRequest(caller, response);
            error? result = proceedToValidationAndVerification(headers, adaptor, message, isSubscriptionValidationAvailable, config);
            if result is error {
                log:printError("Error occurred while unsubscription verification ", err = result.message());
            }
        } else if (onSubscriptionResult is BadSubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            var errorDetails = onSubscriptionResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onSubscriptionResult.message());
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            var errorDetails = onSubscriptionResult is InternalSubscriptionError ? onSubscriptionResult.detail() : INTERNAL_SUBSCRIPTION_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onSubscriptionResult.message());
            respondToRequest(caller, response);
        }
    }
}   

# Processes the subscription validation request.
# 
# + headers - The `http:Headers` received from the original `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
# + message - Subscriber details for the subscription request
# + isSubscriptionValidationAvailable - Flag to notify whether an `onSubscriptionValidation` is implemented in the `websubhub:Service`
# + config - The `websubhub:ClientConfiguration` to be used in the `http:Client` used for the subscription intent verification
# + return - `error` if there is any error in execution or else `()`
isolated function proceedToValidationAndVerification(http:Headers headers, HttpToWebsubhubAdaptor adaptor, Subscription message,
                                                     boolean isSubscriptionValidationAvailable, ClientConfiguration config) returns error? {
    SubscriptionDeniedError|error? validationResult = ();
    if (isSubscriptionValidationAvailable) {
        validationResult = adaptor.callOnSubscriptionValidationMethod(message, headers);
    } else {
        if (!message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://")) {
            validationResult = error SubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (!message.hubTopic.startsWith("http://") && !message.hubTopic.startsWith("https://")) {
            validationResult = error SubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    if (validationResult is SubscriptionDeniedError || validationResult is error) {
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=denied"
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + "hub.reason" + "=" + validationResult.message();
        http:Response validationFailureRequest = check sendSubscriptionNotification(message.hubCallback, queryParams, config);
    } else {
        string challenge = uuid:createType4AsString();
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=" + MODE_SUBSCRIBE
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + HUB_CHALLENGE + "=" + challenge
                            + "&" + HUB_LEASE_SECONDS + "=" + <string>message.hubLeaseSeconds;
        http:Response subscriberResponse = check sendSubscriptionNotification(message.hubCallback, queryParams, config);
        var respStringPayload = subscriberResponse.getTextPayload();
        if (respStringPayload is string) {
            if (respStringPayload == challenge) {
                VerifiedSubscription verifiedMessage = {
                    hub: message.hub,
                    verificationSuccess: true,
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
                    verificationSuccess: true,
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

# Dispatches the notifications to subscribers and retrieves the response.
# 
# + url - The base URL for the resource
# + queryString - Query parameters which should be appended to the base URL
# + config - The `websubhub:ClientConfiguration` to be used in the `http:Client` used for the subscription intent verification
# + return - `http:Response` if receives a successful response or else `error`
isolated function sendSubscriptionNotification(string url, string queryString, ClientConfiguration config) returns http:Response|error {
    string resourceUrl = string `${url}${queryString}`;
    http:Client httpClient = check  new(resourceUrl, retrieveHttpClientConfig(config));
    return httpClient->get("");
}
