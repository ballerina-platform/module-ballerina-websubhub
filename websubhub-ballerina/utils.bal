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

import ballerina/encoding;
import ballerina/http;
import ballerina/log;
import ballerina/java;

isolated function respondToRegisterRequest(http:Caller caller, http:Response response, 
                                            map<string> params, HubService hubService) {
    string topic = "";
    var topicFromParams = params[HUB_TOPIC];
    if topicFromParams is string {
        var decodedValue = encoding:decodeUriComponent(topicFromParams, "UTF-8");
        topic = decodedValue is string ? decodedValue : topicFromParams;
    }
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

isolated function callRegisterMethod(HubService hubService, RegisterTopicMessage msg)
returns TopicRegistrationSuccess|TopicRegistrationError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
