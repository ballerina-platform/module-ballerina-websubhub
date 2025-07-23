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
import jmshub.config;

import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;

final decimal heartbeatTimeout = 5;
final decimal electionWaitingInterval = config:nodeCoordinationConfig.leaderHeartbeatTimeout + common:generateRandomDecimal(1, 5);

isolated function startElection() returns error? {
    while true {
        if node.getCurrentRole() !== FOLLOWER {
            continue;
        }
        runtime:sleep(electionWaitingInterval);
        time:Utc? lastHeartbeatTime = node.getLastHbTime();
        if lastHeartbeatTime is time:Utc {
            decimal diff = time:utcDiffSeconds(time:utcNow(), lastHeartbeatTime);
            if diff < config:nodeCoordinationConfig.leaderHeartbeatTimeout {
                continue;
            }
        }

        log:printDebug("[Coordinator] Heartbeat timeout expired, hence starting an election", candidate = node.getNodeId());
        node.setCurrentTerm(node.getCurrentTerm() + 1);
        node.setCurrentRole(CANDIDATE);
        node.setVotedFor(node.getNodeId());
        node.addVoter(node.getNodeId());

        error? result = sendVoteRequest();
        if result is error {
            log:printError(
                    string `[Coordinator] Error occurred while sending election message: ${result.message()}`, result);
            return result;
        }
    }
}
