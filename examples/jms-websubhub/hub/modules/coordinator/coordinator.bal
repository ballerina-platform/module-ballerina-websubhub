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

import jmshub.config;

import ballerina/lang.runtime;
import ballerina/log;

final Node node = new (config:serverId);
isolated boolean nodeReady = false;
isolated SystemStateSync? stateSyncCallback = ();

isolated function setNodeReady(boolean ready) {
    lock {
        nodeReady = ready;
    }
}

public isolated function isNodeReady() returns boolean {
    lock {
        return nodeReady;
    }
}

public isolated function isLeader() returns boolean {
    lock {
        return node.getCurrentRole() === LEADER;
    }
}

public function initCoordinator(SystemStateSync stateSync) returns error? {
    log:printInfo("[Coordinator] Node is starting", nodeId = node.getNodeId());
    lock {
        stateSyncCallback = stateSync;
    }

    check sendNodeInfo();
    _ = start startNodeDiscovery();
    // wait for a small amount of time to give other nodes to join the consensus collection
    runtime:sleep(5);

    _ = start startConsensusReceiver();
    _ = start startElection();
}

isolated function invokeStateSync() returns error? {
    SystemStateSync? stateSync = ();
    lock {
        stateSync = stateSyncCallback;
    }
    if stateSync is () {
        return;
    }
    return stateSync();
}
