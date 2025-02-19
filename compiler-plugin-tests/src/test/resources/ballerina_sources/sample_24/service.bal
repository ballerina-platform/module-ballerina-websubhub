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

@websubhub:ServiceConfig {
    autoVerifySubscription: true
}
service /websubhub on new websubhub:Listener(9090) {
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message) 
    returns websubhub:TopicRegistrationSuccess {
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message) 
    returns websubhub:TopicDeregistrationSuccess {
        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    isolated remote function onUpdateMessage(websubhub:UpdateMessage msg) returns websubhub:Acknowledgement {
        return websubhub:ACKNOWLEDGEMENT;
    }
    
    isolated remote function onSubscription(websubhub:Subscription msg, websubhub:Controller hubController) 
    returns websubhub:SubscriptionAccepted|error {
        check hubController.markAsVerified(msg);
        return websubhub:SUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg) {}

    isolated remote function onUnsubscription(websubhub:Unsubscription msg, websubhub:Controller hubController) 
    returns websubhub:UnsubscriptionAccepted|error {
        check hubController.markAsVerified(msg);
        return websubhub:UNSUBSCRIPTION_ACCEPTED;
    }

    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg){}
}
