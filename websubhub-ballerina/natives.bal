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
import ballerina/jballerina.java;

isolated function callRegisterMethod(Service hubService, TopicRegistration msg, http:Headers headers)
returns TopicRegistrationSuccess|TopicRegistrationError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callDeregisterMethod(Service hubService, TopicDeregistration msg, http:Headers headers)
returns TopicDeregistrationSuccess|TopicDeregistrationError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUpdateMethod(Service hubService, UpdateMessage msg, http:Headers headers)
returns Acknowledgement|UpdateMessageError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnSubscriptionMethod(Service hubService, Subscription msg, http:Headers headers) returns SubscriptionAccepted|
    SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect|BadSubscriptionError|InternalSubscriptionError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnSubscriptionValidationMethod(Service hubService, Subscription msg, http:Headers headers)
returns SubscriptionDeniedError? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnSubscriptionIntentVerifiedMethod(Service hubService, VerifiedSubscription msg, http:Headers headers) = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUnsubscriptionMethod(Service hubService, Unsubscription msg, http:Headers headers)
returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUnsubscriptionValidationMethod(Service hubService, Unsubscription msg, http:Headers headers)
returns UnsubscriptionDeniedError? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUnsubscriptionIntentVerifiedMethod(Service hubService, VerifiedUnsubscription msg, http:Headers headers) = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
