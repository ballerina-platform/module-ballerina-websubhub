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

import ballerina/log;
import ballerina/http;
import ballerina/test;
import ballerina/regex;

listener Listener hubListenerToAdditionalErrorDetails = new(9093);

var hubServiceToTestAdditionalErrorDetails = service object {

    remote function onRegisterTopic(TopicRegistration message)
                                returns TopicRegistrationError {
        return error TopicRegistrationError("Topic registration failed!",
                        body = { "hub.additional.details": "Feature is not supported in the hub"});
    }

    remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationError {
        return error TopicDeregistrationError("Topic deregistration failed!");
    }

    remote function onUpdateMessage(UpdateMessage msg)
               returns UpdateMessageError {
        return error UpdateMessageError("Error in accessing content", 
                     body = { "hub.additiona.details": "Content update failed!"});
    }
    
    remote function onSubscription(Subscription msg)
                returns SubscriptionAccepted|BadSubscriptionError|InternalSubscriptionError {
        SubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else {
            return error BadSubscriptionError("Bad subscription");
        }
    }

    remote function onSubscriptionValidation(Subscription msg)
                returns SubscriptionDeniedError? {
        if (msg.hubTopic != "test") {
            return error SubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
    }

    remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        log:print("Subscription Intent verified invoked!");
        isIntentVerified = true;
    }

    remote function onUnsubscription(Unsubscription msg)
               returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError {
        if (msg.hubTopic == "test") {
            UnsubscriptionAccepted successResult = {
                body: <map<string>>{
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
        if (msg.hubTopic != "test") {
            return error UnsubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
        log:print("Unsubscription Intent verified invoked!");
    }
};

@test:BeforeGroups { value:["additional-error-details"] }
function beforeAdditionalErrorDetailsTest() {
    checkpanic hubListenerToAdditionalErrorDetails.attach(hubServiceToTestAdditionalErrorDetails, "websubhub");
}

@test:AfterGroups { value:["additional-error-details"] }
function afterAdditionalErrorDetailsTest() {
    checkpanic hubListenerToAdditionalErrorDetails.gracefulStop();
}

http:Client errorDetailsTestClientEp = checkpanic new("http://localhost:9093/websubhub");

@test:Config {
    groups: ["additional-error-details"]
}
function testRegistrationFailureErrorDetails() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test1", "application/x-www-form-urlencoded");

    var response = check errorDetailsTestClientEp->post("/", request);
    test:assertEquals(response.statusCode, 200);
    var payload = response.getTextPayload();
    if (payload is error) {
        test:assertFail("Could not retrieve response body for topic-registration failure");
    } else {
        var responseBody = decodeResponseBody(payload);
        log:print("Retrieved error-response for topic registration failure ", responseBody = responseBody);
        test:assertEquals(responseBody["hub.mode"], "denied");
        test:assertEquals(responseBody["hub.reason"], "Topic registration failed!");
        test:assertEquals(responseBody["hub.additional.details"], "Feature is not supported in the hub");
    }
}

@test:Config {
    groups: ["additional-error-details"]
}
function testDeregistrationFailureErrorDetails() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test1", "application/x-www-form-urlencoded");

    var response = check errorDetailsTestClientEp->post("/", request);
    test:assertEquals(response.statusCode, 200);
    var payload = response.getTextPayload();
    if (payload is error) {
        test:assertFail("Could not retrieve response body for topic-deregistration failure");
    } else {
        var responseBody = decodeResponseBody(payload);
        log:print("Retrieved error-response for topic de-registration failure ", responseBody = responseBody);
        test:assertEquals(responseBody["hub.mode"], "denied");
        test:assertEquals(responseBody["hub.reason"], "Topic deregistration failed!");
    }
}

@test:Config {
    groups: ["additional-error-details"]
}
function testUpdateMessageErrorDetails() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test", "application/x-www-form-urlencoded");

    var response = check errorDetailsTestClientEp->post("/", request);
    test:assertEquals(response.statusCode, 200);
    var payload = response.getTextPayload();
    if (payload is error) {
        test:assertFail("Could not retrieve response body for content update");
    } else {
        var responseBody = decodeResponseBody(payload);
        log:print("Retrieved error-response for content-update failure ", responseBody = responseBody);
        test:assertEquals(responseBody["hub.mode"], "denied");
        test:assertEquals(responseBody["hub.reason"], "Error in accessing content");
    }  
}

isolated function decodeResponseBody(string payload) returns map<string> {
    map<string> body = {};
    if (payload.length() > 0) {
        string[] splittedPayload = regex:split(payload, "&");
        foreach var bodyPart in splittedPayload {
            var responseComponent =  regex:split(bodyPart, "=");
            if (responseComponent.length() == 2) {
                body[responseComponent[0]] = responseComponent[1];
            }
        }
        return body;
    }
    return body;
} 