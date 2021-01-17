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
import ballerina/java;

service class HttpService {
    private HubService hubService;
    private boolean isSubscriptionAvailable;
    private boolean isUnsubscriptionAvailable;

    public isolated function init(HubService hubService) {
        self.hubService = hubService;

        string[] methodNames = getServiceMethodNames(hubService);
        foreach var methodName in methodNames {
            if (methodName == "onSubscription") {
                self.isSubscriptionAvailable = true;
            } else {
                self.isSubscriptionAvailable = false;
            }

            if (methodName == "onUnsubscription") {
                self.isUnsubscriptionAvailable = true;
            } else {
               self.isUnsubscriptionAvailable = false;
            }
        }
    }

    isolated resource function post .(http:Caller caller, http:Request request) {
        http:Response response = new;
        response.statusCode = http:STATUS_OK;

        var reqFormParamMap = request.getFormParams();
        map<string> params = reqFormParamMap is map<string> ? reqFormParamMap : {};

        string mode = params[HUB_MODE] ?: "";
        match mode {
            MODE_REGISTER => {
                respondToRegisterRequest(caller, response, <@untainted> params, self.hubService);
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "The request need to include valid `hub.mode` form param";
                response.setTextPayload(errorMessage);
                log:print("Hub request unsuccessful :" + errorMessage);
            }
        }
        var responseError = caller->respond(response);
        if (responseError is error) {
            log:printError("Error responding remote topic registration status", err = responseError);
        }
    }
}

isolated function getServiceMethodNames(HubService hubService) returns string[] = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
