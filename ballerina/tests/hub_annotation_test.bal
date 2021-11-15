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

import ballerina/lang.runtime;
import ballerina/http;
import ballerina/io;
import ballerina/test;

boolean isSubscriptionVerifiedWithSsl = false;
boolean isContentDeliveredWithSsl = false;

http:ListenerConfiguration subConfigs = {
    secureSocket: {
        key: {
            path: "tests/resources/ballerinaKeystore.pkcs12",
            password: "ballerina"
        }
    }
};

service /subscriber on new http:Listener(9098, subConfigs) {
    resource function get .(http:Request req, http:Caller caller) returns @tainted error? {
        map<string[]> payload = req.getQueryParams();
        string[] hubMode = <string[]> payload["hub.mode"];
        if (hubMode[0] == "denied") {
            io:println("[ANNOTATION_CONFIG] Subscriber Validation failed ", payload);
            check caller->respond("");
        } else {
            isSubscriptionVerifiedWithSsl = true;
            string[] challengeArray = <string[]> payload["hub.challenge"];
            io:println("[ANNOTATION_CONFIG] Subscriber Verified ", challengeArray);
            check caller->respond(challengeArray[0]);
        }
    }

    resource function post .(http:Request req, http:Caller caller) returns @tainted error? {
        isContentDeliveredWithSsl = true;
        check caller->respond();
    }
}

@ServiceConfig {
    webHookConfig: {
        secureSocket: {
            cert: {
                path: "tests/resources/ballerinaTruststore.pkcs12",
                password: "ballerina"
            }
        }
    }
}
service /websubhub on new Listener(9099) {

    isolated remote function onRegisterTopic(TopicRegistration message) returns TopicRegistrationSuccess {
        return TOPIC_REGISTRATION_SUCCESS;
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message) returns TopicDeregistrationSuccess {
        return TOPIC_DEREGISTRATION_SUCCESS;
    }

    remote function onUpdateMessage(UpdateMessage msg) returns Acknowledgement|UpdateMessageError {
        Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9098/subscriber");
        HubClient|error? clientEp = new (subscriptionMsg, httpsConfig);
        if (clientEp is HubClient) {
            ContentDistributionMessage updateMsg = {content: <string>msg.content};
            ContentDistributionSuccess|SubscriptionDeletedError|error? publishResponse = clientEp->notifyContentDistribution(updateMsg);
            return ACKNOWLEDGEMENT;
        } else {
            return UPDATE_MESSAGE_ERROR;
        }
    }
    
    isolated remote function onSubscription(Subscription msg) returns SubscriptionAccepted {
        io:println("[ANNOTATION_CONFIG] Received subscription ", msg);
        return SUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onSubscriptionValidation(Subscription msg) {
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
    }

    isolated remote function onUnsubscription(Unsubscription msg) returns UnsubscriptionAccepted {
        return UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionValidation(Unsubscription msg) {
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg) {
    }
}

PublisherClient annotationTestPublisher = check new ("http://localhost:9099/websubhub");

http:Client annotationTestClient = check new("http://localhost:9099/websubhub");

@test:Config {}
function testSubscriptionWithAnnotationConfig() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=https://localhost:9098/subscriber", 
                            "application/x-www-form-urlencoded");
    http:Response response = check annotationTestClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
    waitForActionCompletion(isSubscriptionVerifiedWithSsl);
    test:assertTrue(isSubscriptionVerifiedWithSsl);
}

@test:Config {}
function testContentUpdateWithAnnotationConfig() returns @tainted error? {
    Acknowledgement response = check annotationTestPublisher->publishUpdate("test", "This is a test message");
    waitForActionCompletion(isContentDeliveredWithSsl);
    test:assertTrue(isContentDeliveredWithSsl);
}

isolated function waitForActionCompletion(boolean flag, int count = 10) {
    int counter = 10;
    while (!flag && counter >= 0) {
        runtime:sleep(1);
        counter -= 1;
    }
}
