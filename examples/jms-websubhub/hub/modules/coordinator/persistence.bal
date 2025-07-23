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

import ballerina/time;
import ballerinax/java.jms;

isolated function sendVoteRequest() returns error? {
    VoteRequest voteRequest = {
        candidateId: node.getNodeId(),
        term: node.getCurrentTerm()
    };
    return sendConsensus(voteRequest);
}

isolated function sendVoteResponse(string candidateId, int term, boolean voteGranted) returns error? {
    VoteResponse voteResponse = {
        voterId: node.getNodeId(),
        candidateId,
        term,
        voteGranted
    };
    return sendConsensus(voteResponse);
}

isolated function sendHeartbeat() returns error? {
    HeartBeat heartbeat = {
        leaderId: node.getNodeId(),
        term: node.getCurrentTerm()
    };
    return sendConsensus(heartbeat);
}

isolated function sendConsensus(ConsensusMessage message) returns error? {
    jms:BytesMessage jmsMessage = {
        content: message.toJsonString().toBytes()
    };
    return producer->sendTo({'type: jms:TOPIC, name: "__consensus"}, jmsMessage);
}

isolated function sendNodeInfo(NodeInfo? nodeInfo = ()) returns error? {
    NodeInfo message = nodeInfo ?: {nodeId: node.getNodeId(), timestamp: time:utcNow()};
    jms:BytesMessage jmsMessage = {
        content: message.toJsonString().toBytes()
    };
    return producer->sendTo({'type: jms:TOPIC, name: "__discovery"}, jmsMessage);
}
