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

isolated service class HttpService {
    private final HttpToWebsubhubAdaptor adaptor;
    private final readonly & ClientConfiguration clientConfig;
    private final string hub;
    private final int defaultHubLeaseSeconds;
    private final boolean isSubscriptionAvailable;
    private final boolean isSubscriptionValidationAvailable;
    private final boolean isUnsubscriptionAvailable;
    private final boolean isUnsubscriptionValidationAvailable;
    private final boolean isRegisterAvailable;
    private final boolean isDeregisterAvailable;

    # Initializes the `websubhub:HttpService` endpoint.
    # ```ballerina
    # websubhub:HttpService httpServiceEp = check new (adaptor, "https://sample.hub.com", 3600);
    # ```
    #
    # + adaptor - The `websubhub:HttpToWebsubhubAdaptor` instance which used as a wrapper to execute service methods
    # + hubUrl       - Hub URL
    # + leaseSeconds - Subscription expiration time for the `hub`
    # + clientConfig - The `websubhub:ClientConfiguration` to be used in the HTTP Client used for subscription/unsubscription intent verification
    # + return - The `websubhub:HttpService` or an `error` if the initialization failed
    isolated function init(HttpToWebsubhubAdaptor adaptor, string hubUrl, int leaseSeconds,
                           *ClientConfiguration clientConfig) {
        self.adaptor = adaptor;
        self.clientConfig = clientConfig.cloneReadOnly();
        self.hub = hubUrl;
        self.defaultHubLeaseSeconds = leaseSeconds;
        string[] methodNames = adaptor.getServiceMethodNames();
        self.isSubscriptionAvailable = isMethodAvailable("onSubscription", methodNames);
        self.isSubscriptionValidationAvailable = isMethodAvailable("onSubscriptionValidation", methodNames);
        self.isUnsubscriptionAvailable = isMethodAvailable("onUnsubscription", methodNames);
        self.isUnsubscriptionValidationAvailable = isMethodAvailable("onUnsubscriptionValidation", methodNames);
        self.isRegisterAvailable = isMethodAvailable("onRegisterTopic", methodNames);
        self.isDeregisterAvailable = isMethodAvailable("onDeregisterTopic", methodNames);
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
                        return;
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
                return;
            }
        }

        string mode = params[HUB_MODE] ?: "";
        match mode {
            MODE_REGISTER => {
                if self.isRegisterAvailable {
                    http:Response|error result = processTopicRegistration(headers, params, self.adaptor);
                    if result is error {
                        response.statusCode = http:STATUS_BAD_REQUEST;
                        response.setTextPayload(result.message());
                        respondToRequest(caller, response);
                    } else {
                        respondToRequest(caller, result);
                    }
                    return;
                } else {
                    response.statusCode = http:STATUS_NOT_IMPLEMENTED;
                }
            }
            MODE_DEREGISTER => {
                if self.isDeregisterAvailable {
                    http:Response|error result = processTopicDeregistration(headers, params, self.adaptor);
                    if result is error {
                        response.statusCode = http:STATUS_BAD_REQUEST;
                        response.setTextPayload(result.message());
                        respondToRequest(caller, response);
                    } else {
                        respondToRequest(caller, result);
                    }
                    return;
                } else {
                    response.statusCode = http:STATUS_NOT_IMPLEMENTED;
                }
            }
            MODE_SUBSCRIBE => {
                Subscription|error subscription = createSubscriptionMessage(self.hub, self.defaultHubLeaseSeconds, params);
                if subscription is Subscription {
                    http:Response|Redirect result = processSubscription(subscription, headers, self.adaptor, self.isSubscriptionAvailable);
                    if result is Redirect {
                        error? redirectError = caller->redirect(response, result.code, result.redirectUrls);
                        if redirectError is error {
                            log:printError("Error occurred while redirecting the subscription", errorMsg = redirectError.message());
                        }
                    } else {
                        int currentStatusCode = result.statusCode;
                        if currentStatusCode == http:STATUS_ACCEPTED && self.isSubscriptionAvailable {
                            respondToRequest(caller, result);
                            error? verificationResult = processSubscriptionVerification(headers, self.adaptor, subscription, 
                                                                                        self.isSubscriptionValidationAvailable, self.clientConfig);
                            if verificationResult is error {
                                log:printError("Error occurred while processing subscription", errorMsg = verificationResult.message());
                            }
                            return;
                        }
                        respondToRequest(caller, result);
                    }
                } else {
                    response.statusCode = http:STATUS_BAD_REQUEST;
                    response.setTextPayload(subscription.message());
                    respondToRequest(caller, response);
                }
                return;
            }
            MODE_UNSUBSCRIBE => {
                processUnsubscriptionRequestAndRespond(<@untainted> request, caller, response, 
                                                       headers, <@untainted> params, self.adaptor,
                                                       self.isUnsubscriptionAvailable,
                                                       <@untainted> self.isUnsubscriptionValidationAvailable, 
                                                       self.clientConfig);
            }
            MODE_PUBLISH => {
                http:Response|error result = processContentPublish(request, headers, params, self.adaptor);
                if result is error {
                    response.statusCode = http:STATUS_BAD_REQUEST;
                    response.setTextPayload(result.message());
                    respondToRequest(caller, response);
                } else {
                    respondToRequest(caller, result);
                }
                return;
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "The request does not include valid `hub.mode` form param.";
                response.setTextPayload(errorMessage);
            }
        }
        respondToRequest(caller, response);
    }
}

# Retrieves whether the particular remote method is available in service-object.
# 
# + methodName - Name of the required method
# + methods - All available methods
# + return - `true` if method available or else `false`
isolated function isMethodAvailable(string methodName, string[] methods) returns boolean {
    return methods.indexOf(methodName) is int;
}
