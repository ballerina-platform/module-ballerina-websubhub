// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
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

import jmshub.common;

import ballerina/log;

import wso2/mi;

@mi:Operation
public function initHubState(json initialState) {
    do {
        common:SystemStateSnapshot systemStateSnapshot = check initialState.fromJsonWithType();
        check processWebsubTopicsSnapshotState(systemStateSnapshot.topics);
        check processWebsubSubscriptionsSnapshotState(systemStateSnapshot.subscriptions);
        // Start hub-state update worker
        _ = start updateHubState();
        log:printInfo("Websubhub service started successfully");
    } on fail error err {
        common:logError("Error occurred while initializing the hub-state using the latest state-snapshot", err, severity = "FATAL");
    }
}
