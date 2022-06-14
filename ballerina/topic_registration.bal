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

isolated function processTopicRegistration(http:Headers headers, map<string> params, 
                                           HttpToWebsubhubAdaptor adaptor) returns http:Response|error {
    string topic = check retrieveQueryParameter(params, HUB_TOPIC);
    TopicRegistration msg = {
        topic: topic
    };
    TopicRegistrationSuccess|error result = adaptor.callRegisterMethod(msg, headers);
    http:Response response = new;
    if result is TopicRegistrationSuccess {
        updateSuccessResponse(response, result.statusCode, result?.body, result?.headers);
    } else {
        CommonResponse errorDetails = result is TopicRegistrationError ? result.detail() : TOPIC_REGISTRATION_ERROR.detail();
        updateErrorResponse(response, errorDetails, result.message());
    }
    return response;
}

isolated function processTopicDeregistration(http:Headers headers, map<string> params, 
                                             HttpToWebsubhubAdaptor adaptor) returns http:Response|error {
    string topic = check retrieveQueryParameter(params, HUB_TOPIC);
    TopicDeregistration msg = {
        topic: topic
    };
    TopicDeregistrationSuccess|error result = adaptor.callDeregisterMethod(msg, headers);
    http:Response response = new;
    if result is TopicDeregistrationSuccess {
        updateSuccessResponse(response, result.statusCode, result?.body, result?.headers);
    } else {
        CommonResponse errorDetails = result is TopicDeregistrationError ? result.detail() : TOPIC_DEREGISTRATION_ERROR.detail();
        updateErrorResponse(response, errorDetails, result.message());
    }
    return response;
}
