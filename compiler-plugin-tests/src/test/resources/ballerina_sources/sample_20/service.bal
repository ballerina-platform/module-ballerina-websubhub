// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/websubhub;
import ballerina/http;
import ballerina/io;

listener websubhub:Listener functionWithArgumentsListener = new(9090);

service /websubhub on functionWithArgumentsListener {

    isolated remote function onRegisterTopic(readonly & websubhub:TopicRegistration message, readonly & http:Headers headers)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        if (message.topic == "test") {
            websubhub:TopicRegistrationSuccess successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error websubhub:TopicRegistrationError("Registration Failed!");
        }
    }

    isolated remote function onDeregisterTopic(readonly & websubhub:TopicDeregistration message, readonly & http:Headers headers)
                        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {

        map<string> body = { isDeregisterSuccess: "true" };
        websubhub:TopicDeregistrationSuccess deregisterResult = {
            body
        };
        if (message.topic == "test") {
            return deregisterResult;
       } else {
            return error websubhub:TopicDeregistrationError("Topic Deregistration Failed!");
        }
    }

    isolated remote function onUpdateMessage(readonly & websubhub:UpdateMessage msg, readonly & http:Headers headers)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        websubhub:Acknowledgement ack = {};
        if (msg.hubTopic == "test") {
            return ack;
        } else if (!(msg.content is ())) {
            return ack;
        } else {
            return error websubhub:UpdateMessageError("Error in accessing content");
        }
    }
    
    isolated remote function onSubscription(readonly & websubhub:Subscription msg, readonly & http:Headers headers)
                returns websubhub:SubscriptionAccepted|websubhub:SubscriptionPermanentRedirect|websubhub:SubscriptionTemporaryRedirect
                |websubhub:BadSubscriptionError|websubhub:InternalSubscriptionError {
        websubhub:SubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else if (msg.hubTopic == "test1") {
            return successResult;
        } else {
            return error websubhub:BadSubscriptionError("Bad subscription");
        }
    }

    isolated remote function onSubscriptionValidation(readonly & websubhub:Subscription msg)
                returns websubhub:SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error websubhub:SubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onSubscriptionIntentVerified(readonly & websubhub:VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(readonly & websubhub:Unsubscription msg, readonly & http:Headers headers)
               returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|websubhub:InternalUnsubscriptionError {
        if (msg.hubTopic == "test" || msg.hubTopic == "test1" ) {
            websubhub:UnsubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error websubhub:BadUnsubscriptionError("Denied unsubscription for topic '" + <string> msg.hubTopic + "'");
        }
    }

    isolated remote function onUnsubscriptionValidation(readonly & websubhub:Unsubscription msg)
                returns websubhub:UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error websubhub:UnsubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(readonly & websubhub:VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}
