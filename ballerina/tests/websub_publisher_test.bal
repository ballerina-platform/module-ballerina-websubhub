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

import ballerina/io;
import ballerina/http;
import ballerina/test;

listener Listener testListener = new(9092);

service /websubhub on testListener {
    isolated remote function onRegisterTopic(TopicRegistration message)
                                returns TopicRegistrationSuccess|TopicRegistrationError {
        if message.topic == "test" {
            return {
                headers: {
                    "header1": "value1"
                },
                body: <map<string>>{
                    "message": "Topic registration successfull"
                }
            };
        }
        return error TopicRegistrationError("Topic registration failed",
            statusCode = http:STATUS_OK,
            body = {
                "message": "Invalid topic received"
            },
            headers = {
                "header2": "value2"
            }
        );
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationSuccess|TopicDeregistrationError {
        if message.topic == "test" {
            return {
                headers: {
                    "header1": "value1"
                },
                body: <map<string>>{
                    "message": "Topic deregistration successfull"
                }
            };
        }
        return error TopicDeregistrationError("Topic deregistration failed",
            statusCode = http:STATUS_OK,
            body = {
                "message": "Invalid topic received"
            },
            headers = {
                "header2": "value2"
            }
        );
    }

    isolated remote function onUpdateMessage(UpdateMessage msg) returns Acknowledgement|UpdateMessageError {
        if msg.hubTopic != "test" {
            return error UpdateMessageError(string `Content update action ${msg.msgType} failed`,
                statusCode = http:STATUS_OK,
                body = {
                    "message": "Content update received for an invalid topic"
                },
                headers = {
                    "header2": "value2"
                }
            );
        }
        return {
            headers: {
                "header1": "value1"
            },
            body: <map<string>>{
                "message": string `Content update action ${msg.msgType} is successful`
            }
        };
    }
    
    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}

PublisherClient websubHubClientEP = check new ("http://localhost:9092/websubhub");

@test:Config{}
public function testPublisherRegisterSuccess() returns error? {
    TopicRegistrationSuccess response = check websubHubClientEP->registerTopic("test");
    test:assertEquals(response.statusCode, http:STATUS_OK);
    map<string> expectedBody = {
        "hub.mode":"accepted",
        "message":"Topic registration successfull"
    };
    test:assertEquals(response?.body, expectedBody);
    test:assertEquals(response?.headers["header1"], "value1");
}

@test:Config{}
public function testPublisherRegisterFailure() {
    TopicRegistrationSuccess|TopicRegistrationError response = websubHubClientEP->registerTopic("test1");
    if response is TopicRegistrationError {
        CommonResponse details = response.detail();
        test:assertEquals(details.statusCode, http:STATUS_OK);
        map<string> expectedBody = {"hub.mode":"denied","hub.reason":"Topic registration failed","message":"Invalid topic received"};
        test:assertEquals(details?.body, expectedBody);
        test:assertEquals(details?.headers["header2"], "value2");
    } else {
        test:assertFail("Topic registration passed for erroneous scenario");
    }
}

@test:Config{}
public function testPublisherDeregisterSuccess() returns error? {
    TopicDeregistrationSuccess response = check websubHubClientEP->deregisterTopic("test");
    test:assertEquals(response.statusCode, http:STATUS_OK);
    map<string> expectedBody = {
        "hub.mode":"accepted",
        "message": "Topic deregistration successfull"
    };
    test:assertEquals(response?.body, expectedBody);
    test:assertEquals(response?.headers["header1"], "value1");
}


@test:Config{}
public function testPublisherDeregisterFailure() {
    TopicDeregistrationSuccess|TopicDeregistrationError response = websubHubClientEP->deregisterTopic("test1");
    if response is TopicDeregistrationError {
        CommonResponse details = response.detail();
        test:assertEquals(details.statusCode, http:STATUS_OK);
        map<string> expectedBody = {"hub.mode":"denied","hub.reason":"Topic deregistration failed","message":"Invalid topic received"};
        test:assertEquals(details?.body, expectedBody);
        test:assertEquals(details?.headers["header2"], "value2");
    } else {
        test:assertFail("Topic registration passed for error scenario");
    }
}

@test:Config{}
public function testPublisherNotifyEvenSuccess() returns error? {
    Acknowledgement response = check websubHubClientEP->notifyUpdate("test");
    test:assertEquals(response.statusCode, http:STATUS_OK);
    map<string> expectedBody = {
        "hub.mode":"accepted",
        "message":"Content update action EVENT is successful"
    };
    test:assertEquals(response?.body, expectedBody);
    test:assertEquals(response?.headers["header1"], "value1");
}

@test:Config{}
public function testPublisherNotifyEventFailure() {
    Acknowledgement|UpdateMessageError response = websubHubClientEP->notifyUpdate("test1");
    if response is UpdateMessageError {
        CommonResponse details = response.detail();
        test:assertEquals(details.statusCode, http:STATUS_OK);
        map<string> expectedBody = {"hub.mode":"denied","hub.reason":"Content update action EVENT failed","message":"Content update received for an invalid topic"};
        test:assertEquals(details?.body, expectedBody);
        test:assertEquals(details?.headers["header2"], "value2");
    } else {
        test:assertFail("Event notify success for erroneous scenario");
    }
}

@test:Config{}
public function testPublisherPubishEventSuccess() returns error? {
    map<string> params = { event: "event"};
    Acknowledgement response = check websubHubClientEP->publishUpdate("test", params);
    test:assertEquals(response.statusCode, http:STATUS_OK);
    map<string> expectedBody = {
        "hub.mode":"accepted",
        "message":"Content update action PUBLISH is successful"
    };
    test:assertEquals(response?.body, expectedBody);
    test:assertEquals(response?.headers["header1"], "value1");
}

@test:Config{}
public function testPublisherPubishEventFailure() {
    map<string> params = { event: "event"};
    Acknowledgement|UpdateMessageError response = websubHubClientEP->publishUpdate("test1", params);
    if response is UpdateMessageError {
        CommonResponse details = response.detail();
        test:assertEquals(details.statusCode, http:STATUS_OK);
        map<string> expectedBody = {"hub.mode":"denied","hub.reason":"Content update action PUBLISH failed","message":"Content update received for an invalid topic"};
        test:assertEquals(details?.body, expectedBody);
        test:assertEquals(details?.headers["header2"], "value2");
    } else {
        test:assertFail("Event publish success for erroneous scenario");
    }
}
