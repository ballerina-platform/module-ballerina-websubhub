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

    String NATIVE_HUB_SERVICE = "NATIVE_HUB_SERVICE";

    String ON_REGISTER_TOPIC = "onRegisterTopic";
    String ON_DEREGISTER_TOPIC = "onDeregisterTopic";
    String ON_UPDATE_MESSAGE = "onUpdateMessage";
    String ON_SUBSCRIPTION = "onSubscription";
    String ON_SUBSCRIPTION_VALIDATION = "onSubscriptionValidation";
    String ON_SUBSCRIPTION_INTENT_VERIFIED = "onSubscriptionIntentVerified";
    String ON_UNSUBSCRIPTION = "onUnsubscription";
    String ON_UNSUBSCRIPTION_VALIDATION = "onUnsubscriptionValidation";
    String ON_UNSUBSCRIPTION_INTENT_VERIFIED = "onUnsubscriptionIntentVerified";

    String HTTP_HEADERS_TYPE = "http:Headers";
    String WEBSUBHUB_CONTROLLER_TYPE = "websubhub:Controller";

    String COMMON_RESPONSE = "CommonResponse";
    String STATUS_CODE = "statusCode";
    String SERVICE_EXECUTION_ERROR = "ServiceExecutionError";
    int PANIC_FROM_THE_SERVICE_ERROR = -6;
}
