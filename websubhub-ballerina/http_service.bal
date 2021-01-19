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
import ballerina/mime;
import ballerina/java;

service class HttpService {
    private Service hubService;
    private boolean isSubscriptionAvailable = false;
    private boolean isSubscriptionValidationAvailable = false;
    private boolean isUnsubscriptionAvailable = false;

    public isolated function init(Service hubService) {
        self.hubService = hubService;

        string[] methodNames = getServiceMethodNames(hubService);
        foreach var methodName in methodNames {
            if (methodName == "onSubscription") {
                self.isSubscriptionAvailable = true;
                break;
            } else {
                self.isSubscriptionAvailable = false;
            }
        }

        foreach var methodName in methodNames {
            if (methodName == "onSubscriptionValidation") {
                self.isSubscriptionValidationAvailable = true;
                break;
            } else {
                self.isSubscriptionValidationAvailable = false;
            }
        }

        foreach var methodName in methodNames {
            if (methodName == "onUnsubscription") {
                self.isUnsubscriptionAvailable = true;
                break;
            } else {
               self.isUnsubscriptionAvailable = false;
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
                processRegisterRequest(caller, response, <@untainted> params, self.hubService);
                respondToRequest(caller, response);
            }
            MODE_UNREGISTER => {
                processUnregisterRequest(caller, response, <@untainted> params, self.hubService);
                respondToRequest(caller, response);
            }
            MODE_SUBSCRIBE => {
                processSubscriptionRequestAndRespond(caller, response, <@untainted> params, 
                                                        <@untainted> self.hubService,
                                                        <@untainted> self.isSubscriptionAvailable,
                                                        <@untainted> self.isSubscriptionValidationAvailable);
            }
            MODE_UNSUBSCRIBE => {
                processUnsubscriptionRequestAndRespond(caller, response, <@untainted> params,
                                                        self.hubService, self.isUnsubscriptionAvailable);
            }
            MODE_PUBLISH => {
                // todo Proper error handling instead of checkpanic
                UpdateMessage updateMsg;
                if (contentType == mime:APPLICATION_FORM_URLENCODED) {
                    updateMsg = {
                        hubTopic: getEncodedValueFromRequest(params, HUB_TOPIC),
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
