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
import ballerina/log;
import ballerina/uuid;

isolated function processRegisterRequest(http:Caller caller, http:Response response,
                                            map<string> params, HubService hubService) {
    string? topicVar = getEncodedValueFromRequest(params, HUB_TOPIC);
    string topic = topicVar is () ? "" : topicVar;
    RegisterTopicMessage msg = {
        topic: topic
    };

    TopicRegistrationSuccess|TopicRegistrationError registerStatus = callRegisterMethod(hubService, msg);
    if (registerStatus is TopicRegistrationError) {
        updateErrorResponse(response, topic, registerStatus.message());
        log:print("Topic registration unsuccessful at Hub for Topic [" + topic + "]: " + registerStatus.message());
    } else {
        updateSuccessResponse(response, registerStatus["body"], registerStatus["headers"]);
        log:print("Topic registration successful at Hub, for topic[" + topic + "]");
    }
}

isolated function processUnregisterRequest(http:Caller caller, http:Response response,
                                            map<string> params, HubService hubService) {
    string? topicVar = getEncodedValueFromRequest(params, HUB_TOPIC);
    string topic = topicVar is () ? "" : topicVar;
    UnregisterTopicMessage msg = {
        topic: topic
    };
    TopicUnregistrationSuccess|TopicUnregistrationError unregisterStatus = callUnregisterMethod(hubService, msg);
    if (unregisterStatus is TopicUnregistrationError) {
        updateErrorResponse(response, topic, unregisterStatus.message());
        log:print("Topic unregistration unsuccessful at Hub for Topic [" + topic + "]: " + unregisterStatus.message());
    } else {
        updateSuccessResponse(response, unregisterStatus["body"], unregisterStatus["headers"]);
        log:print("Topic registration successful at Hub, for topic[" + topic + "]");
    }
}

function processSubscriptionRequestAndRespond(http:Caller caller, http:Response response,
                                              map<string> params, HubService hubService,
                                              boolean isAvailable, boolean isSubscriptionValidationAvailable) {

    SubscriptionMessage message = {
        hubMode: MODE_SUBSCRIBE,
        hubCallback: getEncodedValueFromRequest(params, HUB_CALLBACK),
        hubTopic: getEncodedValueFromRequest(params, HUB_TOPIC),
        hubLeaseSeconds: params[HUB_LEASE_SECONDS],
        hubSecret: params[HUB_LEASE_SECONDS]
    };
    if (!isAvailable) {
        response.statusCode = http:STATUS_ACCEPTED;
        respondToRequest(caller, response);
    } else {
        SubscriptionAccepted|SubscriptionRedirect|
        BadSubscriptionError|InternalSubscriptionError onSubscriptionResult = callOnSubscriptionMethod(hubService, message);
        if (onSubscriptionResult is BadSubscriptionError) {
            response.statusCode = http:STATUS_BAD_REQUEST;
            respondToRequest(caller, response);
        } else if (onSubscriptionResult is InternalSubscriptionError) {
            response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
            respondToRequest(caller, response);
        } else {
            //todo Redirect record is not done
            response.statusCode = http:STATUS_ACCEPTED;
            respondToRequest(caller, response);
            proceedToValidationAndVerification(hubService, message, isSubscriptionValidationAvailable);
        } 
        
    //    else if (onSubscriptionResult is SubscriptionRedirect) {
    //         SubscriptionRedirect redirMsg = <SubscriptionRedirect> onSubscriptionResult;
    //         response.statusCode = http:REDIRECT_TEMPORARY_REDIRECT_307;
    //         var result = caller->redirect(response, http:REDIRECT_TEMPORARY_REDIRECT_307, 
    //                                     onSubscriptionResult.redirectUrls);
    //         if (result is error) {
    //             log:printError("Error in sending redirect response to caller", err = result);
    //         }
    //    } 
    }
}   

function proceedToValidationAndVerification(HubService hubService, SubscriptionMessage message, 
                                                    boolean isSubscriptionValidationAvailable) {
    SubscriptionDenied? validationResult = ();
    if (isSubscriptionValidationAvailable) {
        validationResult = callOnSubscriptionValidationMethod(hubService, message);
    } else {
        if (message.hubCallback is () || message.hubCallback == "") {
            validationResult = error SubscriptionDenied("Invalid hub.callback param in the request.");
        }
        if (message.hubTopic is () || message.hubTopic == "") {
            validationResult = error SubscriptionDenied("Invalid hub.topic param in the request.'");
        }
    }

    http:Client httpClient = checkpanic new(<string> message.hubCallback);
    string challenge = uuid:createType4AsString();

    if (validationResult is SubscriptionDenied) {
        http:Request request = new;
        string payload = "hub.mode=subscribe&hub.topic=" + <string> message.hubTopic + "&hub.reason=" + validationResult.message();
        request.setTextPayload(payload);
        request.setHeader("Content-type","application/x-www-form-urlencoded");
        var validationFailureRequest = httpClient->post("", request);
        if (validationFailureRequest is error) {
            log:printError("Failed to notify subscriber of subscription validation failure", err = validationFailureRequest);
        }
    } else {
        http:Request request = new;
        string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=" + MODE_SUBSCRIBE
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + HUB_CHALLENGE + "=" + challenge;
        log:print("Sending intent verification request to callback[" + <string> message.hubCallback + 
                    "] for topic[" + <string> message.hubTopic + "]");
        var subscriberResponse = httpClient->get(<@untainted string> queryParams, request);
        if (subscriberResponse is http:Response) {
            var respStringPayload = subscriberResponse.getTextPayload();
            if (respStringPayload is string) {
                if (respStringPayload != challenge) {
                    log:print("Intent verification failed for mode: [" + MODE_SUBSCRIBE + "], for callback URL: ["
                            + <string> message.hubCallback + "]: Challenge not echoed correctly.");
                } else {
                    VerifiedSubscriptionMessage verifiedMessage = {
                        verificationSuccess: true,
                        hubMode: message.hubMode,
                        hubCallback: message.hubCallback,
                        hubTopic: message.hubTopic,
                        hubLeaseSeconds: message.hubLeaseSeconds,
                        hubSecret: message.hubSecret
                    };
                    callOnSubscriptionIntentVerifiedMethod(hubService, verifiedMessage);
                }
            } else {
                log:print("Intent verification failed for mode: [" + MODE_SUBSCRIBE + "], for callback URL: ["
                            + <string> message.hubCallback + "]: Challenge not echoed correctly.");
            }
        }
    }
}

function processUnsubscriptionRequestAndRespond(http:Caller caller, http:Response response,
                                              map<string> params, HubService hubService,
                                              boolean isUnsubscriptionAvailable) {
    UnsubscriptionMessage message = {
        hubMode: MODE_SUBSCRIBE,
        hubCallback: getEncodedValueFromRequest(params, HUB_CALLBACK),
        hubTopic: getEncodedValueFromRequest(params, HUB_TOPIC),
        hubSecret: params[HUB_LEASE_SECONDS]
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

function proceedToVerification(HubService hubService, UnsubscriptionMessage message) {
    http:Client httpClient = checkpanic new(<string> message.hubCallback);
    http:Request request = new;

    string challenge = uuid:createType4AsString();
    string queryParams = (strings:includes(<string> message.hubCallback, ("?")) ? "&" : "?")
                            + HUB_MODE + "=" + MODE_UNSUBSCRIBE
                            + "&" + HUB_TOPIC + "=" + <string> message.hubTopic
                            + "&" + HUB_CHALLENGE + "=" + challenge;
    log:print("Sending unsubscribing intent verification request to callback[" + <string> message.hubCallback + 
                    "] for topic[" + <string> message.hubTopic + "]");
    var subscriberResponse = httpClient->get(<@untainted string> queryParams, request);
    if (subscriberResponse is http:Response) {
        var respStringPayload = subscriberResponse.getTextPayload();
        if (respStringPayload is string) {
            if (respStringPayload != challenge) {
                log:print("Intent verification failed for mode: [" + MODE_UNSUBSCRIBE + "], for callback URL: ["
                        + <string> message.hubCallback + "]: Challenge not echoed correctly.");
            } else {
                VerifiedUnsubscriptionMessage verifiedMessage = {
                    verificationSuccess: true,
                    hubMode: message.hubMode,
                    hubCallback: message.hubCallback,
                    hubTopic: message.hubTopic,
                    hubSecret: message.hubSecret
                };
                callOnUnsubscriptionIntentVerifiedMethod(hubService, verifiedMessage);
            }
        } else {
            log:print("Intent verification failed for mode: [" + MODE_UNSUBSCRIBE + "], for callback URL: ["
                        + <string> message.hubCallback + "]: Challenge not echoed correctly.");
        }
    }
}

function processPublishRequestAndRespond(http:Caller caller, http:Response response,
                                         HubService hubService, UpdateMessage updateMsg) {
    
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

isolated function getEncodedValueFromRequest(map<string> params, string 'key) returns string? {
    string? topic = ();
    var topicFromParams = params['key];
    if topicFromParams is string {
        var decodedValue = encoding:decodeUriComponent(topicFromParams, "UTF-8");
        topic = decodedValue is string ? decodedValue : topicFromParams;
    }
    return topic;
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
    if (responseError is error) {
        log:printError("Error responding remote topic registration status", err = responseError);
    }
}
