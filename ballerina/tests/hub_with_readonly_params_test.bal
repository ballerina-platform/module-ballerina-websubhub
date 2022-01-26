// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
import ballerina/io;
import ballerina/mime;
import ballerina/test;

service /websubhub on new Listener(9102) {
    isolated remote function onRegisterTopic(readonly & TopicRegistration msg) returns TopicRegistrationSuccess {
        test:assertTrue(msg is readonly);
        return TOPIC_REGISTRATION_SUCCESS;
    }

    isolated remote function onDeregisterTopic(readonly & TopicDeregistration msg) returns TopicDeregistrationSuccess {
        test:assertTrue(msg is readonly);
        return TOPIC_DEREGISTRATION_SUCCESS;
    }

    isolated remote function onUpdateMessage(readonly & UpdateMessage msg) returns Acknowledgement {
        test:assertTrue(msg is readonly);
        return ACKNOWLEDGEMENT;
    }

    isolated function onSubscription(readonly & Subscription msg) returns SubscriptionAccepted {
        test:assertTrue(msg is readonly);
        return SUBSCRIPTION_ACCEPTED;
    }

    remote function onSubscriptionValidation(readonly & Subscription msg) {
        test:assertTrue(msg is readonly);
    }
    
    isolated remote function onSubscriptionIntentVerified(readonly & VerifiedSubscription msg) {
        test:assertTrue(msg is readonly);
    }

    isolated function onUnsubscription(readonly & Subscription msg) returns SubscriptionAccepted {
        return UNSUBSCRIPTION_ACCEPTED;
    }

    remote function onUnsubscriptionValidation(readonly & Unsubscription msg) {
        test:assertTrue(msg is readonly);
    }

    isolated remote function onUnsubscriptionIntentVerified(readonly & VerifiedUnsubscription msg){
        test:assertTrue(msg is readonly);
    }
}

PublisherClient readonlyParamsTestPublisher = check new ("http://localhost:9102/websubhub");

@test:Config{}
public function testPublisherRegisterSuccessWithReadonly() returns error? {
    TopicRegistrationSuccess registrationResponse = check readonlyParamsTestPublisher->registerTopic("test");
    io:println(registrationResponse);
}

@test:Config{}
public function testPublisherDeregisterSuccessWithReadonly() returns error? {
    TopicDeregistrationSuccess deRegistrationResponse = check readonlyParamsTestPublisher->deregisterTopic("test");
    io:println(deRegistrationResponse);
}

@test:Config{}
public function testPublisherNotifyEvenSuccessWithReadonly() returns error? {
    Acknowledgement response = check readonlyParamsTestPublisher->notifyUpdate("test");
    io:println(response);
}

@test:Config {}
public function testPublisherPubishEventSuccessWithReadonly() returns error? {
    map<string> params = {event: "event"};
    Acknowledgement response = check readonlyParamsTestPublisher->publishUpdate("test", params);
    io:println(response);
}

http:Client readonlyParamsTestSubscriber = check new ("http://localhost:9102/websubhub");

@test:Config {
    groups: [
        "readOnlyParams"
    ]
}
public function testSubscriptionSuccessWithReadonly() returns error? {
    http:Request req = new;
    string payload = string `${HUB_MODE}=subscribe&${HUB_TOPIC}=test&${HUB_CALLBACK}=http://localhost:9191/subscriber`;
    req.setTextPayload(payload, mime:APPLICATION_FORM_URLENCODED);
    http:Response response = check readonlyParamsTestSubscriber->post("", req);
    test:assertEquals(response.statusCode, 202, "Unexpected response status-code");
}

@test:Config {
    groups: [
        "readOnlyParams"
    ]
}
public function testUnsubscriptionSuccessWithReadonly() returns error? {
    http:Request req = new;
    string payload = string `${HUB_MODE}=unsubscribe&${HUB_TOPIC}=test&${HUB_CALLBACK}=http://localhost:9191/subscriber`;
    req.setTextPayload(payload, mime:APPLICATION_FORM_URLENCODED);
    http:Response response = check readonlyParamsTestSubscriber->post("", req);
    test:assertEquals(response.statusCode, 202, "Unexpected response status-code");
}
