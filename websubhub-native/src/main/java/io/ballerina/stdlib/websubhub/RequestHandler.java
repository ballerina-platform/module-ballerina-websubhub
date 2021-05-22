package io.ballerina.stdlib.websubhub;

import io.ballerina.runtime.api.values.BObject;

/**
 * {@code RequestHandler} is a wrapper object used for service method execution.
 */
public class RequestHandler {
    public static void attachService(BObject serviceObj, BObject handlerObj) {
        handlerObj.addNativeData("WEBSUBHUB_SERVICE_OBJECT", serviceObj);
    }
}
