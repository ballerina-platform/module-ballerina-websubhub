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

map<string|string[]> CUSTOM_HEADERS = {
        "header1": ["value1", "value2"],
        "header2": "value3",
        "header3": ["value4"]
};

var simpleSubscriber = service object {

    isolated resource function get .(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] hubMode = <string[]> payload["hub.mode"];
        if (hubMode[0] == "denied") {
            log:printDebug("Subscriber Validation failed ", retrievedPayload = payload);
            check caller->respond("");
        } else {
            string[] challengeArray = <string[]> payload["hub.challenge"];
            check caller->respond(challengeArray[0]);
        }
    }

    isolated resource function post .(http:Caller caller, http:Request req)
            returns error? {
        check caller->respond();
    }

    resource function post addHeaders(http:Caller caller, http:Request req) returns error? {
        http:Response response = new;    
        foreach var [header, value] in CUSTOM_HEADERS.entries() {
            if (value is string) {
                response.setHeader(header, value);
            } else {
                foreach var val in value {
                    response.addHeader(header, val);
                }
            }
        }
        check caller->respond(response);
    }

    isolated resource function post addPayload(http:Caller caller, http:Request req) returns error? {
        string & readonly payload = check req.getTextPayload();
        json|xml|string|byte[]? samplePayload = ();
        match payload {
            "json" => {
                samplePayload = {
                    "message": "This is a test message"
                };
            }
            "text" => {
                samplePayload = "This is a test message";
            }
            "xml" => {
                samplePayload = xml `<content><message>This is a test message</message></content>`;
            }
            "byte" => {
                samplePayload = "This is a test message".toBytes();
            }
            _ => {}
        }
        http:Response resp = new;
        resp.setPayload(samplePayload);
        http:ListenerError? result = caller->respond(resp);
    }

    isolated resource function get unsubscribe(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] hubMode = <string[]> payload["hub.mode"];
        if (hubMode[0] == "denied") {
            log:printDebug("Unsubscription Validation failed ", retrievedPayload = payload);
            check caller->respond("");
        } else {
            string[] challengeArray = <string[]> payload["hub.challenge"];
            http:ListenerError? result = caller->respond(challengeArray[0]);
        }
    }

    isolated resource function post unsubscribe(http:Caller caller, http:Request req)
            returns error? {
        http:ListenerError? result = caller->respond();
    }
};

@test:BeforeSuite
function beforeSuiteFunc() returns @tainted error? {
    check simpleSubscriberListener.attach(simpleSubscriber, "subscriber");
}

@test:AfterSuite { }
function afterSuiteFunc() returns @tainted error? {
    check simpleSubscriberListener.gracefulStop();
}
