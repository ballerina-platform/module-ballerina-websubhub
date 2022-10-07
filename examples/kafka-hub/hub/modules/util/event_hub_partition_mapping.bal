// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/lang.value;
import kafkaHub.config;
import kafkaHub.types;

isolated types:EventHubPartition[] vacantPartitionAssignments = [];
isolated types:EventHubPartition? nextPartition = {
    eventHub: config:EVENT_HUBS[0],
    partition: 0
};

# Retrieves the next available partition mapping.
# 
# + return - Returns partition mapping if available or else `error`
public isolated function getNextPartition() returns types:EventHubPartition|error {
    lock {
        if vacantPartitionAssignments.length() >= 1 {
            return vacantPartitionAssignments.pop().cloneReadOnly();
        }
    }
    lock {
        if nextPartition is types:EventHubPartition {
            types:EventHubPartition currentPointer = check value:ensureType(nextPartition);
            nextPartition = check retrieveNextEventHubPartitionPointer(currentPointer.cloneReadOnly());
            return currentPointer.cloneReadOnly();
        }
        return error("Could not find a valid partition");
    }
}

isolated function retrieveNextEventHubPartitionPointer(readonly & types:EventHubPartition eventHubPartition) returns types:EventHubPartition|error? {
    string currentEventHub = eventHubPartition.eventHub;
    int currentPartitionId = eventHubPartition.partition;
    if currentPartitionId >= config:NUMBER_OF_PARTITIONS - 1 {
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
        // if there is no event-hub partition entry available, return `-1`
        if currentEventHubIdx == config:EVENT_HUBS.length() - 1 {
            return;
        }
        string nextEventHub = config:EVENT_HUBS[currentEventHubIdx + 1];
        return {
            eventHub: nextEventHub,
            partition: 0
        };
    } else {
        return {
            eventHub: currentEventHub,
            partition: currentPartitionId + 1
        };
    }
}

# Updates the next available partition mapping.
#
# + partitionDetails - Provided partition mapping
# + return - Returns `error` if there is an exception while updating the partition information
public isolated function updateNextPartition(readonly & types:EventHubPartition partitionDetails) returns error? {
    int eventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(partitionDetails.eventHub));
    lock {
        if nextPartition is () {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        types:EventHubPartition nextPointer = check value:ensureType(nextPartition);
        string currentEventHub = nextPointer.eventHub;
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
        if eventHubIdx > currentEventHubIdx {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        if eventHubIdx == currentEventHubIdx && partitionDetails.partition >= nextPointer.partition {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
        }
    }
}

# Updates the removed partition assignments.
#
# + removedAssignment - Removed partition assignment
public isolated function removePartitionAssignment(readonly & types:EventHubPartition removedAssignment) {
    lock {
        boolean isPartitionAssignmentUnavailable = vacantPartitionAssignments
            .every(assignment => assignment.eventHub != removedAssignment.eventHub && assignment.partition != removedAssignment.partition);
        if isPartitionAssignmentUnavailable {
            vacantPartitionAssignments.push(removedAssignment);
        }
    }
}
