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
import ballerina/test;

ListenerConfiguration listenerConfigs = {
    secureSocket: {
        key: {
            path: "tests/resources/ballerinaKeystore.pkcs12",
            password: "ballerina"
        }
    }
};

listener Listener hubListener = new(9096, listenerConfigs);

service /websubhub on hubListener {

    remote function onRegisterTopic(TopicRegistration message)
                                returns TopicRegistrationSuccess {
        log:printDebug("Received topic-registration request ", message = message);
        return TOPIC_REGISTRATION_SUCCESS;
    }

    remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationSuccess {
        log:printDebug("Received topic-deregistration request ", message = message);
        return TOPIC_DEREGISTRATION_SUCCESS;
    }

    remote function onUpdateMessage(UpdateMessage message)
               returns Acknowledgement|UpdateMessageError {
        log:printDebug("Received content-update request ", message = message);
        return ACKNOWLEDGEMENT;
    }
    
    remote function onSubscription(Subscription message)
                returns SubscriptionAccepted {
        log:printDebug("Received subscription request ", message = message);
        return SUBSCRIPTION_ACCEPTED;
    }

    remote function onSubscriptionValidation(Subscription message)
                returns SubscriptionDeniedError? {
    }

    remote function onSubscriptionIntentVerified(VerifiedSubscription message) {
    }

    remote function onUnsubscription(Unsubscription message)
               returns UnsubscriptionAccepted {
        log:printDebug("Received unsubscription request ", message = message);
        return UNSUBSCRIPTION_ACCEPTED;
    }

    remote function onUnsubscriptionValidation(Unsubscription message)
                returns UnsubscriptionDeniedError? {
    }

    remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription message){
    }
}

ClientConfiguration httpsConfig = {
    secureSocket: {
        cert: {
            path: "tests/resources/ballerinaTruststore.pkcs12",
            password: "ballerina"
        }
    }
};

PublisherClient sslEnabledPublisher = checkpanic new ("https://localhost:9096/websubhub", httpsConfig);

http:Client sslEnabledClient = checkpanic new("https://localhost:9096/websubhub", <http:ClientConfiguration>httpsConfig);

@test:Config{}
public function testPublisherRegisterSuccessWithSsl() {
    TopicRegistrationSuccess|TopicRegistrationError response =
                    sslEnabledPublisher->registerTopic("test");
    if (response is TopicRegistrationSuccess) {
        log:printDebug("Received topic-registration response ", res = response);
    } else {
        test:assertFail("Topic registration failed");
    }
}

@test:Config{}
public function testPublisherDeregisterSuccessWithSsl() {
    TopicDeregistrationSuccess|TopicDeregistrationError response =
                    sslEnabledPublisher->deregisterTopic("test");
    if (response is TopicDeregistrationSuccess) {
        log:printDebug("Received topic-deregistration response ", res = response);
    } else {
        test:assertFail("Topic registration failed");
    }
}

@test:Config{}
public function testPublisherNotifyEvenSuccessWithSsl() {
    Acknowledgement|UpdateMessageError response = sslEnabledPublisher->notifyUpdate("test");
    if (response is Acknowledgement) {
        log:printDebug("Received event-notify response ", res = response);
    } else {
        test:assertFail("Event notify failed");
    }
}

@test:Config{}
public function testPublisherPubishEventSuccessWithSsl() {
    map<string> params = { event: "event"};
    Acknowledgement|UpdateMessageError response = sslEnabledPublisher->publishUpdate("test", params);
    if (response is Acknowledgement) {
        log:printDebug("Received content-publish response ", res = response);
    } else {
        test:assertFail("Event publish failed");
    }
}

@test:Config {}
function testSubscriptionWithSsl() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=subscribe&hub.topic=test&hub.callback=http://localhost:9091/subscriber", 
                            "application/x-www-form-urlencoded");

    http:Response response = check sslEnabledClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}

@test:Config {}
function testUnsubscriptionWithSsl() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=unsubscribe&hub.topic=test2&hub.callback=http://localhost:9091/subscriber/unsubscribe",
                            "application/x-www-form-urlencoded");

    http:Response response = check sslEnabledClient->post("/", request);
    test:assertEquals(response.statusCode, 202);
}
