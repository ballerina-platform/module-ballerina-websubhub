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

enum Role {
    FOLLOWER, CANDIDATE, LEADER
};

type ConsensusMessage HeartBeat|VoteRequest|VoteResponse;

type HeartBeat record {|
    string 'type = "HeartBeat";
    string leaderId;
    int term;
    time:Utc timestamp = time:utcNow();
|};

type VoteRequest record {|
    string 'type = "VoteRequest";
    string candidateId;
    int term;
|};

type VoteResponse record {|
    string 'type = "VoteResponse";
    string voterId;
    string candidateId;
    int term;
    boolean voteGranted;
|};

type NodeInfo record {|
    string 'type = "NodeInfo";
    readonly string nodeId;
    time:Utc timestamp;
|};

type SystemStateSync isolated function () returns error?;
