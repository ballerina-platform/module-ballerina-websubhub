// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;

listener http:Listener lbListener = check new (LB_PORT,
    secureSocket = {
        key: {
            certFile: "./resources/server.crt",
            keyFile: "./resources/server.key"
        }
    }
);

service /hub on lbListener {
    private final http:LoadBalanceClient loadBalanceClient;

    function init() returns error? {
        self.loadBalanceClient = check new ({
            targets: LB_TARGETS,
            timeout: CLIENT_TIMEOUT
        });
    }

    resource function 'default .(http:Request request) returns http:Response|error {
        return self.loadBalanceClient->forward(request.rawPath, request);
    }
}
