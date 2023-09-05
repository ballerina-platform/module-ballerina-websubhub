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

isolated boolean startupCompleted = false;

isolated function isStartupCompleted() returns boolean {
    lock {
        return startupCompleted;
    }
}

http:Service healthCheckService = service object {
    resource function get readiness() returns http:Ok|http:ServiceUnavailable {
        if isStartupCompleted() {
            return http:OK;
        }
        return http:SERVICE_UNAVAILABLE;
    }
    
    resource function get liveness() returns http:Ok => http:OK;
};
