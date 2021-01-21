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
import ballerina/test;

listener Listener testListener = new(9191);

service /websubhub on testListener {

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
    
    remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
        isIntentVerified = true;
    }

    remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}

PublisherClient websubHubClientEP = checkpanic new ("http://localhost:9191/websubhub");

@test:Config{}
public function testPublisherRegisterSuccess() {
    TopicRegistrationSuccess|TopicRegistrationError registrationResponse =
                    websubHubClientEP->registerTopic("test");

    if (registrationResponse is TopicRegistrationSuccess) {
        io:println(registrationResponse);
    } else {
        test:assertFail("Topic registration failed");
    }
}

@test:Config{}
public function testPublisherRegisterFailure() {
    TopicRegistrationSuccess|TopicRegistrationError registrationResponse =
                    websubHubClientEP->registerTopic("test1");

    if (registrationResponse is TopicRegistrationError) {
        io:println(registrationResponse);
    } else {
        test:assertFail("Topic registration passed");
    }
}

@test:Config{}
public function testPublisherDeregisterSuccess() {
    TopicDeregistrationSuccess|TopicDeregistrationError deRegistrationResponse =
                    websubHubClientEP->deregisterTopic("test");

    if (deRegistrationResponse is TopicDeregistrationSuccess) {
        io:println(deRegistrationResponse);
    } else {
        test:assertFail("Topic registration failed");
    }
}


@test:Config{}
public function testPublisherDeregisterFailure() {
    TopicDeregistrationSuccess|TopicDeregistrationError deRegistrationResponse =
                    websubHubClientEP->deregisterTopic("test1");

    if (deRegistrationResponse is TopicDeregistrationError) {
        io:println(deRegistrationResponse);
    } else {
        test:assertFail("Topic registration passed");
    }
}

@test:Config{}
public function testPublisherNotifyEvenSuccess() {
    Acknowledgement|UpdateMessageError response = websubHubClientEP->notifyUpdate("test");

    if (response is Acknowledgement) {
        io:println(response);
    } else {
        io:println(response);
        test:assertFail("Event notify failed");
    }
}

@test:Config{}
public function testPublisherPubishEventSuccess() {
    map<string> params = { event: "event"};
    Acknowledgement|UpdateMessageError response = websubHubClientEP->publishUpdate("test", params);

    if (response is Acknowledgement) {
        io:println(response);
    } else {
        io:println(response);
        test:assertFail("Event publish failed");
    }
}