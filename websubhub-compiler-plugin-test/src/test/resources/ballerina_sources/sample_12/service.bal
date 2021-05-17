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

import ballerina/websubhub as foo;
import ballerina/http;
import ballerina/io;

listener http:Listener httpListener = new http:Listener(10012);

service /websubhub on new foo:Listener(httpListener) {

    isolated remote function onRegisterTopic(foo:TopicRegistration message)
                                returns foo:TopicRegistrationSuccess|foo:TopicRegistrationError {
        if (message.topic == "test") {
            return foo:TOPIC_REGISTRATION_SUCCESS;
        } else {
            return foo:TOPIC_REGISTRATION_ERROR;
        }
    }

    isolated remote function onDeregisterTopic(foo:TopicDeregistration message, http:Request baseRequest)
                        returns foo:TopicDeregistrationSuccess|foo:TopicDeregistrationError {

        map<string> body = { isDeregisterSuccess: "true" };
        foo:TopicDeregistrationSuccess deregisterResult = {
            body
        };
        if (message.topic == "test") {
            return deregisterResult;
       } else {
            return error foo:TopicDeregistrationError("Topic Deregistration Failed!");
        }
    }

    isolated remote function onUpdateMessage(foo:UpdateMessage message)
               returns foo:Acknowledgement|foo:UpdateMessageError {
        return foo:ACKNOWLEDGEMENT;
    }
    
    isolated remote function onSubscription(foo:Subscription msg)
                returns foo:SubscriptionAccepted|foo:SubscriptionPermanentRedirect|foo:SubscriptionTemporaryRedirect
                |foo:BadSubscriptionError|foo:InternalSubscriptionError {
        foo:SubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else if (msg.hubTopic == "test1") {
            return successResult;
        } else {
            return error foo:BadSubscriptionError("Bad subscription");
        }
    }

    isolated remote function onSubscriptionValidation(foo:Subscription msg)
                returns foo:SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error foo:SubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onSubscriptionIntentVerified(foo:VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(foo:Unsubscription msg)
               returns foo:UnsubscriptionAccepted|foo:BadUnsubscriptionError|foo:InternalUnsubscriptionError {
        if (msg.hubTopic == "test" || msg.hubTopic == "test1" ) {
            foo:UnsubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error foo:BadUnsubscriptionError("Denied unsubscription for topic '" + <string> msg.hubTopic + "'");
        }
    }

    isolated remote function onUnsubscriptionValidation(foo:Unsubscription msg)
                returns foo:UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error foo:UnsubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(foo:VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}
