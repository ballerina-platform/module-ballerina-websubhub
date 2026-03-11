// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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
import ballerina/lang.runtime;

Service subIntentVerifyFailureSvc = service object {

    isolated remote function onRegisterTopic(TopicRegistration message) returns TopicRegistrationError {
        return TOPIC_REGISTRATION_ERROR;
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message) returns TopicDeregistrationError {
        return TOPIC_DEREGISTRATION_ERROR;
    }

    isolated remote function onUpdateMessage(UpdateMessage msg) returns UpdateMessageError {
        return UPDATE_MESSAGE_ERROR;
    }
    
    isolated remote function onSubscription(Subscription msg, http:Headers headers, Controller hubController) 
        returns SubscriptionAccepted|InternalSubscriptionError {
        return SUBSCRIPTION_ACCEPTED;    
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) returns error? {
        return error ("Internal error occurred while processing the verified subscription");
    }

    isolated remote function onUnsubscription(Unsubscription msg, http:Headers headers, Controller hubController)
        returns UnsubscriptionAccepted|InternalUnsubscriptionError {
        return UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg) returns error? {
        return error ("Internal error occurred while processing the verified unsubscription");
    }
};

final http:Client subNotifyClient = check new("http://localhost:9105");

@test:BeforeGroups { 
    value:["subscriberNotify"] 
}
function beforeSubNotifyTest() returns error? {
    check commonHubListener.attach(subIntentVerifyFailureSvc, "websubhub");
}

@test:Config{
    groups: ["subscriberNotify"]
}
function testSubscriptionHubErrorNotification() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=testTopic&hub.callback=http://localhost:9191/subscriber/hubError", 
                            "application/x-www-form-urlencoded");
    http:Response response = check subNotifyClient->post("/websubhub", request);
    test:assertEquals(response.statusCode, 202);
    
    runtime:sleep(2);
    boolean onHubErrorInvoked = false;
    lock {
        onHubErrorInvoked = isOnSubErrorInvoked;
    }
    test:assertTrue(onHubErrorInvoked, "Hub level error was not propagated to the subscriber");
}

@test:Config{
    groups: ["subscriberNotify"]
}
function testUnsubscriptionHubErrorNotification() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=testTopic&hub.callback=http://localhost:9191/subscriber/hubError",
                            "application/x-www-form-urlencoded");
    http:Response response = check subNotifyClient->post("/websubhub", request);
    test:assertEquals(response.statusCode, 202);

    runtime:sleep(2);
    boolean onHubErrorInvoked = false;
    lock {
        onHubErrorInvoked = isOnUnSubErrorInvoked;
    }
    test:assertTrue(onHubErrorInvoked, "Hub level error was not propagated to the subscriber");
}
