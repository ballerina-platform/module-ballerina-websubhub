package io.ballerina.stdlib.websubhub;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.async.StrandMetadata;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.util.ArrayList;

import static io.ballerina.runtime.api.utils.StringUtils.fromString;

/**
 * {@code RequestHandler} is a wrapper object used for service method execution.
 */
public class RequestHandler {
    public static void attachService(BObject serviceObj, BObject handlerObj) {
        handlerObj.addNativeData("WEBSUBHUB_SERVICE_OBJECT", serviceObj);
    }

    public static BArray getServiceMethodNames(BObject bHubService) {
        ArrayList<BString> methodNamesList = new ArrayList<>();
        for (MethodType method : bHubService.getType().getMethods()) {
            methodNamesList.add(StringUtils.fromString(method.getName()));
        }
        return ValueCreator.createArrayValue(methodNamesList.toArray(BString[]::new));
    }

    public static Object callRegisterMethod(Environment env, BObject handlerObj,
                                            BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callRegisterMethod", "onRegisterTopic");
    }

    public static Object callDeregisterMethod(Environment env, BObject handlerObj,
                                              BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callDeregisterMethod", "onDeregisterTopic");
    }

    public static Object callOnUpdateMethod(Environment env, BObject handlerObj,
                                            BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callOnUpdateMethod", "onUpdateMessage");
    }

    public static Object callOnSubscriptionMethod(Environment env, BObject handlerObj,
                                                  BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callOnSubscriptionMethod", "onSubscription");
    }

    public static Object callOnSubscriptionValidationMethod(Environment env, BObject handlerObj,
                                                            BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callOnSubscriptionValidationMethod", "onSubscriptionValidation");
    }

    public static Object callOnSubscriptionIntentVerifiedMethod(Environment env, BObject handlerObj,
                                                                BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callOnSubscriptionIntentVerifiedMethod",
                "onSubscriptionIntentVerified");
    }

    public static Object callOnUnsubscriptionMethod(Environment env, BObject handlerObj,
                                                    BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args,
                "callOnUnsubscriptionMethod", "onUnsubscription");
    }

    public static Object callOnUnsubscriptionValidationMethod(Environment env, BObject handlerObj,
                                                              BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args, "callOnUnsubscriptionValidationMethod",
                "onUnsubscriptionValidation");
    }

    public static Object callOnUnsubscriptionIntentVerifiedMethod(Environment env, BObject handlerObj,
                                                                  BMap<BString, Object> message, BObject bHttpHeaders) {
        BObject bHubService = (BObject) handlerObj.getNativeData("WEBSUBHUB_SERVICE_OBJECT");
        Object[] args = new Object[]{message, true, bHttpHeaders, true};
        return invokeRemoteFunction(env, bHubService, args, "callOnUnsubscriptionIntentVerifiedMethod",
                "onUnsubscriptionIntentVerified");
    }

    private static Object invokeRemoteFunction(Environment env, BObject bHubService, Object[] args,
                                               String parentFunctionName, String remoteFunctionName) {
        Future balFuture = env.markAsync();
        Module module = ModuleUtils.getModule();
        StrandMetadata metadata = new StrandMetadata(module.getOrg(), module.getName(), module.getVersion(),
                parentFunctionName);
        env.getRuntime().invokeMethodAsync(bHubService, remoteFunctionName, null, metadata, new Callback() {
            @Override
            public void notifySuccess(Object result) {
                balFuture.complete(result);
            }

            @Override
            public void notifyFailure(BError bError) {
                BString errorMessage = fromString("service method invocation failed: " + bError.getErrorMessage());
                BError invocationError = ErrorCreator.createError(module, "ServiceExecutionError",
                        errorMessage, bError, null);
                balFuture.complete(invocationError);
            }
        }, args);
        return null;
    }
}
