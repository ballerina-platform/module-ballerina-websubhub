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

import ballerina/lang.'string as strings;
import ballerina/url;
import ballerina/http;
import ballerina/uuid;
import ballerina/regex;

# Processes `topic` registration request.
# 
# + caller - The `http:Caller` reference for the current request
# + response - The `http:Response` which should be returned 
# + headers - The `http:Headers` received from original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + hubService - Current `websubhub:Service`
isolated function processRegisterRequest(http:Caller caller, http:Response response,
                                         http:Headers headers, map<string> params, 
                                         Service hubService) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicRegistration msg = {
            topic: topic
        };

        TopicRegistrationSuccess|TopicRegistrationError result = callRegisterMethod(hubService, msg, headers);
        if (result is TopicRegistrationError) {
            var errorDetails = result.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        } else {
            updateSuccessResponse(response, result["body"], result["headers"]);
        }
    }
}

# Processes `topic` deregistration request.
# 
# + caller - The `http:Caller` reference for the current request
# + response - The `http:Response` which should be returned 
# + headers - The `http:Headers` received from original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + hubService - Current `websubhub:Service`
isolated function processDeregisterRequest(http:Caller caller, http:Response response,
                                           http:Headers headers, map<string> params, 
                                           Service hubService) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicDeregistration msg = {
            topic: topic
        };
        TopicDeregistrationSuccess|TopicDeregistrationError result = callDeregisterMethod(hubService, msg, headers);
        if (result is TopicDeregistrationError) {
            var errorDetails = result.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        } else {
            updateSuccessResponse(response, result["body"], result["headers"]);
        }
    }
}

# Processes subscription request.
# 
# + request - Received `http:Request` instance
# + caller - The `http:Caller` reference for the current request
# + response - The `http:Response` which should be returned 
# + headers - The `http:Headers` received from original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + hubService - Current `websubhub:Service`
# + isAvailable - Flag to notify whether `onSubscription` is implemented in `websubhub:Service`
# + isSubscriptionValidationAvailable - Flag to notify whether `onSubscriptionValidation` is implemented in `websubhub:Service`
# + hubUrl - Public URL in which the `hub` is running
# + defaultHubLeaseSeconds - Default subscription active timeout for `hub`
# + config - `websubhub:ClientConfiguration` to be used in `http:Client` used for subscription intent verification
isolated function processSubscriptionRequestAndRespond(http:Request request, http:Caller caller, http:Response response,
                                                       http:Headers headers, map<string> params, Service hubService,
                                                       boolean isAvailable, boolean isSubscriptionValidationAvailable, 
                                                       string hubUrl, int defaultHubLeaseSeconds, ClientConfiguration config) {

    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is ()) {
        return;
    }
    string? hubCallback = getEncodedValueOrUpdatedErrorResponse(params, HUB_CALLBACK, response);
    if (hubCallback is ()) {
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
        BadSubscriptionError|InternalSubscriptionError onSubscriptionResult = callOnSubscriptionMethod(
                                                                                        hubService, message, headers);
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
            proceedToValidationAndVerification(headers, hubService, message, isSubscriptionValidationAvailable, config);
        } else if (onSubscriptionResult is BadSubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            var errorDetails = onSubscriptionResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onSubscriptionResult.message());
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            onSubscriptionResult = <InternalSubscriptionError>onSubscriptionResult;
            var errorDetails = onSubscriptionResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onSubscriptionResult.message());
            respondToRequest(caller, response);
        }
    }
}   

# Processes subscription validation request.
# 
# + headers - The `http:Headers` received from original `http:Request`
# + hubService - Current `websubhub:Service`
# + message - Subscriber details for subscription request
# + isSubscriptionValidationAvailable - Flag to notify whether `onSubscriptionValidation` is implemented in `websubhub:Service`
# + config - `websubhub:ClientConfiguration` to be used in `http:Client` used for subscription intent verification
isolated function proceedToValidationAndVerification(http:Headers headers, Service hubService, Subscription message,
                                                     boolean isSubscriptionValidationAvailable, ClientConfiguration config) {
    SubscriptionDeniedError? validationResult = ();
    if (isSubscriptionValidationAvailable) {
        validationResult = callOnSubscriptionValidationMethod(hubService, message, headers);
    } else {
        if (!message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://")) {
            validationResult = error SubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (!message.hubTopic.startsWith("http://") && !message.hubTopic.startsWith("https://")) {
            validationResult = error SubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    http:Client httpClient = checkpanic new(<string> message.hubCallback, retrieveHttpClientConfig(config));
    string challenge = uuid:createType4AsString();

    if (validationResult is SubscriptionDeniedError) {
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=denied"
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + "hub.reason" + "=" + validationResult.message();
        http:ClientError|http:Response validationFailureRequest = httpClient->get(<@untainted string> queryParams);
    } else {
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=" + MODE_SUBSCRIBE
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + HUB_CHALLENGE + "=" + challenge
                            + "&" + HUB_LEASE_SECONDS + "=" + <string>message.hubLeaseSeconds;
        http:ClientError|http:Response subscriberResponse = httpClient->get(<@untainted string> queryParams);
        if (subscriberResponse is http:Response) {
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
                    callOnSubscriptionIntentVerifiedMethod(hubService, verifiedMessage, headers);
                }
            }
        }
    }
}

# Processes unsubscription request.
# 
# + request - Received `http:Request` instance
# + caller - The `http:Caller` reference for the current request
# + response - The `http:Response` which should be returned 
# + headers - The `http:Headers` received from original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + hubService - Current `websubhub:Service`
# + isUnsubscriptionAvailable - Flag to notify whether `onUnsubscription` is implemented in `websubhub:Service`
# + isUnsubscriptionValidationAvailable - Flag to notify whether `onUnsubscriptionValidation` is implemented in `websubhub:Service`
# + config - `websubhub:ClientConfiguration` to be used in `http:Client` used for subscription intent verification
isolated function processUnsubscriptionRequestAndRespond(http:Request request, http:Caller caller, http:Response response, 
                                                         http:Headers headers, map<string> params, Service hubService,
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
            |InternalUnsubscriptionError onUnsubscriptionResult = callOnUnsubscriptionMethod(
                                                                            hubService, message, headers);
        if (onUnsubscriptionResult is UnsubscriptionAccepted) {
            response.statusCode = http:STATUS_ACCEPTED;
            respondToRequest(caller, response);
            proceedToUnsubscriptionVerification(
                request, headers, hubService, message, isUnsubscriptionValidationAvailable, config);
        } else if (onUnsubscriptionResult is BadUnsubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            var errorDetails = onUnsubscriptionResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onUnsubscriptionResult.message());
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            onUnsubscriptionResult = <InternalUnsubscriptionError>onUnsubscriptionResult;
            var errorDetails = onUnsubscriptionResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], onUnsubscriptionResult.message());
            respondToRequest(caller, response);
        } 
    }
}

# Processes unsubscription validation request.
#
# + initialRequest - Original `http:Request` instance
# + headers - The `http:Headers` received from original `http:Request`
# + hubService - Current `websubhub:Service`
# + message - Subscriber details for unsubscription request
# + isUnsubscriptionValidationAvailable - Flag to notify whether `onSubscriptionValidation` is implemented in `websubhub:Service`
# + config - `websubhub:ClientConfiguration` to be used in `http:Client` used for subscription intent verification
isolated function proceedToUnsubscriptionVerification(http:Request initialRequest, http:Headers headers, Service hubService, 
                                                      Unsubscription message, boolean isUnsubscriptionValidationAvailable, 
                                                      ClientConfiguration config) {

    UnsubscriptionDeniedError? validationResult = ();
    if (isUnsubscriptionValidationAvailable) {
        validationResult = callOnUnsubscriptionValidationMethod(hubService, message, headers);
    } else {
        if (!message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://")) {
            validationResult = error UnsubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (!message.hubTopic.startsWith("http://") && !message.hubTopic.startsWith("https://")) {
            validationResult = error UnsubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    http:Client httpClient = checkpanic new(<string> message.hubCallback, retrieveHttpClientConfig(config));
    if (validationResult is UnsubscriptionDeniedError) {
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=denied"
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + "hub.reason" + "=" + validationResult.message();
        http:ClientError|http:Response validationFailureRequest = httpClient->get(<@untainted string> queryParams);
    } else {
        string challenge = uuid:createType4AsString();
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                                + HUB_MODE + "=" + MODE_UNSUBSCRIBE
                                + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                                + "&" + HUB_CHALLENGE + "=" + challenge;
        http:ClientError|http:Response subscriberResponse = httpClient->get(<@untainted string> queryParams);
        if (subscriberResponse is http:Response) {
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
                    callOnUnsubscriptionIntentVerifiedMethod(hubService, verifiedMessage, headers);
                }
            }
        }
    }
}

# Processes publish content request.
# 
# + caller - The `http:Caller` reference for the current request
# + response - The `http:Response` which should be returned 
# + headers - The `http:Headers` received from original `http:Request`
# + hubService - Current `websubhub:Service`
# + updateMsg - Content update message
isolated function processPublishRequestAndRespond(http:Caller caller, http:Response response,
                                                  http:Headers headers, Service hubService, 
                                                  UpdateMessage updateMsg) {
    
    Acknowledgement|UpdateMessageError updateResult = callOnUpdateMethod(hubService, updateMsg, headers);

    response.statusCode = http:STATUS_OK;
    if (updateResult is Acknowledgement) {
        response.setTextPayload("hub.mode=accepted");
        response.setHeader("Content-type","application/x-www-form-urlencoded");
    } else {
        var errorDetails = updateResult.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], updateResult.message());
    }
    respondToRequest(caller, response);
}

# Retrieves url-encoded parameter.
# 
# + params - Available query parameters
# + 'key - Required parameter name/key
# + response - The `http:Response` which should be returned 
# + return - Requested parameter value if present or else `()`
isolated function getEncodedValueOrUpdatedErrorResponse(map<string> params, string 'key, 
                                                        http:Response response) returns string? {
    string|error? requestedValue = ();
    var retrievedValue = params.removeIfHasKey('key);
    if retrievedValue is string {
        requestedValue = url:decode(retrievedValue, "UTF-8");
    }
    if (requestedValue is string && requestedValue != "") {
       return <string> requestedValue;
    } else {
        updateBadRequestErrorResponse(response, 'key, requestedValue);
        return ();
    }
}

# Updates error response for Bad Request.
# 
# + response - The `http:Response` which should be returned 
# + paramName - Errorneous parameter name
# + topicParameter - Received value or `error`
isolated function updateBadRequestErrorResponse(http:Response response, string paramName, 
                                                string|error? topicParameter) {
    string errorMessage = "";
    if (topicParameter is error) {
        errorMessage = "Invalid value found for parameter '" + paramName + "' : " + topicParameter.message();
    } else {
        errorMessage = "Empty value found for parameter '" + paramName + "'"; 
    }
    response.statusCode = http:STATUS_BAD_REQUEST;
    response.setTextPayload(errorMessage);
}

# Updates generic error response.
# 
# + response - The `http:Response` which should be returned 
# + messageBody - Optional response payload
# + headers - Optional additional response headers
# + reason - Optional reason for rejecting the request
isolated function updateErrorResponse(http:Response response, anydata? messageBody, 
                                      map<string|string[]>? headers, string reason) {
    updateHubResponse(response, "denied", messageBody, headers, reason);
}

# Updates generic success response.
# 
# + response - The `http:Response` which should be returned 
# + messageBody - Optional response payload
# + headers - Optional additional response headers
isolated function updateSuccessResponse(http:Response response, anydata? messageBody, 
                                        map<string|string[]>? headers) {
    updateHubResponse(response, "accepted", messageBody, headers);
}

# Updates `hub` response.
# 
# + response - The `http:Response` which should be returned 
# + hubMode - Current Hub Mode
# + messageBody - Optional response payload
# + headers - Optional additional response headers
# + reason - Optional reason for rejecting the request
isolated function updateHubResponse(http:Response response, string hubMode, 
                                    anydata? messageBody, map<string|string[]>? headers, 
                                    string? reason = ()) {
    response.setHeader("Content-type","application/x-www-form-urlencoded");

    string payload = generateResponsePayload(hubMode, messageBody, reason);

    response.setTextPayload(payload);

    if (headers is map<string|string[]>) {
        foreach var [header, value] in headers.entries() {
            if (value is string) {
                response.setHeader(header, value);
            } else {
                foreach var valueElement in value {
                    response.addHeader(header, valueElement);
                }
            }
        }
    }
}

# Generates payload to be added to the `hub` Response.
# 
# + hubMode - Current Hub Mode
# + messageBody - Optional response payload
# + reason - Optional reason for rejecting the request
# + return - Response payload as `string`
isolated function generateResponsePayload(string hubMode, anydata? messageBody, string? reason) returns string {
    string payload = "hub.mode=" + hubMode;
    payload += reason is string ? "&hub.reason=" + reason : "";
    if (messageBody is map<string> && messageBody.length() > 0) {
        payload += "&" + retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
    }
    return payload;
}

# Generates form-url-encoded response payload.
#
# + messageBody - Provided response payload
# + return - Form URL encoded response body
isolated function retrieveTextPayloadForFormUrlEncodedMessage(map<string> messageBody) returns string {
    string payload = "";
    string[] messageParams = [];
    foreach var ['key, value] in messageBody.entries() {
        messageParams.push('key + "=" + value);
    }
    payload += strings:'join("&", ...messageParams);
    return payload;
}

# Converts text payload to `map<string>`.
# 
# + payload - Received text payload
# + return - Response payload as `map<string>`
isolated function retrieveResponseBodyForFormUrlEncodedMessage(string payload) returns map<string> {
    map<string> responsePayload = {};
    string[] queryParams = regex:split(payload, "&");
    foreach var query in queryParams {
        string[] keyValueEntry = regex:split(query, "=");
        if (keyValueEntry.length() == 2) {
            responsePayload[keyValueEntry[0]] = keyValueEntry[1];
        }
    }
    return responsePayload;
}

# Responds to the received `http:Request`.
# 
# + caller - The `http:Caller` reference for the current request
# + response - Updated `http:Response`
isolated function respondToRequest(http:Caller caller, http:Response response) {
    http:ListenerError? responseError = caller->respond(response);
}
