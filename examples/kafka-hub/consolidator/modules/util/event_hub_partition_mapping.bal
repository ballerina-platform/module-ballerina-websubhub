// Copyright (c) 2022, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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
import consolidatorService.config;
import consolidatorService.types;

isolated types:EventHubPartition[] vacantPartitionAssignments = [];
isolated types:EventHubPartition? nextPartition = {
    namespaceId: config:AVAILABLE_NAMESPACE_IDS[0],
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

# Updates the next available partition mapping.
#
# + partitionDetails - Provided partition mapping
# + return - Returns `error` if there is an exception while updating the partition information
public isolated function updateNextPartition(readonly & types:EventHubPartition partitionDetails) returns error? {
    int namespaceIdx = check value:ensureType(config:AVAILABLE_NAMESPACE_IDS.indexOf(partitionDetails.namespaceId));
    int eventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(partitionDetails.eventHub));
    lock {
        if nextPartition is () {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        types:EventHubPartition nextPointer = check value:ensureType(nextPartition);
        int currentNamespaceIdx = check value:ensureType(config:AVAILABLE_NAMESPACE_IDS.indexOf(nextPointer.namespaceId));
        if namespaceIdx > currentNamespaceIdx {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(nextPointer.eventHub));
        if eventHubIdx > currentEventHubIdx {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        if namespaceIdx == currentNamespaceIdx && eventHubIdx >= currentEventHubIdx {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        int partition = partitionDetails.partition;
        if namespaceIdx == currentNamespaceIdx && eventHubIdx == currentEventHubIdx && partition >= nextPointer.partition {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
    }
}

isolated function retrieveNextEventHubPartitionPointer(readonly & types:EventHubPartition eventHubPartition) returns types:EventHubPartition|error? {
    string currentNamespace = eventHubPartition.namespaceId;
    string currentEventHub = eventHubPartition.eventHub;
    int currentPartitionId = eventHubPartition.partition;
    // check whether current partition number is greater than the last partition number
    if currentPartitionId >= config:NUMBER_OF_PARTITIONS - 1 {
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
        // if the current event-hub is not the last event-hub for the current namespace, use the next event-hub
        if currentEventHubIdx < config:EVENT_HUBS.length() - 1 {
            string nextEventHub = config:EVENT_HUBS[currentEventHubIdx + 1];
            return {
                namespaceId: currentNamespace,
                eventHub: nextEventHub,
                partition: 0
            };
        }
        int currentNamespaceIdx = check value:ensureType(config:AVAILABLE_NAMESPACE_IDS.indexOf(currentNamespace));
        // if there is no namespace entry available, return `nil`
        if currentNamespaceIdx >= config:AVAILABLE_NAMESPACE_IDS.length() - 1 {
            return;
        } 
        // if there are available namespace entries, use the next available namespace
        string nextNamespace = config:AVAILABLE_NAMESPACE_IDS[currentNamespaceIdx + 1];
        return {
            namespaceId: nextNamespace,
            eventHub: config:EVENT_HUBS[0],
            partition: 0
        };
    } else {
        // if the partition number is lesser than the last partition number, use the next partition
        return {
            namespaceId: currentNamespace,
            eventHub: currentEventHub,
            partition: currentPartitionId + 1
        };
    }
}

# Updates the removed partition assignments.
#
# + removedAssignment - Removed partition assignment
public isolated function updateVacantPartitionAssignment(readonly & types:EventHubPartition removedAssignment) {
    lock {
        boolean isPartitionAssignmentUnavailable = vacantPartitionAssignments
            .every(assignment => assignment.eventHub != removedAssignment.eventHub && assignment.partition != removedAssignment.partition);
        if isPartitionAssignmentUnavailable {
            vacantPartitionAssignments.push(removedAssignment);
        }
    }
}
