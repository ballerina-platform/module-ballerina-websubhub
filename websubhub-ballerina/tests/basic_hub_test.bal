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
import ballerina/test;

http:Client httpClient = new("http://localhost:9090/websubhub");

listener Listener functionWithArgumentsListener = new(9090);

service /websubhub on functionWithArgumentsListener {

    remote function onRegisterTopic(RegisterTopicMessage message)
                                returns TopicRegistrationSuccess|TopicRegistrationError {
        if (message.topic == "test") {
            TopicRegistrationSuccess successResult = {
                body: {
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error TopicRegistrationError("Registration Failed!");
        }
    }

    remote function onUnregisterTopic(UnregisterTopicMessage message)
                        returns TopicUnregistrationSuccess|TopicUnregistrationError {
        TopicRegistrationSuccess unregisterResult = {
            body: {
                   isSuccess: "true"
                }
        };
        if (message.topic == "test") {
            return unregisterResult;
       } else {
            return error TopicUnregistrationError("Topic Unregistration Failed!");
        }
    }
}


@test:Config {
}
function testFailurePost() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register123&hub.topic=test", "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 400);
        test:assertEquals(response.getTextPayload(), "The request need to include valid `hub.mode` form param");
    } else {
        test:assertFail("Malformed request was successful");
    }
}

@test:Config {
}
function testRegistrationSuccess() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=accepted&isSuccess=true";
    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Registration test failed");
    }
}

@test:Config {
}
function testRegistrationFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test1", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=denied&hub.topic=test1&hub.reason=Registration Failed!";
    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Registration test failed");
    }
}