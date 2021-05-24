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

# Processes the `topic` registration request.
# 
# + caller - The `http:Caller` reference of the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
isolated function processRegisterRequest(http:Caller caller, http:Response response,
                                         http:Headers headers, map<string> params, 
                                         HttpToWebsubhubAdaptor adaptor) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicRegistration msg = {
            topic: topic
        };
        TopicRegistrationSuccess|TopicRegistrationError|error result = adaptor.callRegisterMethod(msg, headers);
        if (result is TopicRegistrationSuccess) {
            updateSuccessResponse(response, result["body"], result["headers"]);
        } else {
            var errorDetails = result is TopicRegistrationError ? result.detail(): TOPIC_REGISTRATION_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        }
    }
}

# Processes the `topic` deregistration request.
# 
# + caller - The `http:Caller` reference of the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
isolated function processDeregisterRequest(http:Caller caller, http:Response response,
                                           http:Headers headers, map<string> params, 
                                           HttpToWebsubhubAdaptor adaptor) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicDeregistration msg = {
            topic: topic
        };
        TopicDeregistrationSuccess|TopicDeregistrationError|error result = adaptor.callDeregisterMethod(msg, headers);
        if (result is TopicDeregistrationSuccess) {
            updateSuccessResponse(response, result["body"], result["headers"]);
        } else {
            var errorDetails = result is TopicDeregistrationError ? result.detail() : TOPIC_DEREGISTRATION_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        }
    }
}

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
            proceedToValidationAndVerification(headers, adaptor, message, isSubscriptionValidationAvailable, config);
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
isolated function proceedToValidationAndVerification(http:Headers headers, HttpToWebsubhubAdaptor adaptor, Subscription message,
                                                     boolean isSubscriptionValidationAvailable, ClientConfiguration config) {
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

    http:Client httpClient = checkpanic new(<string> message.hubCallback, retrieveHttpClientConfig(config));
    string challenge = uuid:createType4AsString();

    if (validationResult is SubscriptionDeniedError || validationResult is error) {
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
                    error? errorResponse = adaptor.callOnSubscriptionIntentVerifiedMethod(verifiedMessage, headers);
                }
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
            proceedToUnsubscriptionVerification(
                request, headers, adaptor, message, isUnsubscriptionValidationAvailable, config);
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
isolated function proceedToUnsubscriptionVerification(http:Request initialRequest, http:Headers headers, HttpToWebsubhubAdaptor adaptor,
                                                      Unsubscription message, boolean isUnsubscriptionValidationAvailable, 
                                                      ClientConfiguration config) {

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

    http:Client httpClient = checkpanic new(<string> message.hubCallback, retrieveHttpClientConfig(config));
    if (validationResult is UnsubscriptionDeniedError|| validationResult is error) {
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
                    error? errorResponse = adaptor.callOnUnsubscriptionIntentVerifiedMethod(verifiedMessage, headers);
                }
            }
        }
    }
}

# Processes the publish-content request.
# 
# + caller - The `http:Caller` reference for the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor`
# + updateMsg - Content update message
isolated function processPublishRequestAndRespond(http:Caller caller, http:Response response,
                                                  http:Headers headers, HttpToWebsubhubAdaptor adaptor,
                                                  UpdateMessage updateMsg) {
    
    Acknowledgement|UpdateMessageError|error updateResult = adaptor.callOnUpdateMethod(updateMsg, headers);

    response.statusCode = http:STATUS_OK;
    if (updateResult is Acknowledgement) {
        response.setTextPayload("hub.mode=accepted");
        response.setHeader("Content-type","application/x-www-form-urlencoded");
    } else if (updateResult is UpdateMessageError) {
        var errorDetails = updateResult.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], updateResult.message());
    } else {
        var errorDetails = UPDATE_MESSAGE_ERROR.detail();
        updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], updateResult.message());
    }
    respondToRequest(caller, response);
}

# Retrieves an URL-encoded parameter.
# 
# + params - Available query parameters
# + 'key - Required parameter name/key
# + response - The `http:Response`, which should be returned 
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

# Updates the error response for a bad request.
# 
# + response - The `http:Response`, which should be returned 
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

# Updates the generic error response.
# 
# + response - The `http:Response`, which should be returned 
# + messageBody - Optional response payload
# + headers - Optional additional response headers
# + reason - Optional reason for rejecting the request
isolated function updateErrorResponse(http:Response response, anydata? messageBody, 
                                      map<string|string[]>? headers, string reason) {
    updateHubResponse(response, "denied", messageBody, headers, reason);
}

# Updates the generic success response.
# 
# + response - The `http:Response`, which should be returned 
# + messageBody - Optional response payload
# + headers - Optional additional response headers
isolated function updateSuccessResponse(http:Response response, anydata? messageBody, 
                                        map<string|string[]>? headers) {
    updateHubResponse(response, "accepted", messageBody, headers);
}

# Updates the `hub` response.
# 
# + response - The `http:Response`, which should be returned 
# + hubMode - Current Hub mode
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

# Generates the payload to be added to the `hub` Response.
# 
# + hubMode - Current Hub mode
# + messageBody - Optional response payload
# + reason - Optional reason for rejecting the request
# + return - Response payload as a `string`
isolated function generateResponsePayload(string hubMode, anydata? messageBody, string? reason) returns string {
    string payload = "hub.mode=" + hubMode;
    payload += reason is string ? "&hub.reason=" + reason : "";
    if (messageBody is map<string> && messageBody.length() > 0) {
        payload += "&" + retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
    }
    return payload;
}

# Generates the form-URL-encoded response payload.
#
# + messageBody - Provided response payload
# + return - The formed URL-encoded response body
isolated function retrieveTextPayloadForFormUrlEncodedMessage(map<string> messageBody) returns string {
    string payload = "";
    string[] messageParams = [];
    foreach var ['key, value] in messageBody.entries() {
        messageParams.push('key + "=" + value);
    }
    payload += strings:'join("&", ...messageParams);
    return payload;
}

# Converts a text payload to `map<string>`.
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
# + caller - The `http:Caller` reference of the current request
# + response - Updated `http:Response`
isolated function respondToRequest(http:Caller caller, http:Response response) {
    http:ListenerError? responseError = caller->respond(response);
}
