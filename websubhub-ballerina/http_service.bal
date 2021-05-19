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
import ballerina/jballerina.java;

service class HttpService {
    private Service hubService;
    private ClientConfiguration clientConfig;
    private string hub;
    private int defaultHubLeaseSeconds;
    private boolean isSubscriptionAvailable = false;
    private boolean isSubscriptionValidationAvailable = false;
    private boolean isUnsubscriptionAvailable = false;
    private boolean isUnsubscriptionValidationAvailable = false;
    private boolean isRegisterAvailable = false;
    private boolean isDeregisterAvailable = false;

    # Initializes the `websubhub:HttpService` endpoint.
    # ```ballerina
    # websubhub:HttpService httpServiceEp = check new ('service, "https://sample.hub.com", 3600);
    # ```
    #
    # + hubService   - Current `websubhub:Service` instance
    # + hubUrl       - Hub URL
    # + leaseSeconds - Subscription expiration time for the `hub`
    # + clientConfig - The `websubhub:ClientConfiguration` to be used in the HTTP Client used for subscription/unsubscription intent verification
    # + return - The `websubhub:HttpService` or an `error` if the initialization failed
    public isolated function init(Service hubService, string hubUrl, int leaseSeconds, *ClientConfiguration clientConfig) {
        self.hubService = hubService;
        self.clientConfig = clientConfig;
        self.hub = hubUrl;
        self.defaultHubLeaseSeconds = leaseSeconds;
        string[] methodNames = getServiceMethodNames(hubService);
        foreach var methodName in methodNames {
            match methodName {
                "onSubscription" => {
                    self.isSubscriptionAvailable = true;  
                }
                "onSubscriptionValidation" => {
                    self.isSubscriptionValidationAvailable = true;
                }
                "onUnsubscription" => {
                    self.isUnsubscriptionAvailable = true;
                }
                "onUnsubscriptionValidation" => {
                    self.isUnsubscriptionValidationAvailable = true;
                }
                "onRegisterTopic" => {
                    self.isRegisterAvailable = true;
                }
                "onDeregisterTopic" => {
                    self.isDeregisterAvailable = true;
                }
            }
        }
    }

    # Receives HTTP POST requests.
    # 
    # + caller - The `http:Caller` reference of the current request
    # + request - Received `http:Request` instance
    # + headers - HTTP headers found in the original HTTP request
    # + return - An `error` if there is any exception in the request processing or else `()`
    isolated resource function post .(http:Caller caller, http:Request request, http:Headers headers) returns @tainted error? {
        http:Response response = new;
        response.statusCode = http:STATUS_OK;

        map<string> params = {};

        string contentType = check headers.getHeader(CONTENT_TYPE);
        map<string[]> queryParams = request.getQueryParams();
        match contentType {
            mime:APPLICATION_FORM_URLENCODED => {
                string|http:HeaderNotFoundError publisherHeader = headers.getHeader(BALLERINA_PUBLISH_HEADER);
                if publisherHeader is string {
                    if publisherHeader == "publish" {
                        string[] hubMode = queryParams.get(HUB_MODE);
                        string[] hubTopic = queryParams.get(HUB_TOPIC);
                        params[HUB_MODE] = hubMode.length() == 1 ? hubMode[0] : "";
                        params[HUB_TOPIC] = hubTopic.length() == 1 ? hubTopic[0] : "";
                    } else if publisherHeader == "event" {
                        var reqFormParamMap = request.getFormParams();
                        params = reqFormParamMap is map<string> ? reqFormParamMap : {};
                    } else {
                        response.statusCode = http:STATUS_BAD_REQUEST;
                        response.setTextPayload("Invalid value for header " + BALLERINA_PUBLISH_HEADER);
                        respondToRequest(caller, response);
                    }
                } else {
                    var reqFormParamMap = request.getFormParams();
                    params = reqFormParamMap is map<string> ? reqFormParamMap : {};
                }
            }
            mime:APPLICATION_JSON|mime:APPLICATION_XML|mime:APPLICATION_OCTET_STREAM|mime:TEXT_PLAIN => {
                string[] hubMode = queryParams.get(HUB_MODE);
                string[] hubTopic = queryParams.get(HUB_TOPIC);
                params[HUB_MODE] = hubMode.length() == 1 ? hubMode[0] : "";
                params[HUB_TOPIC] = hubTopic.length() == 1 ? hubTopic[0] : "";
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
                if self.isRegisterAvailable {
                    processRegisterRequest(caller, response, headers, <@untainted> params, self.hubService);
                } else {
                    response.statusCode = http:STATUS_NOT_IMPLEMENTED;
                }
                respondToRequest(caller, response);
            }
            MODE_DEREGISTER => {
                if self.isDeregisterAvailable {
                    processDeregisterRequest(caller, response, headers, <@untainted> params, self.hubService);
                } else {
                    response.statusCode = http:STATUS_NOT_IMPLEMENTED;
                }
                respondToRequest(caller, response);
            }
            MODE_SUBSCRIBE => {
                processSubscriptionRequestAndRespond(<@untainted> request, caller, response, 
                                                     headers, <@untainted> params, 
                                                     <@untainted> self.hubService, 
                                                     <@untainted> self.isSubscriptionAvailable,
                                                     <@untainted> self.isSubscriptionValidationAvailable, 
                                                     <@untainted> self.hub, 
                                                     <@untainted> self.defaultHubLeaseSeconds, 
                                                     self.clientConfig);
            }
            MODE_UNSUBSCRIBE => {
                processUnsubscriptionRequestAndRespond(<@untainted> request, caller, response, 
                                                       headers, <@untainted> params, self.hubService, 
                                                       self.isUnsubscriptionAvailable,
                                                       <@untainted> self.isUnsubscriptionValidationAvailable, 
                                                       self.clientConfig);
            }
            MODE_PUBLISH => {
                string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response); 
                if topic is () {
                    respondToRequest(caller, response);
                    return;
                }
                UpdateMessage updateMsg;
                if contentType == mime:APPLICATION_FORM_URLENCODED {
                    updateMsg = {
                        hubTopic: <string> topic,
                        msgType: EVENT,
                        contentType: contentType,
                        content: ()
                    };
                } else if contentType == mime:APPLICATION_JSON {
                    updateMsg = {
                        hubTopic: <string> topic,
                        msgType: PUBLISH,
                        contentType: contentType,
                        content: check request.getJsonPayload()
                    };
                } else if contentType == mime:APPLICATION_XML {
                    updateMsg = {
                        hubTopic: <string> topic,
                        msgType: PUBLISH,
                        contentType: contentType,
                        content: check request.getXmlPayload()
                    };
                } else if contentType == mime:TEXT_PLAIN {
                    updateMsg = {
                        hubTopic: <string> topic,
                        msgType: PUBLISH,
                        contentType: contentType,
                        content: check request.getTextPayload()
                    };
                } else {
                    updateMsg = {
                        hubTopic: <string> topic,
                        msgType: PUBLISH,
                        contentType: mime:APPLICATION_OCTET_STREAM,
                        content: check request.getBinaryPayload()
                    };
                }
                processPublishRequestAndRespond(caller, response, headers, self.hubService, <@untainted> updateMsg);
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

# Retrives the names of the implemented methods in the `websubhub:Service` instance.
# 
# + hubService - Current `websubhub:Service` instance
# + return - All the methods implemented in the `websubhub:Service` as a `string[]`
isolated function getServiceMethodNames(Service hubService) returns string[] = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
