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
    }

    isolated resource function post .(http:Caller caller, http:Request request, http:Headers headers) returns error? {
        map<string>|error params = self.retrieveQueryParams(request, headers);
        if params is error {
            http:Response response = new;
            response.statusCode = http:STATUS_BAD_REQUEST;
            respondToRequest(caller, response);
        } else {
            string? mode = params[HUB_MODE];
            match mode {
                MODE_REGISTER => {
                    self.handleTopicRegistration(caller, headers, params);
                    return;
                }
                MODE_DEREGISTER => {
                    self.handleTopicDeregistration(caller, headers, params);
                    return;
                }
                MODE_SUBSCRIBE => {
                    self.handleSubscription(caller, headers, params);
                    return;
                }
                MODE_UNSUBSCRIBE => {
                    http:Response response = new;
                    processUnsubscriptionRequestAndRespond(request, caller, response, 
                                                        headers, params, self.adaptor, 
                                                        self.isUnsubscriptionAvailable, self.isUnsubscriptionValidationAvailable, 
                                                        self.clientConfig);
                }
                MODE_PUBLISH => {
                    self.handleContentPublish(caller, request, headers, params);
                    return;
                }
                _ => {
                    http:Response response = new;
                    response.statusCode = http:STATUS_BAD_REQUEST;
                    string errorMessage = "The request does not include valid `hub.mode` form param.";
                    response.setTextPayload(errorMessage);
                    respondToRequest(caller, response);
                }
            }
        }
    }

    isolated function retrieveQueryParams(http:Request request, http:Headers headers) returns map<string>|error {
        string contentType = check headers.getHeader(CONTENT_TYPE);
        map<string> params = {};
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
                        return error("Invalid value for header " + BALLERINA_PUBLISH_HEADER);
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
                string errorMessage = "Endpoint only supports content type of application/x-www-form-urlencoded, " + 
                                        "application/json, application/xml, application/octet-stream and text/plain";
                return error(errorMessage);
            }
        }
        return params;
    }

    isolated function handleTopicRegistration(http:Caller caller, http:Headers headers, map<string> params) {
        http:Response|error result = processTopicRegistration(headers, params, self.adaptor);
        handleResult(caller, result);
    }

    isolated function handleTopicDeregistration(http:Caller caller, http:Headers headers, map<string> params) {
        http:Response|error result = processTopicDeregistration(headers, params, self.adaptor);
        handleResult(caller, result);
    }

    isolated function handleSubscription(http:Caller caller, http:Headers headers, map<string> params) {
        Subscription|error subscription = createSubscriptionMessage(self.hub, self.defaultHubLeaseSeconds, params);
        if subscription is Subscription {
            http:Response|Redirect result = processSubscription(subscription, headers, self.adaptor, self.isSubscriptionAvailable);
            if result is Redirect {
                error? redirectError = caller->redirect(new http:Response(), result.code, result.redirectUrls);
                if redirectError is error {
                    log:printError("Error occurred while redirecting the subscription", 'error = redirectError);
                }
            } else {
                int currentStatusCode = result.statusCode;
                if currentStatusCode == http:STATUS_ACCEPTED && self.isSubscriptionAvailable {
                    respondToRequest(caller, result);
                    error? verificationResult = processSubscriptionVerification(headers, self.adaptor, subscription, 
                                                                                        self.isSubscriptionValidationAvailable, self.clientConfig);
                    if verificationResult is error {
                        log:printError("Error occurred while processing subscription", 'error = verificationResult);
                    }
                    return;
                }
                respondToRequest(caller, result);
            }
        } else {
            http:Response response = new;
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setTextPayload(subscription.message());
            respondToRequest(caller, response);
        }
    }

    isolated function handleContentPublish(http:Caller caller, http:Request request, http:Headers headers, map<string> params) {
        http:Response|error result = processContentPublish(request, headers, params, self.adaptor);
        handleResult(caller, result);
    }
}

isolated function isMethodAvailable(string methodName, string[] methods) returns boolean {
    return methods.indexOf(methodName) is int;
}

isolated function handleResult(http:Caller caller, http:Response|error result) {
    if result is error {
        http:Response response = new;
        response.statusCode = http:STATUS_BAD_REQUEST;
        response.setTextPayload(result.message());
        respondToRequest(caller, response);
    } else {
        respondToRequest(caller, result);
    }
}
