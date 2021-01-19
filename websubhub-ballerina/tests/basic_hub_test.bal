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

import ballerina/io;
import ballerina/http;
import ballerina/test;

boolean isIntentVerified = false;
boolean isValidationFailed = false;

http:Client httpClient = checkpanic new("http://localhost:9090/websubhub");

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
                   isUnregisterSuccess: "true"
                }
        };
        if (message.topic == "test") {
            return unregisterResult;
       } else {
            return error TopicUnregistrationError("Topic Unregistration Failed!");
        }
    }

    remote function onSubscription(SubscriptionMessage msg)
                returns SubscriptionAccepted|SubscriptionRedirect|BadSubscriptionError
                |InternalSubscriptionError {
        SubscriptionAccepted successResult = {
                body: {
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic is string && msg.hubTopic == "test") {
            return successResult;
        } else if (msg.hubTopic == "test1") {
            return successResult;
        } else {
            return error BadSubscriptionError("Bad subscription");
        }
    }

    remote function onSubscriptionValidation(SubscriptionMessage msg)
                returns SubscriptionDenied? {
        if (msg.hubTopic == "test1") {
            return error SubscriptionDenied("Denied subscription for topic 'test1'");
        }
        return ();
    }

    remote function onSubscriptionIntentVerified(VerifiedSubscriptionMessage msg) {
        io:println("Subscription Intent verified invoked!");
        isIntentVerified = true;
    }

    remote function onUnsubscription(UnsubscriptionMessage msg)
               returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError {
        if (msg.hubTopic == "test") {
            UnsubscriptionAccepted successResult = {
                body: {
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error BadUnsubscriptionError("Denied unsubscription for topic '" + <string> msg.hubTopic + "'");
        }
    }

    remote function onUnsubscriptionIntentVerified(VerifiedUnsubscriptionMessage msg){
        io:println("Unsubscription Intent verified invoked!");
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

@test:Config {
}
function testUnregistrationSuccess() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unregister&hub.topic=test", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=accepted&isUnregisterSuccess=true";
    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Unregistration test failed");
    }
}

@test:Config {
}
function testUnregistrationFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unregister&hub.topic=test1", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=denied&hub.topic=test1&hub.reason=Topic Unregistration Failed!";
    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Unregistration test failed");
    }
}

service /subscriber on new http:Listener(9091) {

    resource function get .(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] challengeArray = <string[]> payload["hub.challenge"];
        check caller->respond(challengeArray[0]);
    }

    resource function post .(http:Caller caller, http:Request req)
            returns error? {
        io:println("Subscriber Validation failed post", req.getTextPayload());
        isValidationFailed = true;
        check caller->respond();
    }

    resource function get unsubscribe(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] challengeArray = <string[]> payload["hub.challenge"];
        check caller->respond(challengeArray[0]);
    }

    resource function post unsubscribe(http:Caller caller, http:Request req)
            returns error? {
        io:println("Unsubscribe Validation failed post", req.getTextPayload());
        check caller->respond();
    }
}

@test:Config {
}
function testSubscriptionFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 400);
    } else {
        test:assertFail("Unregistration test failed");
    }
}

@test:Config {
}
function testSubscriptionValidationFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 202);
        // todo Validate post request invoked, as of now manually checked through logs
        // test:assertEquals(isValidationFailed, true);
    } else {
        test:assertFail("Unregistration test failed");
    }
}

@test:Config {
}
function testSubscriptionIntentVerification() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 202);
        // todo Validate post request invoked, as of now manually checked through logs
        // test:assertEquals(isIntentVerified, true);
    } else {
        test:assertFail("Unregistration test failed");
    }
}

@test:Config {
}
function testUnsubscriptionFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber/unsubscribe", 
                            "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 400);
    } else {
        test:assertFail("UnsubscriptionFailure test failed");
    }
}

@test:Config {
}
function testUnsubscriptionIntentVerification() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber/unsubscribe", 
                            "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 202);
        // todo Validate post request invoked, as of now manually checked through logs
        // test:assertEquals(isIntentVerified, true);
    } else {
        test:assertFail("UnsubscriptionIntentVerification test failed");
    }
}
