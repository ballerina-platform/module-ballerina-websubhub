// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
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

@websubhub:ServiceConfig {
    autoVerifySubscriptionIntent: true
}
service /websubhub on new websubhub:Listener(9090) {
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message, websubhub:Controller hubController) 
    returns websubhub:TopicRegistrationSuccess {
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message, websubhub:Controller hubController) 
    returns websubhub:TopicDeregistrationSuccess {
        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    isolated remote function onUpdateMessage(websubhub:UpdateMessage msg, websubhub:Controller hubController) returns websubhub:Acknowledgement {
        return websubhub:ACKNOWLEDGEMENT;
    }

    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg, websubhub:Controller hubController) {}
    
    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg, websubhub:Controller hubController){}
}
