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

import ballerina/java;

isolated function callRegisterMethod(HubService hubService, TopicRegistration msg)
returns TopicRegistrationSuccess|TopicRegistrationError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callUnregisterMethod(HubService hubService, TopicUnregistration msg)
returns TopicUnregistrationSuccess|TopicUnregistrationError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUpdateMethod(HubService hubService, UpdateMessage msg)
returns Acknowledgement|UpdateMessageError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnSubscriptionMethod(HubService hubService, Subscription msg)
returns SubscriptionAccepted|SubscriptionRedirect|BadSubscriptionError|InternalSubscriptionError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnSubscriptionValidationMethod(HubService hubService, Subscription msg)
returns SubscriptionDeniedError? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnSubscriptionIntentVerifiedMethod(HubService hubService, VerifiedSubscription msg) = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUnsubscriptionMethod(HubService hubService, Unsubscription msg)
returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;

isolated function callOnUnsubscriptionIntentVerifiedMethod(HubService hubService, 
                                VerifiedUnsubscription msg) = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
