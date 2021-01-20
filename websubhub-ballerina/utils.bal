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
            updateErrorResponse(response, topic, registerStatus.message());
        } else {
            updateSuccessResponse(response, registerStatus["body"], registerStatus["headers"]);
        }
    }
}

isolated function processUnregisterRequest(http:Caller caller, http:Response response,
                                            map<string> params, Service hubService) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicUnregistration msg = {
            topic: topic
        };
        TopicUnregistrationSuccess|TopicUnregistrationError unregisterStatus = callUnregisterMethod(hubService, msg);
        if (unregisterStatus is TopicUnregistrationError) {
            updateErrorResponse(response, topic, unregisterStatus.message());
        } else {
            updateSuccessResponse(response, unregisterStatus["body"], unregisterStatus["headers"]);
        }
    }
}

function processSubscriptionRequestAndRespond(http:Caller caller, http:Response response,
                                              map<string> params, Service hubService,
                                              boolean isAvailable, boolean isSubscriptionValidationAvailable) {

    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is ()) {
        return;
    }
    string? hubCallback = getEncodedValueOrUpdatedErrorResponse(params, HUB_CALLBACK, response);
    if (hubCallback is ()) {
        return;
    }                             
    Subscription message = {
        hubMode: MODE_SUBSCRIBE,
        hubCallback: <string> hubCallback,
        hubTopic: <string> topic,
        hubLeaseSeconds: params[HUB_LEASE_SECONDS],
        hubSecret: params[HUB_SECRET]
    };
    if (!isAvailable) {
        response.statusCode = http:STATUS_ACCEPTED;
        respondToRequest(caller, response);
    } else {
        SubscriptionAccepted|SubscriptionRedirect|
        BadSubscriptionError|InternalSubscriptionError onSubscriptionResult = callOnSubscriptionMethod(hubService, message);
        if (onSubscriptionResult is SubscriptionRedirect) {
            SubscriptionRedirect redirMsg = <SubscriptionRedirect> onSubscriptionResult;
            response.statusCode = http:REDIRECT_TEMPORARY_REDIRECT_307;
            var result = caller->redirect(response, http:REDIRECT_TEMPORARY_REDIRECT_307,
                                                 onSubscriptionResult.redirectUrls);
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
        // todo L1 Validate if hub.secret present
        if (message.hubCallback == "") {
            validationResult = error SubscriptionDeniedError("Invalid hub.callback param in the request.");
        }
        if (message.hubTopic == "") {
            validationResult = error SubscriptionDeniedError("Invalid hub.topic param in the request.'");
        }
    }

    http:Client httpClient = checkpanic new(<string> message.hubCallback);
    string challenge = uuid:createType4AsString();

    if (validationResult is SubscriptionDeniedError) {
        http:Request request = new;
        string payload = "hub.mode=subscribe&hub.topic=" + <string> message.hubTopic + "&hub.reason=" + validationResult.message();
        request.setTextPayload(payload);
        request.setHeader("Content-type","application/x-www-form-urlencoded");
        var validationFailureRequest = httpClient->post("", request);
    } else {
        http:Request request = new;
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=" + MODE_SUBSCRIBE
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + HUB_CHALLENGE + "=" + challenge;
        var subscriberResponse = httpClient->get(<@untainted string> queryParams, request);
        if (subscriberResponse is http:Response) {
            var respStringPayload = subscriberResponse.getTextPayload();
            if (respStringPayload is string) {
                if (respStringPayload == challenge) {
                    VerifiedSubscription verifiedMessage = {
                        verificationSuccess: true,
                        hubMode: message.hubMode,
                        hubCallback: message.hubCallback,
                        hubTopic: message.hubTopic,
                        hubLeaseSeconds: message.hubLeaseSeconds,
                        hubSecret: message.hubSecret
                    };
                    callOnSubscriptionIntentVerifiedMethod(hubService, verifiedMessage);
                }
            }
        }
    }
}

function processUnsubscriptionRequestAndRespond(http:Caller caller, http:Response response,
                                              map<string> params, Service hubService,
                                              boolean isUnsubscriptionAvailable) {
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
        hubSecret: params[HUB_SECRET]
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
            proceedToVerification(hubService, message);
        } else if (onUnsubscriptionResult is BadUnsubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            respondToRequest(caller, response);
        } else {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            respondToRequest(caller, response);
        } 
    }
}

function proceedToVerification(Service hubService, Unsubscription message) {
    http:Client httpClient = checkpanic new(<string> message.hubCallback);
    http:Request request = new;

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
                    hubSecret: message.hubSecret
                };
                callOnUnsubscriptionIntentVerifiedMethod(hubService, verifiedMessage);
            }
        }
    }
}

function processPublishRequestAndRespond(http:Caller caller, http:Response response,
                                         Service hubService, UpdateMessage updateMsg) {
    
    Acknowledgement|UpdateMessageError updateResult = callOnUpdateMethod(hubService, updateMsg);

    response.statusCode = http:STATUS_ACCEPTED;
    if (updateResult is Acknowledgement) {
        response.setTextPayload("hub.mode=accepted");
        response.setHeader("Content-type","application/x-www-form-urlencoded");
    } else {
        updateErrorResponse(response, updateMsg.hubTopic is () ? "" : <string> updateMsg.hubTopic, updateResult.message());
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

isolated function updateErrorResponse(http:Response response, string topic, string reason) {
    string payload = "hub.mode=denied&hub.topic=" + topic + "&hub.reason=" + reason;
    response.setTextPayload(payload);
    response.setHeader("Content-type","application/x-www-form-urlencoded");
}

isolated function updateSuccessResponse(http:Response response, map<string>? messageBody, 
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
