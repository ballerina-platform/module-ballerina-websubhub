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
import ballerina/mime;
import ballerina/java;

service class HttpService {
    private Service hubService;
    private boolean isSubscriptionAvailable = false;
    private boolean isSubscriptionValidationAvailable = false;
    private boolean isUnsubscriptionAvailable = false;
    private boolean isUnsubscriptionValidationAvailable = false;
    private boolean isRegisterAvailable = false;
    private boolean isUnregisterAvailable = false;

    public isolated function init(Service hubService) {
        self.hubService = hubService;

        string[] methodNames = getServiceMethodNames(hubService);
        foreach var methodName in methodNames {
            if (methodName == "onSubscription") {
                self.isSubscriptionAvailable = true;
            }
            if (methodName == "onSubscriptionValidation") {
                self.isSubscriptionValidationAvailable = true;
            }
            if (methodName == "onUnsubscription") {
                self.isUnsubscriptionAvailable = true;
            }
            if (methodName == "onUnsubscriptionValidation") {
                self.isUnsubscriptionValidationAvailable = true;
            }
            if (methodName == "onRegisterTopic") {
                self.isRegisterAvailable = true;
            }
            if (methodName == "onUnregisterTopic") {
                self.isUnregisterAvailable = true;
            }
        }
    }

    resource function post .(http:Caller caller, http:Request request) {
        http:Response response = new;
        response.statusCode = http:STATUS_OK;

        map<string> params = {};

        string contentType = checkpanic request.getHeader(CONTENT_TYPE);
        // todo: Use constants form mime/http
        match contentType {
            "application/x-www-form-urlencoded" => {
                var reqFormParamMap = request.getFormParams();
                params = reqFormParamMap is map<string> ? reqFormParamMap : {};
            }
            "application/json"|"application/xml"|"application/octet-stream"|"text/plain" => {
                params = {
                    HUB_MODE: MODE_PUBLISH
                };
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "Endpoint only supports content type of application/x-www-form-urlencoded, " +
                                        "application/json, application/xml, application/octet-stream and text/plain";
                response.setTextPayload(errorMessage);
                respondToRequest(caller, response);
            }
        }

        string mode = params[HUB_MODE] ?: "";
        match mode {
            MODE_REGISTER => {
                if (self.isRegisterAvailable) {
                    processRegisterRequest(caller, response, <@untainted> params, self.hubService);
                } else {
                    response.statusCode = http:STATUS_NOT_IMPLEMENTED;
                }
                respondToRequest(caller, response);
            }
            MODE_UNREGISTER => {
                if (self.isUnregisterAvailable) {
                    processUnregisterRequest(caller, response, <@untainted> params, self.hubService);
                } else {
                    response.statusCode = http:STATUS_NOT_IMPLEMENTED;
                }
                respondToRequest(caller, response);
            }
            MODE_SUBSCRIBE => {
                processSubscriptionRequestAndRespond(<@untainted> request, caller, response, <@untainted> params, 
                                                        <@untainted> self.hubService,
                                                        <@untainted> self.isSubscriptionAvailable,
                                                        <@untainted> self.isSubscriptionValidationAvailable);
            }
            MODE_UNSUBSCRIBE => {
                processUnsubscriptionRequestAndRespond(<@untainted> request, caller, response, <@untainted> params,
                                                        self.hubService, self.isUnsubscriptionAvailable,
                                                        <@untainted> self.isUnsubscriptionValidationAvailable);
            }
            MODE_PUBLISH => {
                // todo Proper error handling instead of checkpanic
                string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response); 
                if (topic is ()) {
                    respondToRequest(caller, response);
                    return;
                }
                UpdateMessage updateMsg;
                if (contentType == mime:APPLICATION_FORM_URLENCODED) {
                    updateMsg = {
                        hubTopic: <string> topic,
                        content: ()
                    };
                } else if (contentType == mime:APPLICATION_JSON) {
                    updateMsg = {
                        hubTopic: (),
                        content: checkpanic request.getJsonPayload()
                    };
                } else if (contentType == mime:APPLICATION_XML) {
                    updateMsg = {
                        hubTopic: (),
                        content: checkpanic request.getXmlPayload()
                    };
                } else if (contentType == "text/plain") {
                    updateMsg = {
                        hubTopic: (),
                        content: checkpanic request.getTextPayload()
                    };
                } else {
                    updateMsg = {
                        hubTopic: (),
                        content: checkpanic request.getBinaryPayload()
                    };
                }
                processPublishRequestAndRespond(caller, response, self.hubService, <@untainted> updateMsg);
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "The request does not include valid `hub.mode` form param.";
                response.setTextPayload(errorMessage);
                respondToRequest(caller, response);
            }
        }
    }
}

isolated function getServiceMethodNames(Service hubService) returns string[] = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
