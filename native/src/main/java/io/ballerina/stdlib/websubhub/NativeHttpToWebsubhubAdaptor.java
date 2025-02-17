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
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.IntersectionType;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.types.ObjectType;
import io.ballerina.runtime.api.types.Parameter;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.util.List;
import java.util.concurrent.CompletableFuture;

import static io.ballerina.stdlib.websubhub.Constants.ON_DEREGISTER_TOPIC;
import static io.ballerina.stdlib.websubhub.Constants.ON_REGISTER_TOPIC;
import static io.ballerina.stdlib.websubhub.Constants.ON_SUBSCRIPTION;
import static io.ballerina.stdlib.websubhub.Constants.ON_SUBSCRIPTION_INTENT_VERIFIED;
import static io.ballerina.stdlib.websubhub.Constants.ON_SUBSCRIPTION_VALIDATION;
import static io.ballerina.stdlib.websubhub.Constants.ON_UNSUBSCRIPTION;
import static io.ballerina.stdlib.websubhub.Constants.ON_UNSUBSCRIPTION_INTENT_VERIFIED;
import static io.ballerina.stdlib.websubhub.Constants.ON_UNSUBSCRIPTION_VALIDATION;
import static io.ballerina.stdlib.websubhub.Constants.ON_UPDATE_MESSAGE;
import static io.ballerina.stdlib.websubhub.Constants.NATIVE_HUB_SERVICE;

/**
 * {@code NativeHttpToWebsubhubAdaptor} is a wrapper object used for service method execution.
 */
public final class NativeHttpToWebsubhubAdaptor {
    private NativeHttpToWebsubhubAdaptor() {}

    public static void externInit(BObject adaptor, BObject serviceObj) {
        adaptor.addNativeData(NATIVE_HUB_SERVICE, new NativeHubService(serviceObj));
    }

    public static BArray getServiceMethodNames(BObject adaptor) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        List<BString> remoteMethodNames = nativeHubService.getRemoteMethodNames().stream()
                .map(StringUtils::fromString).toList();
        return ValueCreator.createArrayValue(remoteMethodNames.toArray(BString[]::new));
    }

    public static Object callRegisterMethod(Environment env, BObject adaptor,
                                            BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_REGISTER_TOPIC);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_REGISTER_TOPIC, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callRegisterMethod", ON_REGISTER_TOPIC);
    }

    public static Object callDeregisterMethod(Environment env, BObject adaptor,
                                              BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_DEREGISTER_TOPIC);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_DEREGISTER_TOPIC, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callDeregisterMethod", ON_DEREGISTER_TOPIC);
    }

    public static Object callOnUpdateMethod(Environment env, BObject adaptor,
                                            BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_UPDATE_MESSAGE);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_UPDATE_MESSAGE, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callOnUpdateMethod", ON_UPDATE_MESSAGE);
    }

    public static Object callOnSubscriptionMethod(Environment env, BObject adaptor,
                                                  BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_SUBSCRIPTION);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_SUBSCRIPTION, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callOnSubscriptionMethod", ON_SUBSCRIPTION);
    }

    public static Object callOnSubscriptionValidationMethod(Environment env, BObject adaptor,
                                                            BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_SUBSCRIPTION_VALIDATION);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_SUBSCRIPTION_VALIDATION, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callOnSubscriptionValidationMethod", ON_SUBSCRIPTION_VALIDATION);
    }

    public static Object callOnSubscriptionIntentVerifiedMethod(Environment env, BObject adaptor,
                                                                BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_SUBSCRIPTION_INTENT_VERIFIED);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_SUBSCRIPTION_INTENT_VERIFIED, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callOnSubscriptionIntentVerifiedMethod",
                ON_SUBSCRIPTION_INTENT_VERIFIED);
    }

    public static Object callOnUnsubscriptionMethod(Environment env, BObject adaptor,
                                                    BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_UNSUBSCRIPTION);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_UNSUBSCRIPTION, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args,
                "callOnUnsubscriptionMethod", ON_UNSUBSCRIPTION);
    }

    public static Object callOnUnsubscriptionValidationMethod(Environment env, BObject adaptor,
                                                              BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_UNSUBSCRIPTION_VALIDATION);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_UNSUBSCRIPTION_VALIDATION, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args, "callOnUnsubscriptionValidationMethod",
                ON_UNSUBSCRIPTION_VALIDATION);
    }

    public static Object callOnUnsubscriptionIntentVerifiedMethod(Environment env, BObject adaptor,
                                                                  BMap<BString, Object> message, BObject bHttpHeaders) {
        NativeHubService nativeHubService = (NativeHubService) adaptor.getNativeData(NATIVE_HUB_SERVICE);
        BObject bHubService = nativeHubService.getBHubService();
        boolean isReadOnly = isReadOnlyParam(bHubService, ON_UNSUBSCRIPTION_INTENT_VERIFIED);
        if (isReadOnly) {
            message.freezeDirect();
        }
        Object[] args = nativeHubService.getMethodArgs(ON_UNSUBSCRIPTION_INTENT_VERIFIED, message, bHttpHeaders);
        return invokeRemoteFunction(env, bHubService, args, "callOnUnsubscriptionIntentVerifiedMethod",
                ON_UNSUBSCRIPTION_INTENT_VERIFIED);
    }

    private static boolean isReadOnlyParam(BObject serviceObj, String remoteMethod) {
        ObjectType objectType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(serviceObj));
        for (MethodType method : objectType.getMethods()) {
            if (method.getName().equals(remoteMethod)) {
                Parameter[] parameters = method.getParameters();
                if (parameters.length >= 1) {
                    Parameter parameter = parameters[0];
                    Type paramType = parameter.type;
                    if (paramType instanceof IntersectionType) {
                        List<Type> constituentTypes = ((IntersectionType) paramType).getConstituentTypes();
                        return constituentTypes.stream().anyMatch(t -> TypeTags.READONLY_TAG == t.getTag());
                    }
                }
            }
        }
        return false;
    }

    private static Object invokeRemoteFunction(Environment env, BObject bHubService, Object[] args,
                                               String parentFunctionName, String remoteFunctionName) {
        return env.yieldAndRun(() -> {
            CompletableFuture<Object> balFuture = new CompletableFuture<>();
            Module module = ModuleUtils.getModule();
            ObjectType serviceType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(bHubService));
            try {
                Object result = env.getRuntime().callMethod(bHubService, remoteFunctionName, null, args);
                ModuleUtils.notifySuccess(balFuture, result);
                return ModuleUtils.getResult(balFuture);
            } catch (BError bError) {
                ModuleUtils.notifyFailure(bError);
            }
            return null;
        });
    }
}
