// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/test;
import ballerina/http;
import ballerina/log;

listener http:Listener simpleSubscriberListener = new (9191);

var simpleSubscriber = service object {

    resource function get .(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] hubMode = <string[]> payload["hub.mode"];
        if (hubMode[0] == "denied") {
            log:printDebug("Subscriber Validation failed ", retrievedPayload = payload);
            isValidationFailed = true;
            check caller->respond("");
        } else {
            string[] challengeArray = <string[]> payload["hub.challenge"];
            check caller->respond(challengeArray[0]);
        }
    }

    resource function post .(http:Caller caller, http:Request req)
            returns error? {
        check caller->respond();
    }

    resource function get unsubscribe(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] hubMode = <string[]> payload["hub.mode"];
        if (hubMode[0] == "denied") {
            log:printDebug("Unsubscription Validation failed ", retrievedPayload = payload);
            isValidationFailed = true;
            check caller->respond("");
        } else {
            string[] challengeArray = <string[]> payload["hub.challenge"];
            check caller->respond(challengeArray[0]);
        }
    }

    resource function post unsubscribe(http:Caller caller, http:Request req)
            returns error? {
        check caller->respond();
    }
};

@test:BeforeSuite
function beforeSuiteFunc() {
    checkpanic simpleSubscriberListener.attach(simpleSubscriber, "subscriber");
}

@test:AfterSuite { }
function afterSuiteFunc() {
    checkpanic simpleSubscriberListener.gracefulStop();
}