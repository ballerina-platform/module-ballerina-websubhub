/*
 * Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.websubhub;

/**
 * {@code Constants} contains the public constants to be used.
 */
public interface Constants {
    String PACKAGE_ORG = "ballerina";
    String PACKAGE_NAME = "websubhub";

    String LISTENER_IDENTIFIER = "Listener";

    String ON_REGISTER_TOPIC = "onRegisterTopic";
    String ON_DEREGISTER_TOPIC = "onDeregisterTopic";
    String ON_UPDATE_MESSAGE = "onUpdateMessage";
    String ON_SUBSCRIPTION = "onSubscription";
    String ON_SUBSCRIPTION_VALIDATION = "onSubscriptionValidation";
    String ON_SUBSCRIPTION_INTENT_VERIFICATION = "onSubscriptionIntentVerified";
    String ON_UNSUBSCRIPTION = "onUnsubscription";
    String ON_UNSUBSCRIPTION_VALIDATION = "onUnsubscriptionValidation";
    String ON_UNSUBSCRIPTION_INTENT_VERIFICATION = "onUnsubscriptionIntentVerified";

    String TOPIC_REGISTRATION = "websubhub:TopicRegistration";
    String TOPIC_DEREGISTRATION = "websubhub:TopicDeregistration";
    String UPDATE_MESSAGE = "websubhub:UpdateMessage";
    String SUBSCRIPTION = "websubhub:Subscription";
    String VERIFIED_SUBSCRIPTION = "websubhub:VerifiedSubscription";
    String UNSUBSCRIPTION = "websubhub:Unsubscription";
    String VERIFIED_UNSUBSCRIPTION = "websubhub:VerifiedUnsubscription";
    String BASE_REQUEST = "http:Request";
    String TOPIC_REGISTRATION_SUCCESS = "websubhub:TopicRegistrationSuccess";
    String TOPIC_REGISTRATION_ERROR = "websubhub:TopicRegistrationError";
    String TOPIC_DEREGISTRATION_SUCCESS = "websubhub:TopicDeregistrationSuccess";
    String TOPIC_DEREGISTRATION_ERROR = "websubhub:TopicDeregistrationError";
    String UPDATE_MESSAGE_ERROR = "websubhub:UpdateMessageError";
    String SUBSCRIPTION_ACCEPTED = "websubhub:SubscriptionAccepted";
    String SUBSCRIPTION_PERMANENT_REDIRECT = "websubhub:SubscriptionPermanentRedirect";
    String SUBSCRIPTION_TEMP_REDIRECT = "websubhub:SubscriptionTemporaryRedirect";
    String BAD_SUBSCRIPTION_ERROR = "websubhub:BadSubscriptionError";
    String SUBSCRIPTION_INTERNAL_ERROR = "websubhub:InternalSubscriptionError";
    String SUBSCRIPTION_DENIED_ERROR = "websubhub:SubscriptionDeniedError";
    String UNSUBSCRIPTION_ACCEPTED = "websubhub:UnsubscriptionAccepted";
    String BAD_UNSUBSCRIPTION = "websubhub:BadUnsubscriptionError";
    String UNSUBSCRIPTION_INTERNAL_ERROR = "websubhub:InternalUnsubscriptionError";
    String UNSUBSCRIPTION_DENIED_ERROR = "websubhub:UnsubscriptionDeniedError";
    String ACKNOWLEDGEMENT = "websubhub:Acknowledgement";
    String ERROR = "annotations:error";

    String OPTIONAL = "?";
}
