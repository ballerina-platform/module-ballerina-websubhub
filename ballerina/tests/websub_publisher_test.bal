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

listener Listener testListener = new(9092);

service /websubhub on testListener {

    isolated remote function onRegisterTopic(TopicRegistration message)
                                returns TopicRegistrationSuccess|TopicRegistrationError {
        if (message.topic == "test") {
            return TOPIC_REGISTRATION_SUCCESS;
        } else {
            return TOPIC_REGISTRATION_ERROR;
        }
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationSuccess|TopicDeregistrationError {
        if (message.topic == "test") {
            return TOPIC_DEREGISTRATION_SUCCESS;
       } else {
            return TOPIC_DEREGISTRATION_ERROR;
        }
    }

    isolated remote function onUpdateMessage(UpdateMessage msg)
               returns Acknowledgement|UpdateMessageError {
        if (msg.hubTopic == "test") {
            return ACKNOWLEDGEMENT;
        } else if (!(msg.content is ())) {
            return ACKNOWLEDGEMENT;
        } else {
            return UPDATE_MESSAGE_ERROR;
        }
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
