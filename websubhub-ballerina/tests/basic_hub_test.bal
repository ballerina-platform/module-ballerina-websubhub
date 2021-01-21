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

    remote function onRegisterTopic(TopicRegistration message)
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

    remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationSuccess|TopicDeregistrationError {
        TopicRegistrationSuccess deregisterResult = {
            body: {
                   isDeregisterSuccess: "true"
                }
        };
        if (message.topic == "test") {
            return deregisterResult;
       } else {
            return error TopicDeregistrationError("Topic Deregistration Failed!");
        }
    }

    remote function onUpdateMessage(UpdateMessage msg)
               returns Acknowledgement|UpdateMessageError {
        Acknowledgement ack = {};
        if (msg.hubTopic == "test") {
            return ack;
        } else if (!(msg.content is ())) {
            return ack;
        } else {
            return error UpdateMessageError("Error in accessing content");
        }
    }
    
    remote function onSubscription(Subscription msg)
                returns SubscriptionAccepted|SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect
                |BadSubscriptionError|InternalSubscriptionError {
        SubscriptionAccepted successResult = {
                body: {
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else if (msg.hubTopic == "test1") {
            return successResult;
        } else {
            return error BadSubscriptionError("Bad subscription");
        }
    }

    remote function onSubscriptionValidation(Subscription msg)
                returns SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error SubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
        isIntentVerified = true;
    }

    remote function onUnsubscription(Unsubscription msg)
               returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError {
        if (msg.hubTopic == "test" || msg.hubTopic == "test1" ) {
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

    remote function onUnsubscriptionValidation(Unsubscription msg)
                returns UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error UnsubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
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
        test:assertEquals(response.getTextPayload(), "The request does not include valid `hub.mode` form param.");
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

    string expectedPayload = "hub.mode=denied&hub.reason=Registration Failed!";
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
function testDeregistrationSuccess() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=accepted&isDeregisterSuccess=true";
    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Deregistration test failed");
    }
}

@test:Config {
}
function testDeregistrationFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test1", "application/x-www-form-urlencoded");

    string expectedPayload = "hub.mode=denied&hub.reason=Topic Deregistration Failed!";
    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), expectedPayload);
    } else {
        test:assertFail("Deregistration test failed");
    }
}

service /subscriber on new http:Listener(9091) {

    resource function get .(http:Caller caller, http:Request req)
            returns error? {
        map<string[]> payload = req.getQueryParams();
        string[] hubMode = <string[]> payload["hub.mode"];
        if (hubMode[0] == "denied") {
            io:println("Subscriber Validation failed get", payload);
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
            io:println("Unsubscription Validation failed get", payload);
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
        test:assertFail("Deregistration test failed");
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
        test:assertFail("Deregistration test failed");
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
        test:assertFail("Deregistration test failed");
    }
}

@test:Config {
}
function testUnsubscriptionFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber/unsubscribe",
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
function testUnsubscriptionValidationFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 202);
        // todo Validate post request invoked, as of now manually checked through logs
        // test:assertEquals(isValidationFailed, true);
    } else {
        test:assertFail("Deregistration test failed");
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

@test:Config {
}
function testPublishContent() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test", "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
    } else {
        test:assertFail("UnsubscriptionIntentVerification test failed");
    }
}

@test:Config {
}
function testPublishContentFailure() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test1", "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
    } else {
        test:assertFail("UnsubscriptionIntentVerification test failed");
    }
}

@test:Config {
}
function testPublishContentLocal() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("event=event1", "application/x-www-form-urlencoded");
    request.setHeader(BALLERINA_PUBLISH_HEADER, "publish");

    var response = check httpClient->post("/?hub.mode=publish&hub.topic=test", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
    } else {
        test:assertFail("UnsubscriptionIntentVerification test failed");
    }
}
