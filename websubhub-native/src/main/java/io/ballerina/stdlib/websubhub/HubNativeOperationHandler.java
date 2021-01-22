/*
 * Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.websubhub;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.async.StrandMetadata;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.util.ArrayList;
import java.util.concurrent.CountDownLatch;

public class HubNativeOperationHandler {

    public static BArray getServiceMethodNames(BObject bHubService) {
        ArrayList<BString> methodNamesList = new ArrayList<>();
        for (MethodType method : bHubService.getType().getMethods()) {
            methodNamesList.add(StringUtils.fromString(method.getName()));
        }
        return ValueCreator.createArrayValue(methodNamesList.toArray(BString[]::new));
    }

    public static Object callRegisterMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callRegisterMethod", "onRegisterTopic");
    }

    public static Object callDeregisterMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callDeregisterMethod", "onDeregisterTopic");
    }

    public static Object callOnUpdateMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callOnUpdateMethod", "onUpdateMessage");
    }

    public static Object callOnSubscriptionMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callOnSubscriptionMethod", "onSubscription");
    }

    public static Object callOnSubscriptionValidationMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callOnSubscriptionValidationMethod", "onSubscriptionValidation");
    }

    public static void callOnSubscriptionIntentVerifiedMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        invokeRemoteFunction(env, bHubService, message, "callOnSubscriptionIntentVerifiedMethod", "onSubscriptionIntentVerified");
    }

    public static Object callOnUnsubscriptionMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callOnUnsubscriptionMethod", "onUnsubscription");
    }

    public static Object callOnUnsubscriptionValidationMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        return invokeRemoteFunction(env, bHubService, message, "callOnUnsubscriptionValidationMethod", "onUnsubscriptionValidation");
    }

    public static void callOnUnsubscriptionIntentVerifiedMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {
        invokeRemoteFunction(env, bHubService, message, "callOnUnsubscriptionIntentVerifiedMethod", "onUnsubscriptionIntentVerified");
    }

    private static Object invokeRemoteFunction(Environment env, BObject bHubService, BMap<BString, Object> message,
                                String parentFunctionName, String remoteFunctionName) {
        Module module = ModuleUtils.getModule();
        StrandMetadata metadata = new StrandMetadata(module.getOrg(), module.getName(), module.getVersion(),
                parentFunctionName);
        CountDownLatch latch = new CountDownLatch(1);
        CallableUnitCallback callback = new CallableUnitCallback(latch);

        Object[] args = new Object[]{message, true};
        env.getRuntime().invokeMethodAsync(bHubService, remoteFunctionName, null, metadata, callback, args);

        try {
            latch.await();
        } catch (InterruptedException e) {
            // Ignore
        }
        return callback.getResult();
    }

}
