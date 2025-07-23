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

isolated class Node {
    private final string nodeId;
    private int currentTerm = 0;
    private Role currentRole = FOLLOWER;
    private string[] votesReceived = [];
    private string? currentLeader = ();
    private string? votedFor = ();
    private time:Utc? lastHbTime = ();

    isolated function init(string nodeId) {
        self.nodeId = nodeId;
    }

    isolated function getNodeId() returns string {
        lock {
            return self.nodeId;
        }
    }

    isolated function setCurrentTerm(int term) {
        lock {
            self.currentTerm = term;
        }
    }

    isolated function getCurrentTerm() returns int {
        lock {
            return self.currentTerm;
        }
    }

    isolated function setCurrentRole(Role role) {
        lock {
            self.currentRole = role;
        }
    }

    isolated function getCurrentRole() returns Role {
        lock {
            return self.currentRole;
        }
    }

    isolated function addVoter(string voterId) {
        lock {
            int? idx = self.votesReceived.indexOf(voterId);
            if idx is () {
                self.votesReceived.push(voterId);
            }
        }
    }

    isolated function getVotesReceived() returns string[] {
        lock {
            return self.votesReceived.cloneReadOnly();
        }
    }

    isolated function setCurrentLeader(string leaderId) {
        lock {
            self.currentLeader = leaderId;
        }
    }

    isolated function getCurrentLeader() returns string? {
        lock {
            return self.currentLeader;
        }
    }

    isolated function setVotedFor(string candidateId) {
        lock {
            self.votedFor = candidateId;
        }
    }

    isolated function getVotedFor() returns string? {
        lock {
            return self.votedFor;
        }
    }

    isolated function setLastHbTime(time:Utc timestamp) {
        lock {
            self.lastHbTime = timestamp;
        }
    }

    isolated function getLastHbTime() returns time:Utc? {
        lock {
            return self.lastHbTime;
        }
    }

    isolated function resetElectionInfo() {
        lock {
            self.votesReceived = [];
        }
        lock {
            self.currentLeader = ();
        }
        self.resetVotedFor();
    }

    isolated function resetVotedFor() {
        lock {
            self.votedFor = ();
        }
    }
}
