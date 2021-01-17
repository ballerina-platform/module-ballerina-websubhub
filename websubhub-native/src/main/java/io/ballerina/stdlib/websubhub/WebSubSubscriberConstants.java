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

package io.ballerina.stdlib.websubhub;

import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BString;

import static io.ballerina.runtime.api.constants.RuntimeConstants.BALLERINA_BUILTIN_PKG_PREFIX;

/**
 * Constants for WebSubSubscriber Services.
 *
 * @since 0.965.0
 */
public class WebSubSubscriberConstants {

    public static final String BALLERINA = "ballerina";
    public static final String WEBSUB = "websubhub";
    public static final String MODULE_VERSION = "0.1.0";
    public static final Module WEBSUB_PACKAGE_ID = new Module(BALLERINA_BUILTIN_PKG_PREFIX, WEBSUB, MODULE_VERSION);

    public static final String STRUCT_WEBSUB_BALLERINA_HUB = "Hub";
    public static final String STRUCT_WEBSUB_BALLERINA_HUB_STARTED_UP_ERROR = "HubStartedUpError";

    // SubscriptionDetails struct field names
    public static final String SUBSCRIPTION_DETAILS_TOPIC = "topic";
    public static final String SUBSCRIPTION_DETAILS_CALLBACK = "callback";
    public static final String SUBSCRIPTION_DETAILS_SECRET = "secret";
    public static final BString SUBSCRIPTION_DETAILS_LEASE_SECONDS = StringUtils.fromString("leaseSeconds");
    public static final BString SUBSCRIPTION_DETAILS_CREATED_AT = StringUtils.fromString("createdAt");
    public static final String SUBSCRIPTION_DETAILS = "SubscriberDetails";

}
