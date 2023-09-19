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
import ballerina/io;

# The port that is used to start the load-balancer
configurable int LB_PORT = 9090;

# The client timeout
configurable decimal CLIENT_TIMEOUT = 10.0;

# Endpoint configurations related to the load-balancer
configurable string LB_CONFIG_FILE = "./resources/lb-config.json";

http:TargetService[] LB_TARGETS = check getLbTargets();

isolated function getLbTargets() returns http:TargetService[]|error {
    json configs = check io:fileReadJson(LB_CONFIG_FILE);
    return configs.fromJsonWithType();
}
