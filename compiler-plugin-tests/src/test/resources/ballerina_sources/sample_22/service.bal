// Copyright (c) 2022 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
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

import ballerina/websubhub;
import ballerina/http;

listener http:Listener httpListener = new http:Listener(10012);
listener websubhub:Listener functionWithArgumentsListener = check new(httpListener, {
    secureSocket: {
        key: {
            path: "tests/resources/ballerinaKeystore.pkcs12",
            password: "ballerina"
        }
    }
});

final readonly & string[] TOPICS = ["test", "test1"];

service /websubhub on functionWithArgumentsListener {
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        if TOPICS.indexOf(message.topic) is () {
            return websubhub:TOPIC_REGISTRATION_SUCCESS;
        } else {
            return websubhub:TOPIC_REGISTRATION_ERROR;
        }
    }

    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message)
                        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {
        if TOPICS.indexOf(message.topic) !is () {
            return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
       } else {
            return websubhub:TOPIC_DEREGISTRATION_ERROR;
        }
    }

    isolated remote function onUpdateMessage(websubhub:UpdateMessage message)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        if TOPICS.indexOf(message.hubTopic) !is () {
            return websubhub:ACKNOWLEDGEMENT;
        } else {
            return websubhub:UPDATE_MESSAGE_ERROR;
        }
    }
    
    isolated remote function onSubscription(websubhub:Subscription message) returns websubhub:SubscriptionAccepted {
        return websubhub:SUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onSubscriptionValidation(websubhub:Subscription message)
                returns websubhub:SubscriptionDeniedError? {
        if TOPICS.indexOf(message.hubTopic) is () {
            return websubhub:SUBSCRIPTION_DENIED_ERROR;
        }
        return;
    }

    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) {}

    isolated remote function onUnsubscription(websubhub:Unsubscription message) 
                returns websubhub:UnsubscriptionAccepted {
        return websubhub:UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionValidation(websubhub:Unsubscription message)
                returns websubhub:UnsubscriptionDeniedError? {
        if TOPICS.indexOf(message.hubTopic) !is () {
            return websubhub:UNSUBSCRIPTION_DENIED_ERROR;
        }
        return;
    }

    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg){}
}
