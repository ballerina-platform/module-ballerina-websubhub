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

import ballerina/log;
import ballerina/http;
import ballerina/test;

listener Listener hubWithHeaderDetailsListener = new(9095);

var hubWithHeaderDetails = service object {

    remote function onRegisterTopic(TopicRegistration message, http:Headers headers)
                                returns TopicRegistrationSuccess {
        log:print("Executing topic registration", message = message, headers = headers.getHeaderNames());
        TopicRegistrationSuccess successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
        };
        return successResult;
    }

    remote function onDeregisterTopic(TopicDeregistration message, http:Headers headers)
                        returns TopicDeregistrationSuccess {
        log:print("Executing topic de-registration", message = message, headers = headers.getHeaderNames());
        map<string> body = { isDeregisterSuccess: "true" };
        TopicDeregistrationSuccess deregisterResult = {
            body
        };
        return deregisterResult;
    }
};

@test:BeforeGroups { value:["http-header-details"] }
function beforeHttpHeaderDetailsTest() {
    checkpanic hubWithHeaderDetailsListener.attach(hubWithHeaderDetails, "websubhub");
}

@test:AfterGroups { value:["http-header-details"] }
function afterHttpHeaderDetailsTest() {
    checkpanic hubWithHeaderDetailsListener.gracefulStop();
}

http:Client httpHeaderDetailsTestClientEp = checkpanic new("http://localhost:9095/websubhub");

@test:Config {
    groups: ["http-header-details"]
}
function testRegistrationWithHeaderDetails() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=accepted&isSuccess=true";
    var response = httpHeaderDetailsTestClientEp->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Registration test failed");
    }
}

@test:Config {
    groups: ["http-header-details"]
}
function testDeregistrationSuccessWithHeaderDetails() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=accepted&isDeregisterSuccess=true";
    var response = httpHeaderDetailsTestClientEp->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Deregistration test failed");
    }
}
