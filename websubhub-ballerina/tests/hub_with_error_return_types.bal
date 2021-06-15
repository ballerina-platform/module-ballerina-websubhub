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

import ballerina/http;
import ballerina/test;

http:Client hubWithErrorReturnTypesClient = checkpanic new("http://localhost:9101/websubhub");

listener Listener hubWithErrorReturnTypesListener = new(9101);

service /websubhub on hubWithErrorReturnTypesListener {

    isolated remote function onRegisterTopic(TopicRegistration message) returns error {
        return error ("Registration Failed!");
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message) returns error {
        return error ("Topic Deregistration Failed!");
    }

    isolated remote function onUpdateMessage(UpdateMessage msg) returns error {
        return error ("Error in accessing content");
    }
    
    isolated remote function onSubscription(Subscription msg) returns error {
        return error ("Error occurred while processing subscription");
    }

    isolated remote function onSubscriptionValidation(Subscription msg) returns error? {
        return error ("Denied subscription with Hub");
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) returns error? {
        return error ("Error occcurred while verifying subscription intent");
    }

    isolated remote function onUnsubscription(Unsubscription msg) returns error {
        return error ("Denied unsubscription for topic '" + <string> msg.hubTopic + "'");
    }

    isolated remote function onUnsubscriptionValidation(Unsubscription msg) returns error? {
        return error ("Denied subscription with Hub");
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg) returns error? {
        return error ("Error occcurred while verifying unsubscription intent");
    }
}


@test:Config {
}
function testFailurePostWithErrorReturnTypes() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register123&hub.topic=test", "application/x-www-form-urlencoded");
    http:Response response = check hubWithErrorReturnTypesClient->post("/", request);
    test:assertEquals(response.statusCode, 400);
    test:assertEquals(response.getTextPayload(), "The request does not include valid `hub.mode` form param.");
}

@test:Config {
}
function testRegistrationFailureWithErrorReturnTypes() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test1", "application/x-www-form-urlencoded");
    string expectedPayload = "hub.mode=denied&hub.reason=Registration Failed!";
    http:Response response = check hubWithErrorReturnTypesClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testDeregistrationFailureWithErrorReturnTypes() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test1", "application/x-www-form-urlencoded");
    string expectedPayload = "hub.mode=denied&hub.reason=Topic Deregistration Failed!";
    http:Response response = check hubWithErrorReturnTypesClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
    test:assertEquals(response.getTextPayload(), expectedPayload);
}

@test:Config {
}
function testSubscriptionFailureWithErrorReturnTypes() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");
    http:Response response = check hubWithErrorReturnTypesClient->post("/", request);
    test:assertEquals(response.statusCode, 500);
}

@test:Config {
}
function testUnsubscriptionFailureWithErrorReturnTypes() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded");
    http:Response response = check hubWithErrorReturnTypesClient->post("/", request);
    test:assertEquals(response.statusCode, 500);
}

@test:Config {
}
function testPublishContentFailureWithErrorReturnTypes() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test1", "application/x-www-form-urlencoded");
    http:Response response = check hubWithErrorReturnTypesClient->post("/", request);
    test:assertEquals(response.statusCode, 200);
}
