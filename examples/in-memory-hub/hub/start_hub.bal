// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/websubhub;
import in_memory_hub.dispatcher;

configurable int HUB_PORT = 9090;

public function main() returns error? {
    // Initialize the Hub
    _ = @strand {thread: "any"} start dispatcher:syncDispatcherState();

    websubhub:Listener hubListener = check new (9090);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}
