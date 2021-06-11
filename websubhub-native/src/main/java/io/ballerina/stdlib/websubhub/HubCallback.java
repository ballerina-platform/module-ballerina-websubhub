package io.ballerina.stdlib.websubhub;

import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BString;

import static io.ballerina.runtime.api.utils.StringUtils.fromString;

/**
 * {@code HubCallback} used to handle the websubhub remote method invocation results.
 */
public class HubCallback implements Callback {
    private final Future future;
    private final Module module;

    public HubCallback(Future future, Module module) {
        this.future = future;
        this.module = module;
    }

    @Override
    public void notifySuccess(Object result) {
        if (result instanceof BError) {
            BError error = (BError) result;
            if (!isModuleDefinedError(error)) {
                error.printStackTrace();
            }
        }

        future.complete(result);
    }

    @Override
    public void notifyFailure(BError bError) {
        BString errorMessage = fromString("service method invocation failed: " + bError.getErrorMessage());
        BError invocationError = ErrorCreator.createError(module, "ServiceExecutionError",
                errorMessage, bError, null);
        future.complete(invocationError);
    }

    private boolean isModuleDefinedError(BError error) {
        Type errorType = error.getType();
        String errorName = errorType.getName();
        Module packageDetails = errorType.getPackage();
        String orgName = packageDetails.getOrg();
        String packageName = packageDetails.getName();
        return Constants.MODULE_DEFINED_ERRORS.contains(errorName)
                && Constants.PACKAGE_ORG.equals(orgName) && Constants.PACKAGE_NAME.equals(packageName);
    }
}
