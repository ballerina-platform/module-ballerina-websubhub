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

import ballerina/lang.value;
import ballerina/log;
import ballerina/time;
import ballerinax/java.jms;

isolated table<NodeInfo> key(nodeId) clusterNodes = table [];

isolated function isClusterNodeAlreadyExist(NodeInfo node) returns boolean {
    NodeInfo? existingNode = ();
    lock {
        existingNode = clusterNodes[node.nodeId].cloneReadOnly();
    }
    if existingNode is () {
        return false;
    }
    if time:utcDiffSeconds(node.timestamp, existingNode.timestamp) > 0d {
        return false;
    }
    return true;
}

isolated function addNode(NodeInfo node) {
    lock {
        clusterNodes.put(node.cloneReadOnly());
    }
}

isolated function getQuorumSize() returns int {
    int numberOfNodes = 0;
    lock {
        numberOfNodes = clusterNodes.length();
    }
    return (numberOfNodes / 2) + 1;
}

isolated function getClusterNodes() returns NodeInfo[] {
    lock {
        return clusterNodes.toArray().cloneReadOnly();
    }
}

function startNodeDiscovery() returns error? {
    var [session, consumer] = nodeDiscoveryConnection;
    while true {
        jms:Message? message = check consumer->receive(10000);
        if message is () {
            continue;
        }

        if message !is jms:BytesMessage {
            continue;
        }

        do {
            NodeInfo nodeInfo = check value:fromJsonStringWithType(check string:fromBytes(message.content));
            processNodeDiscoveryMessage(nodeInfo);
            check session->'commit();
        } on fail error e {
            check session->'rollback();
            return e;
        }
    }
}

isolated function processNodeDiscoveryMessage(NodeInfo nodeInfo) {
    log:printDebug("[Node Discovery] Received NodeInfo message", payload = nodeInfo);
    if isClusterNodeAlreadyExist(nodeInfo) {
        return;
    }
    addNode(nodeInfo);
    if isNodeReady() && isLeader() {
        foreach var node in getClusterNodes() {
            error? result = sendNodeInfo(node);
            if result is error {
                log:printError(
                        string `[Node Discovery] Error occurred while sending cluster node information to a new node: ${result.message()}`, result);
            }
        }
        error? result = invokeStateSync();
        if result is error {
            log:printError(
                    string `[Coordinator] Error occurred while invoking state-sync once after leader election: ${result.message()}`, result);
        }
    }
}
