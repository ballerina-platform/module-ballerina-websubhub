// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
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

import ballerina/test;
import ballerina/http;
import ballerina/lang.runtime;

listener Listener autoSubscriptionVerifyListener = new(9104);

http:Client subAutoVerifyClient = check new("http://localhost:9104");

const AUTO_VERIFY_TOPIC = "autoVerifyTopic";
const AUTO_VERIFY_SUBSCRIBER = "https://sample.subscriber.xyz";

isolated boolean subscriptionAutoVerified = false;
isolated boolean unsubscriptionAutoVerified = false;

Service autoVerifyEnabledService = @ServiceConfig { 
    autoVerifySubscription: true
}
service object {

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
        Error? result = hubController.markAsVerified(msg);
        if result is Error {
            return INTERNAL_SUBSCRIPTION_ERROR;
        }

        return SUBSCRIPTION_ACCEPTED;    
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        if AUTO_VERIFY_TOPIC == msg.hubTopic && AUTO_VERIFY_SUBSCRIBER == msg.hubCallback {
            lock {
                subscriptionAutoVerified = true;
            }
        }
    }

    isolated remote function onUnsubscription(Unsubscription msg, http:Headers headers, Controller hubController)
    returns UnsubscriptionAccepted|InternalUnsubscriptionError {
        Error? result = hubController.markAsVerified(msg);
        if result is Error {
            return INTERNAL_UNSUBSCRIPTION_ERROR;
        }

        return UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
        if AUTO_VERIFY_TOPIC == msg.hubTopic && AUTO_VERIFY_SUBSCRIBER == msg.hubCallback {
            lock {
                unsubscriptionAutoVerified = true;
            }
        }
    }
};

Service autoVerifyDisabledService = service object {

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
        Error? result = hubController.markAsVerified(msg);
        if result is Error {
            return INTERNAL_SUBSCRIPTION_ERROR;
        }

        return SUBSCRIPTION_ACCEPTED;    
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {}

    isolated remote function onUnsubscription(Unsubscription msg, http:Headers headers, Controller hubController)
    returns UnsubscriptionAccepted|InternalUnsubscriptionError {
        Error? result = hubController.markAsVerified(msg);
        if result is Error {
            return INTERNAL_UNSUBSCRIPTION_ERROR;
        }

        return UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg) {}
};

@test:BeforeGroups { value:["autoVerifySubscription"] }
function beforeAutoVerifySubscriptionTest() returns error? {
    check autoSubscriptionVerifyListener.attach(autoVerifyEnabledService, "websubhub");
    check autoSubscriptionVerifyListener.attach(autoVerifyDisabledService, "websubhubnegative");
}

@test:AfterGroups { value:["autoVerifySubscription"] }
function afterAutoVerifySubscriptionTest() returns error? {
    check autoSubscriptionVerifyListener.gracefulStop();
}

@test:Config{
    groups: ["autoVerifySubscription"]
}
function testSubscriptionWithAutoVerification() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=autoVerifyTopic&hub.callback=https://sample.subscriber.xyz", 
                            "application/x-www-form-urlencoded");
    http:Response response = check subAutoVerifyClient->post("/websubhub", request);
    test:assertEquals(response.statusCode, 202);
    
    runtime:sleep(2);
    boolean subscriptionVerified = false;
    lock {
        subscriptionVerified = subscriptionAutoVerified;
    }
    test:assertTrue(subscriptionVerified);
}

@test:Config{
    groups: ["autoVerifySubscription"]
}
function testUnsubscriptionWithAutoVerification() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=autoVerifyTopic&hub.callback=https://sample.subscriber.xyz",
                            "application/x-www-form-urlencoded");
    http:Response response = check subAutoVerifyClient->post("/websubhub", request);
    test:assertEquals(response.statusCode, 202);

    runtime:sleep(2);
    boolean unsubscriptionVerified = false;
    lock {
        unsubscriptionVerified = unsubscriptionAutoVerified;
    }
    test:assertTrue(unsubscriptionVerified);
}

@test:Config{
    groups: ["autoVerifySubscription"]
}
function testSubscriptionWithAutoVerificationError() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=autoVerifyTopic&hub.callback=https://sample.subscriber.xyz", 
                            "application/x-www-form-urlencoded");
    http:Response response = check subAutoVerifyClient->post("/websubhubnegative", request);
    test:assertEquals(response.statusCode, 500);
}

@test:Config{
    groups: ["autoVerifySubscription"]
}
function testUnsubscriptionWithAutoVerificationError() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=autoVerifyTopic&hub.callback=https://sample.subscriber.xyz",
                            "application/x-www-form-urlencoded");
    http:Response response = check subAutoVerifyClient->post("/websubhubnegative", request);
    test:assertEquals(response.statusCode, 500);
}
