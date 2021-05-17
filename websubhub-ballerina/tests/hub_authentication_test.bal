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
import ballerina/log;
import ballerina/jwt;
import ballerina/test;

listener Listener securedListener = new(9100,
    secureSocket = {
        key: {
            certFile: "tests/resources/public.crt",
            keyFile: "tests/resources/private.key"
        }
    }
);

http:ListenerJwtAuthHandler handler = new({
    issuer: "wso2",
    audience: "ballerina",
    signatureConfig: {
        certFile: "tests/resources/public.crt"
    },
    scopeKey: "scp"
});

service /websubhub on securedListener {

    remote function onRegisterTopic(TopicRegistration message, http:Request req)
                                returns TopicRegistrationSuccess|TopicRegistrationError {
        string? auth = doAuth(req);
        if (auth is string) {
            return error TopicRegistrationError(auth);
        }
        log:printDebug("Received topic-registration request ", message = message);
        return TOPIC_REGISTRATION_SUCCESS;
    }

    remote function onDeregisterTopic(TopicDeregistration message, http:Request req)
                        returns TopicDeregistrationSuccess|TopicDeregistrationError {
        string? auth = doAuth(req);
        if (auth is string) {
            return error TopicDeregistrationError(auth);
        }
        log:printDebug("Received topic-deregistration request ", message = message);
        return TOPIC_DEREGISTRATION_SUCCESS;
    }

    remote function onUpdateMessage(UpdateMessage message, http:Request req)
               returns Acknowledgement|UpdateMessageError {
        string? auth = doAuth(req);
        if (auth is string) {
            return error UpdateMessageError(auth);
        }
        log:printDebug("Received content-update request ", message = message);
        return ACKNOWLEDGEMENT;
    }
    
    remote function onSubscription(Subscription message, http:Request req)
                returns SubscriptionAccepted|InternalSubscriptionError {
        string? auth = doAuth(req);
        if (auth is string) {
            return error InternalSubscriptionError(auth);
        }
        log:printDebug("Received subscription request ", message = message);
        return SUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription message) {
    }

    remote function onUnsubscription(Unsubscription message, http:Request req)
               returns UnsubscriptionAccepted|InternalUnsubscriptionError {
        string? auth = doAuth(req);
        if (auth is string) {
            return error InternalUnsubscriptionError(auth);
        }
        log:printDebug("Received unsubscription request ", message = message);
        return UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription message){
    }
}

function doAuth(http:Request req) returns string? {
    jwt:Payload|http:Unauthorized authn = handler.authenticate(req);
    if (authn is http:Unauthorized) {
        string errorMsg = "Failed to authenticate the request. " + <string>authn?.body;
        log:printError(errorMsg);
        return errorMsg;
    }
    http:Forbidden? authz = handler.authorize(<jwt:Payload>authn, "hello");
    if (authz is http:Forbidden) {
        string errorMsg = "Failed to authorize the request for the scope key: 'scp' and value: 'hello'.";
        log:printError(errorMsg);
        return errorMsg;
    }
    return;
}

PublisherClient authEnabledPublisherClient = check new("https://localhost:9100/websubhub",
    auth = {
        username: "ballerina",
        issuer: "wso2",
        audience: ["ballerina", "ballerina.org", "ballerina.io"],
        keyId: "5a0b754-895f-4279-8843-b745e11a57e9",
        jwtId: "JlbmMiOiJBMTI4Q0JDLUhTMjU2In",
        customClaims: { "scp": "hello" },
        expTime: 3600,
        signatureConfig: {
            config: {
                keyFile: "tests/resources/private.key"
            }
        }
    },
    secureSocket = {
        cert: "tests/resources/public.crt"
    }
);

http:Client authEnabledClient = check new("https://localhost:9100/websubhub", {
    auth: {
        username: "ballerina",
        issuer: "wso2",
        audience: ["ballerina", "ballerina.org", "ballerina.io"],
        keyId: "5a0b754-895f-4279-8843-b745e11a57e9",
        jwtId: "JlbmMiOiJBMTI4Q0JDLUhTMjU2In",
        customClaims: { "scp": "hello" },
        expTime: 3600,
        signatureConfig: {
            config: {
                keyFile: "tests/resources/private.key"
            }
        }
    },
    secureSocket: {
        cert: "tests/resources/public.crt"
    }
});

@test:Config{
    groups: ["authEnabledHub"]
}
public function testTopicRegisterSuccessWithAuthentication() {
    TopicRegistrationSuccess|TopicRegistrationError response =
                    authEnabledPublisherClient->registerTopic("test");
    if (response is TopicRegistrationSuccess) {
        log:printDebug("Received topic-registration response ", res = response);
    } else {
        test:assertFail("Topic registration failed");
    }
}

@test:Config{
    groups: ["authEnabledHub"]
}
public function testTopicDeregisterSuccessWithAuthentication() {
    TopicDeregistrationSuccess|TopicDeregistrationError response =
                    authEnabledPublisherClient->deregisterTopic("test");
    if (response is TopicDeregistrationSuccess) {
        log:printDebug("Received topic-deregistration response ", res = response);
    } else {
        test:assertFail("Topic registration failed");
    }
}

@test:Config{
    groups: ["authEnabledHub"]
}
public function testPublisherNotifyEvenSuccessWithAuthentication() {
    Acknowledgement|UpdateMessageError response = authEnabledPublisherClient->notifyUpdate("test");
    if (response is Acknowledgement) {
        log:printDebug("Received event-notify response ", res = response);
    } else {
        test:assertFail("Event notify failed");
    }
}

@test:Config{
    groups: ["authEnabledHub"]
}
public function testPublisherPubishEventSuccessWithAuthentication() {
    map<string> params = { event: "event"};
    Acknowledgement|UpdateMessageError response = authEnabledPublisherClient->publishUpdate("test", params);
    if (response is Acknowledgement) {
        log:printDebug("Received content-publish response ", res = response);
    } else {
        test:assertFail("Event publish failed");
    }
}

@test:Config{
    groups: ["authEnabledHub"]
}
function testSubscriptionWithAuthentication() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");
    http:Response response = check authEnabledClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config{
    groups: ["authEnabledHub"]
}
function testUnsubscriptionWithAuthentication() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded");
    http:Response response = check authEnabledClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}
