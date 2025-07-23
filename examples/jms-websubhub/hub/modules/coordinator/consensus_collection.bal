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

import ballerina/lang.runtime;
import ballerina/lang.value;
import ballerina/log;
import ballerinax/java.jms;

function startConsensusReceiver() returns error? {
    var [session, consumer] = consensusConnection;
    while true {
        jms:Message? message = check consumer->receive(10000);
        if message is () {
            continue;
        }

        if message !is jms:BytesMessage {
            continue;
        }

        do {
            ConsensusMessage consensus = check value:fromJsonStringWithType(
                    check string:fromBytes(message.content));
            check processConsensus(consensus);
            check session->'commit();
        } on fail error e {
            check session->'rollback();
            return e;
        }
    }
}

isolated function processConsensus(ConsensusMessage consensus) returns error? {
    log:printDebug("[Coordinator] Received consensus message", payload = consensus);
    if consensus is HeartBeat {
        check processHeartbeat(consensus);
    } else if consensus is VoteRequest {
        check processVoteRequest(consensus);
    } else if consensus is VoteResponse {
        check processVoteResponse(consensus);
    }
}

isolated function processHeartbeat(HeartBeat message) returns error? {
    if node.getCurrentTerm() < message.term {
        node.setCurrentTerm(message.term);
        node.resetVotedFor();
    }
    if node.getCurrentTerm() === message.term {
        if node.getLastHbTime() is () {
            setNodeReady(true);
        }
        if node.getNodeId() === message.leaderId {
            return;
        }
        node.setCurrentRole(FOLLOWER);
        node.setCurrentLeader(message.leaderId);
        node.setLastHbTime(message.timestamp);
    }
}

isolated function processVoteRequest(VoteRequest message) returns error? {
    if node.getCurrentTerm() < message.term {
        node.setCurrentTerm(message.term);
        node.setCurrentRole(FOLLOWER);
        node.resetVotedFor();
    }

    string? votedFor = node.getVotedFor();
    if node.getCurrentTerm() === message.term && (votedFor is () || votedFor === message.candidateId) {
        node.setVotedFor(message.candidateId);
        error? result = sendVoteResponse(message.candidateId, message.term, true);
        if result is error {
            log:printError(
                    string `[Coordinator] Error occurred while sending vote response: ${result.message()}`, result);
        }
    } else {
        error? result = sendVoteResponse(message.candidateId, message.term, false);
        if result is error {
            log:printError(
                    string `[Coordinator] Error occurred while sending vote response: ${result.message()}`, result);
        }
    }
}

isolated function processVoteResponse(VoteResponse message) returns error? {
    if node.getCurrentRole() === CANDIDATE {
        if node.getCurrentTerm() === message.term && message.voteGranted {
            node.addVoter(message.voterId);
            if node.getVotesReceived().length() >= getQuorumSize() {
                node.setCurrentRole(LEADER);
                node.setCurrentLeader(node.getNodeId());
                log:printDebug("[Coordinator] Leader elected", leaderId = node.getNodeId());
                _ = start startHeartbeat();
                error? result = invokeStateSync();
                if result is error {
                    log:printError(
                            string `[Coordinator] Error occurred while invoking state-sync once after leader election: ${result.message()}`, result);
                }
            }
        }
    } else if node.getCurrentTerm() < message.term {
        node.setCurrentTerm(message.term);
        node.setCurrentRole(FOLLOWER);
        node.resetVotedFor();
    }
}

isolated function startHeartbeat() {
    while node.getCurrentRole() === LEADER {
        error? result = sendHeartbeat();
        if result is error {
            log:printError(
                    string `[Coordinator] Error occurred while sending heartbeat: ${result.message()}`, result);
        }
        runtime:sleep(heartbeatTimeout);
    }
}
