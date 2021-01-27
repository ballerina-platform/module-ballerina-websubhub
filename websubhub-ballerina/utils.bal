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
import ballerina/encoding;
import ballerina/http;
import ballerina/uuid;

isolated function processRegisterRequest(http:Caller caller, http:Response response,
                                            map<string> params, Service hubService) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicRegistration msg = {
            topic: topic
        };

        TopicRegistrationSuccess|TopicRegistrationError registerStatus = callRegisterMethod(hubService, msg);
        if (registerStatus is TopicRegistrationError) {
            updateErrorResponse(response, registerStatus.message());
        } else {
            updateSuccessResponse(response, registerStatus["body"], registerStatus["headers"]);
        }
    }
}

isolated function processDeregisterRequest(http:Caller caller, http:Response response,
                                            map<string> params, Service hubService) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicDeregistration msg = {
            topic: topic
        };
        TopicDeregistrationSuccess|TopicDeregistrationError deregisterStatus = callDeregisterMethod(hubService, msg);
        if (deregisterStatus is TopicDeregistrationError) {
            updateErrorResponse(response, deregisterStatus.message());
        } else {
            updateSuccessResponse(response, deregisterStatus["body"], deregisterStatus["headers"]);
        }
    }
}

function processSubscriptionRequestAndRespond(http:Request request, http:Caller caller, http:Response response,
                                              map<string> params, Service hubService,
                                              boolean isAvailable, boolean isSubscriptionValidationAvailable, string hubUrl, int defaultHubLeaseSeconds) {

    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is ()) {
        return;
    }
    string? hubCallback = getEncodedValueOrUpdatedErrorResponse(params, HUB_CALLBACK, response);
    if (hubCallback is ()) {
        return;
    }

    var hubLeaseSeconds = params[HUB_LEASE_SECONDS];
    if (hubLeaseSeconds is () || 'int:fromString(hubLeaseSeconds) == 0) {
        hubLeaseSeconds = defaultHubLeaseSeconds.toString();
    }

    Subscription message = {
        hub: hubUrl,
        hubMode: MODE_SUBSCRIBE,
        hubCallback: <string> hubCallback,
        hubTopic: <string> topic,
        hubLeaseSeconds: hubLeaseSeconds,
        hubSecret: params[HUB_SECRET],
        rawRequest: request
    };
    if (!isAvailable) {
        response.statusCode = http:STATUS_ACCEPTED;
        respondToRequest(caller, response);
    } else {
        SubscriptionAccepted|SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect|
        BadSubscriptionError|InternalSubscriptionError onSubscriptionResult = callOnSubscriptionMethod(hubService, message);
        if (onSubscriptionResult is SubscriptionPermanentRedirect) {
            var result = caller->redirect(response, http:REDIRECT_TEMPORARY_REDIRECT_307, onSubscriptionResult.redirectUrls);
        } else if (onSubscriptionResult is SubscriptionPermanentRedirect) {
           SubscriptionPermanentRedirect redirMsg = <SubscriptionPermanentRedirect> onSubscriptionResult;
           var result = caller->redirect(response, http:REDIRECT_PERMANENT_REDIRECT_308, redirMsg.redirectUrls);
        } else if (onSubscriptionResult is SubscriptionAccepted) {
            response.statusCode = http:STATUS_ACCEPTED;
            respondToRequest(caller, response);
            proceedToValidationAndVerification(hubService, message, isSubscriptionValidationAvailable);
        } else if (onSubscriptionResult is BadSubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            respondToRequest(caller, response);
        }
    }
}   

function proceedToValidationAndVerification(Service hubService, Subscription message,
                                            boolean isSubscriptionValidationAvailable) {
    SubscriptionDeniedError? validationResult = ();
    if (isSubscriptionValidationAvailable) {
        validationResult = callOnSubscriptionValidationMethod(hubService, message);
    } else {
        if (!message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://")) {
            validationResult = error SubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (!message.hubTopic.startsWith("http://") && !message.hubTopic.startsWith("https://")) {
            validationResult = error SubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    http:Client httpClient = checkpanic new(<string> message.hubCallback);
    string challenge = uuid:createType4AsString();

    if (validationResult is SubscriptionDeniedError) {
        http:Request request = new;
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=denied"
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + "hub.reason" + "=" + validationResult.message();
        var validationFailureRequest = httpClient->get(<@untainted string> queryParams, request);
    } else {
        http:Request request = new;
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=" + MODE_SUBSCRIBE
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + HUB_CHALLENGE + "=" + challenge
                            + "&" + HUB_LEASE_SECONDS + "=" + <string>message.hubLeaseSeconds;
        var subscriberResponse = httpClient->get(<@untainted string> queryParams, request);
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
                        hubSecret: message.hubSecret,
                        rawRequest: request
                    };
                    callOnSubscriptionIntentVerifiedMethod(hubService, verifiedMessage);
                }
            }
        }
    }
}

function processUnsubscriptionRequestAndRespond(http:Request request, http:Caller caller, http:Response response,
                                              map<string> params, Service hubService,
                                              boolean isUnsubscriptionAvailable,
                                              boolean isUnsubscriptionValidationAvailable) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is ()) {
        return;
    }
    string? hubCallback = getEncodedValueOrUpdatedErrorResponse(params, HUB_CALLBACK, response);
    if (hubCallback is ()) {
        return;
    } 
    Unsubscription message = {
        hubMode: MODE_SUBSCRIBE,
        hubCallback: <string> hubCallback,
        hubTopic: <string> topic,
        hubSecret: params[HUB_SECRET],
        rawRequest: request
    };
    if (!isUnsubscriptionAvailable) {
        response.statusCode = http:STATUS_ACCEPTED;
        respondToRequest(caller, response);
    } else {
        UnsubscriptionAccepted|BadUnsubscriptionError
            |InternalUnsubscriptionError onUnsubscriptionResult = callOnUnsubscriptionMethod(hubService, message);
        if (onUnsubscriptionResult is UnsubscriptionAccepted) {
            response.statusCode = http:STATUS_ACCEPTED;
            respondToRequest(caller, response);
            proceedToUnsubscriptionVerification(request, hubService, message, isUnsubscriptionValidationAvailable);
        } else if (onUnsubscriptionResult is BadUnsubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            respondToRequest(caller, response);
        } 
    }
}

function proceedToUnsubscriptionVerification(http:Request initialRequest, Service hubService, Unsubscription message,
                                            boolean isUnsubscriptionValidationAvailable) {

    UnsubscriptionDeniedError? validationResult = ();
    if (isUnsubscriptionValidationAvailable) {
        validationResult = callOnUnsubscriptionValidationMethod(hubService, message);
    } else {
        if (!message.hubCallback.startsWith("http://") && !message.hubCallback.startsWith("https://")) {
            validationResult = error UnsubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (!message.hubTopic.startsWith("http://") && !message.hubTopic.startsWith("https://")) {
            validationResult = error UnsubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    http:Client httpClient = checkpanic new(<string> message.hubCallback);
    http:Request request = new;
    if (validationResult is UnsubscriptionDeniedError) {
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=denied"
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + "hub.reason" + "=" + validationResult.message();
        var validationFailureRequest = httpClient->get(<@untainted string> queryParams, request);
    } else {
        string challenge = uuid:createType4AsString();
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                                + HUB_MODE + "=" + MODE_UNSUBSCRIBE
                                + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                                + "&" + HUB_CHALLENGE + "=" + challenge;
        var subscriberResponse = httpClient->get(<@untainted string> queryParams, request);
        if (subscriberResponse is http:Response) {
            var respStringPayload = subscriberResponse.getTextPayload();
            if (respStringPayload is string) {
                if (respStringPayload == challenge) {
                    VerifiedUnsubscription verifiedMessage = {
                        verificationSuccess: true,
                        hubMode: message.hubMode,
                        hubCallback: message.hubCallback,
                        hubTopic: message.hubTopic,
                        hubSecret: message.hubSecret,
                        rawRequest: initialRequest
                    };
                    callOnUnsubscriptionIntentVerifiedMethod(hubService, verifiedMessage);
                }
            }
        }
    }
}

function processPublishRequestAndRespond(http:Caller caller, http:Response response,
                                         Service hubService, UpdateMessage updateMsg) {
    
    Acknowledgement|UpdateMessageError updateResult = callOnUpdateMethod(hubService, updateMsg);

    response.statusCode = http:STATUS_OK;
    if (updateResult is Acknowledgement) {
        response.setTextPayload("hub.mode=accepted");
        response.setHeader("Content-type","application/x-www-form-urlencoded");
    } else {
        updateErrorResponse(response, updateResult.message());
    }
    respondToRequest(caller, response);
}

isolated function getEncodedValueOrUpdatedErrorResponse(map<string> params, string 'key, http:Response response) 
                                            returns string? {
    string|error? topic = ();
    var topicFromParams = params['key];
    if topicFromParams is string {
        topic = encoding:decodeUriComponent(topicFromParams, "UTF-8");
    }
    if (topic is string && topic != "") {
       return <string> topic;
    } else {
        updateBadRequestErrorResponse(response, 'key, topic);
        return ();
    }
}

isolated function updateBadRequestErrorResponse(http:Response response, string paramName, string|error? topicParameter) {
    string errorMessage = "";
    if (topicParameter is error) {
        errorMessage = "Invalid value found for parameter '" + paramName + "' : " + topicParameter.message();
    } else {
        errorMessage = "Empty value found for parameter '" + paramName + "'"; 
    }
    response.statusCode = http:STATUS_BAD_REQUEST;
    response.setTextPayload(errorMessage);
}

isolated function updateErrorResponse(http:Response response, string reason) {
    string payload = "hub.mode=denied" + "&hub.reason=" + reason;
    response.setTextPayload(payload);
    response.setHeader("Content-type","application/x-www-form-urlencoded");
}

isolated function updateSuccessResponse(http:Response response, anydata? messageBody, 
                                        map<string|string[]>? headers) {
    string payload = "hub.mode=accepted";
    if (messageBody is map<string>) {
        foreach var ['key, value] in messageBody.entries() {
            payload = payload + "&" + 'key + "=" + value;
        }
    }
    response.setTextPayload(payload);
    response.setHeader("Content-type","application/x-www-form-urlencoded");
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

isolated function respondToRequest(http:Caller caller, http:Response response) {
    var responseError = caller->respond(response);
}
