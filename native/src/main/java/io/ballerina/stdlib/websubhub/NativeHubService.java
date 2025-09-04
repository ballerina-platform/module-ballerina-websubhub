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

import io.ballerina.runtime.api.types.RemoteMethodType;
import io.ballerina.runtime.api.types.ServiceType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BObject;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;

/**
 * {@code NativeBHubService} is a Java wrapper for Ballerina `websubhub:Service` object.
 */
public class NativeHubService {
    private final BObject bHubService;
    private final Map<String, List<Type>> methodParameterMapping = new HashMap<>();


    NativeHubService(BObject bHubService) {
        RemoteMethodType[] remoteMethods = ((ServiceType) TypeUtils.getType(bHubService)).getRemoteMethods();
        for (RemoteMethodType remoteMethod: remoteMethods) {
            String methodName = remoteMethod.getName();
            List<Type> paramTypeInOrder = Stream.of(remoteMethod.getParameters()).map(p -> p.type).toList();
            methodParameterMapping.put(methodName, paramTypeInOrder);
        }
        this.bHubService = bHubService;
    }

    public BObject getBHubService() {
        return bHubService;
    }

    public Set<String> getRemoteMethodNames() {
        return methodParameterMapping.keySet();
    }

    public Object[] resolveArgs(String methodName, InteropArgs interopArgs) {
        List<Type> artTypes = methodParameterMapping.getOrDefault(methodName, Collections.emptyList());
        Object[] args = new Object[artTypes.size()];
        for (int i = 0; i < artTypes.size(); i++) {
            args[i] = interopArgs.getMappingArg(artTypes.get(i));
        }
        return args;
    }
}
