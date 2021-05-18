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

import ballerina/websubhub;
import ballerina/http;
import ballerina/io;

listener websubhub:Listener functionWithArgumentsListener = new(9090);

public type NewResponse record {|
    websubhub:Subscription message;
|};

service /websubhub on functionWithArgumentsListener {

    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        if (message.topic == "test") {
            return websubhub:TOPIC_REGISTRATION_SUCCESS;
        } else {
            return websubhub:TOPIC_REGISTRATION_ERROR;
        }
    }

    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message, http:Request baseRequest)
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

    isolated remote function onUpdateMessage(websubhub:UpdateMessage message)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        return websubhub:ACKNOWLEDGEMENT;
    }
    
    isolated remote function onSubscription(websubhub:Subscription msg)
                returns websubhub:SubscriptionAccepted|websubhub:SubscriptionPermanentRedirect|websubhub:SubscriptionTemporaryRedirect
                |websubhub:BadSubscriptionError|websubhub:InternalSubscriptionError|NewResponse {
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

    isolated remote function onSubscriptionValidation(websubhub:Subscription msg)
                returns websubhub:SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error websubhub:SubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(websubhub:Unsubscription msg)
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

    isolated remote function onUnsubscriptionValidation(websubhub:Unsubscription msg)
                returns websubhub:UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error websubhub:UnsubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}
