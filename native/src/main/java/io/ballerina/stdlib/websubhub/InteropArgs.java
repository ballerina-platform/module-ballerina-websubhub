/*
 * Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
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

import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import static io.ballerina.stdlib.websubhub.Constants.HTTP_HEADERS_TYPE;

/**
 * {@code InteropArgs} is a wrapper object which contains the parameters for inter-op calls.
 */
public class InteropArgs {
    private final BMap<BString, Object> message;
    private final BObject httpHeaders;

    InteropArgs(BMap<BString, Object> message, BObject httpHeaders) {
        this.message = message;
        this.httpHeaders = httpHeaders;
    }

    public Object getMappingArg(Type argType) {
        String argTypeName = argType.toString();
        if (HTTP_HEADERS_TYPE.equals(argTypeName)) {
            return httpHeaders;
        }
        return message;
    }
}
