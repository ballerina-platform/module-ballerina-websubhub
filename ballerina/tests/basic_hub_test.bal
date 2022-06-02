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

http:Client httpClient = check new("http://localhost:9090/websubhub");

listener Listener functionWithArgumentsListener = new(9090);

service /websubhub on functionWithArgumentsListener {

    isolated remote function onRegisterTopic(TopicRegistration message)
                                returns TopicRegistrationSuccess|TopicRegistrationError {
        if (message.topic == "test") {
            TopicRegistrationSuccess successResult = {
                statusCode: http:STATUS_OK,
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error TopicRegistrationError("Registration Failed!", statusCode = http:STATUS_OK);
        }
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationSuccess|TopicDeregistrationError {
        if (message.topic == "test") {
            return {
                statusCode: http:STATUS_OK,
                body: <map<string>> {
                    isDeregisterSuccess: "true"
                }
            };
       } else {
            return error TopicDeregistrationError("Topic Deregistration Failed!", statusCode = http:STATUS_OK);
        }
    }

    isolated remote function onUpdateMessage(UpdateMessage msg)
               returns Acknowledgement|UpdateMessageError {
        if (msg.hubTopic == "test") {
            return {
                statusCode: http:STATUS_OK
            };
        } else if msg.content !is () {
            return {
                statusCode: http:STATUS_OK
            };
        } else {
            return error UpdateMessageError("Error in accessing content", statusCode = http:STATUS_BAD_REQUEST);
        }
    }
    
    isolated remote function onSubscription(Subscription msg) returns SubscriptionAccepted|BadSubscriptionError {
        SubscriptionAccepted successResult = {
                statusCode: http:STATUS_ACCEPTED,
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else if (msg.hubTopic == "test1") {
            return successResult;
        } else {
            return error BadSubscriptionError("Bad subscription", statusCode = http:STATUS_BAD_REQUEST);
        }
    }

    isolated remote function onSubscriptionValidation(Subscription msg)
                returns SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error SubscriptionDeniedError("Denied subscription for topic 'test1'", statusCode = http:STATUS_BAD_REQUEST);
        }
        return ();
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(Unsubscription msg)
               returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError {
        if (msg.hubTopic == "test" || msg.hubTopic == "test1" ) {
            UnsubscriptionAccepted successResult = {
                statusCode: http:STATUS_ACCEPTED,
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error BadUnsubscriptionError("Denied unsubscription for topic '" + msg.hubTopic + "'", statusCode = http:STATUS_BAD_REQUEST);
        }
    }

    isolated remote function onUnsubscriptionValidation(Unsubscription msg)
                returns UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error UnsubscriptionDeniedError("Denied subscription for topic 'test1'", statusCode = http:STATUS_BAD_REQUEST);
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}


@test:Config {
}
function testFailurePost() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register123&hub.topic=test", "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 400);
    test:assertEquals(response.getTextPayload(), "The request does not include valid `hub.mode` form param.");
}

@test:Config {
}
function testRegistrationSuccess() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test", "application/x-www-form-urlencoded");
    string expectedPayload = "hub.mode=accepted&isSuccess=true";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testRegistrationSuccessWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test", "application/x-www-form-urlencoded;charset=UTF-8");
    string expectedPayload = "hub.mode=accepted&isSuccess=true";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testRegistrationFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test1", "application/x-www-form-urlencoded");
    string expectedPayload = "hub.mode=denied&hub.reason=Registration Failed!";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testRegistrationFailureWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test1", "application/x-www-form-urlencoded;charset=UTF-8");
    string expectedPayload = "hub.mode=denied&hub.reason=Registration Failed!";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testDeregistrationSuccess() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test", "application/x-www-form-urlencoded");
    string expectedPayload = "hub.mode=accepted&isDeregisterSuccess=true";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testDeregistrationSuccessWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test", "application/x-www-form-urlencoded;charset=UTF-8");
    string expectedPayload = "hub.mode=accepted&isDeregisterSuccess=true";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testDeregistrationFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test1", "application/x-www-form-urlencoded");
    string expectedPayload = "hub.mode=denied&hub.reason=Topic Deregistration Failed!";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testDeregistrationFailureWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test1", "application/x-www-form-urlencoded;charset=UTF-8");
    string expectedPayload = "hub.mode=denied&hub.reason=Topic Deregistration Failed!";
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testSubscriptionFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 400);
}

@test:Config {
}
function testSubscriptionFailureWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded;charset=UTF-8");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 400);
}

@test:Config {
}
function testSubscriptionValidationFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testSubscriptionValidationFailureWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded;charset=UTF-8");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testSubscriptionIntentVerification() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");

    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testSubscriptionIntentVerificationWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded;charset=UTF-8");

    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testSubscriptionWithAdditionalParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber&param1=value1&param2=value2", 
                            "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testUnsubscriptionFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded");

    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 400);
}

@test:Config {
}
function testUnsubscriptionFailureWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded;charset=UTF-8");

    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 400);
}

@test:Config {
}
function testUnsubscriptionValidationFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testUnsubscriptionValidationFailureWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test1&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded;charset=UTF-8");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testUnsubscriptionIntentVerification() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber/unsubscribe", 
                            "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testUnsubscriptionIntentVerificationWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber/unsubscribe", 
                            "application/x-www-form-urlencoded;charset=UTF-8");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {
}
function testPublishContent() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test", "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
}

@test:Config {
}
function testPublishContentFailure() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test1", "application/x-www-form-urlencoded");
    http:Response response = check httpClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
}

@test:Config {
}
function testPublishContentLocal() returns error? {
    http:Request request = new;
    request.setTextPayload("event=event1", "application/x-www-form-urlencoded");
    request.setHeader(BALLERINA_PUBLISH_HEADER, "publish");
    http:Response response = check httpClient->post("/?hub.mode=publish&hub.topic=test", request);
    test:assertEquals(response.statusCode, 200);
}

@test:Config {
}
function testPublishContentFailureForEmptyTopic() returns error? {
    http:Request request = new;
    request.setTextPayload("event=event1", "application/x-www-form-urlencoded");
    request.setHeader(BALLERINA_PUBLISH_HEADER, "publish");
    http:Response response = check httpClient->post("/?hub.mode=publish", request);
    test:assertEquals(response.statusCode, 400);
    string responsePayload = check response.getTextPayload();
    test:assertEquals(responsePayload, "Empty value found for parameter 'hub.topic'");
}

@test:Config {
}
function testPublishContentLocalWithContentTypeHeaderWithParams() returns error? {
    http:Request request = new;
    request.setJsonPayload({ event: "event1" }, "application/json; charset=utf-8");
    request.setHeader(BALLERINA_PUBLISH_HEADER, "publish");
    http:Response response = check httpClient->post("/?hub.mode=publish&hub.topic=test", request);
    test:assertEquals(response.statusCode, 200);
}

@test:Config {
}
function testPublishContentLocalWithUnsupportedContentType() returns error? {
    http:Request request = new;
    request.setJsonPayload({ event: "event1" }, "application/vnd.ford.car+json; charset=utf-8");
    request.setHeader(BALLERINA_PUBLISH_HEADER, "publish");
    http:Response response = check httpClient->post("/?hub.mode=publish&hub.topic=test", request);
    test:assertEquals(response.statusCode, 400);
}
