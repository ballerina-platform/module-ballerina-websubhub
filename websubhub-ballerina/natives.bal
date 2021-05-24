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

isolated class HttpToWebsubhubAdaptor {
    isolated function init(Service 'service) returns error? {
        externInit(self, 'service);
    }

    isolated function getServiceMethodNames() returns string[] = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callRegisterMethod(TopicRegistration msg, http:Headers headers)
    returns TopicRegistrationSuccess|TopicRegistrationError|error = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callDeregisterMethod(TopicDeregistration msg, http:Headers headers)
    returns TopicDeregistrationSuccess|TopicDeregistrationError|error = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnUpdateMethod(UpdateMessage msg, http:Headers headers)
    returns Acknowledgement|UpdateMessageError|error = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnSubscriptionMethod(Subscription msg, http:Headers headers) returns SubscriptionAccepted|
        SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect|BadSubscriptionError|InternalSubscriptionError|error = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnSubscriptionValidationMethod(Subscription msg, http:Headers headers)
    returns SubscriptionDeniedError|error? = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnSubscriptionIntentVerifiedMethod(VerifiedSubscription msg, http:Headers headers) returns error? = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnUnsubscriptionMethod(Unsubscription msg, http:Headers headers)
    returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError|error = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnUnsubscriptionValidationMethod(Unsubscription msg, http:Headers headers)
    returns UnsubscriptionDeniedError|error? = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;

    isolated function callOnUnsubscriptionIntentVerifiedMethod(VerifiedUnsubscription msg, http:Headers headers) returns error? = @java:Method {
        'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
    } external;
}

isolated function externInit(HttpToWebsubhubAdaptor adaptor, Service serviceObj) = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.NativeHttpToWebsubhubAdaptor"
} external;
