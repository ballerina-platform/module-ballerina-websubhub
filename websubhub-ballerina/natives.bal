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

isolated function attachService(Service serviceObj, RequestHandler handlerObj) = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callRegisterMethod(RequestHandler handlerObj, TopicRegistration msg, http:Headers headers)
returns TopicRegistrationSuccess|TopicRegistrationError|error = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callDeregisterMethod(RequestHandler handlerObj, TopicDeregistration msg, http:Headers headers)
returns TopicDeregistrationSuccess|TopicDeregistrationError|error = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnUpdateMethod(RequestHandler handlerObj, UpdateMessage msg, http:Headers headers)
returns Acknowledgement|UpdateMessageError|error = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnSubscriptionMethod(RequestHandler handlerObj, Subscription msg, http:Headers headers) returns SubscriptionAccepted|
    SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect|BadSubscriptionError|InternalSubscriptionError|error = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnSubscriptionValidationMethod(RequestHandler handlerObj, Subscription msg, http:Headers headers)
returns SubscriptionDeniedError|error? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnSubscriptionIntentVerifiedMethod(RequestHandler handlerObj, VerifiedSubscription msg, http:Headers headers) returns error? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnUnsubscriptionMethod(RequestHandler handlerObj, Unsubscription msg, http:Headers headers)
returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError|error = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnUnsubscriptionValidationMethod(RequestHandler handlerObj, Unsubscription msg, http:Headers headers)
returns UnsubscriptionDeniedError|error? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;

isolated function callOnUnsubscriptionIntentVerifiedMethod(RequestHandler handlerObj, VerifiedUnsubscription msg, http:Headers headers) returns error? = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.RequestHandler"
} external;
