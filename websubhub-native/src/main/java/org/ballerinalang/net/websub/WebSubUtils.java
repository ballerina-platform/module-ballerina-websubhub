/*
 *  Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 *  WSO2 Inc. licenses this file to you under the Apache License,
 *  Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

package org.ballerinalang.net.websub;

import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.utils.JsonUtils;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import org.ballerinalang.mime.util.EntityBodyHandler;
import org.ballerinalang.mime.util.MimeConstants;
import org.ballerinalang.mime.util.MimeUtil;
import org.ballerinalang.net.http.HttpConstants;
import org.ballerinalang.net.http.HttpUtil;
import org.ballerinalang.net.transport.message.HttpCarbonMessage;

/**
 * Util class for WebSub.
 */
public class WebSubUtils {

    public static final String WEBSUB_ERROR = "WebSubError";

    /**
     * Create WebSub specific error record with 'WebSubError' as error type ID name.
     *
     * @param errMsg  Actual error message
     * @return Ballerina error value
     */
    public static BError createError(String errMsg) {
        return ErrorCreator.createDistinctError(WEBSUB_ERROR, WebSubSubscriberConstants.WEBSUB_PACKAGE_ID,
                                                 StringUtils.fromString(errMsg));
    }

}
