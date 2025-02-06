// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/log;
import ballerina/http;
import ballerina/websubhub;
import ballerina/lang.runtime;
import ballerina/os;
import kafkaHub.config;

public function main() returns error? {    
    // Initialize the Hub
    check initializeHubState();

    int hubPort = check getHubPort();
    // Start the HealthCheck Service
    http:Listener httpListener = check new (hubPort, 
        secureSocket = {
            key: {
                path: config:SSL_KEYSTORE_PATH,
                password: config:KEYSTORE_PASSWORD
            }
        }
    );
    runtime:registerListener(httpListener);
    check httpListener.attach(healthCheckService, "/health");

    // Start the Hub
    websubhub:Listener hubListener = check new (httpListener);
    runtime:registerListener(hubListener);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
    log:printInfo("Websubhub service started successfully");
}

isolated function getHubPort() returns int|error {
    string hubPort = os:getEnv("HUB_PORT");
    if hubPort == "" {
        return config:HUB_PORT;
    }
    return int:fromString(hubPort);
}
