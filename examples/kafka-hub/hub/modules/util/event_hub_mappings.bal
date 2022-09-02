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

// todo: find a way to persist removed assignments
isolated types:EventHubPartition[] removedPartitionAssignments = [];
isolated types:EventHubPartition|int nextPartition = {
    eventHub: config:EVENT_HUBS[0],
    partition: 0
};

# Retrieves the next available partition mapping.
# 
# + return - Returns partition mapping if available or else `error`
public isolated function getNextPartition() returns types:EventHubPartition|error {
    lock {
        if removedPartitionAssignments.length() >= 1 {
            return removedPartitionAssignments.pop().cloneReadOnly();
        }
    }
    lock {
        if nextPartition is types:EventHubPartition {
            types:EventHubPartition currentPointer = check value:ensureType(nextPartition);
            readonly & types:EventHubPartition nextPointer = check value:ensureType(nextPartition);
            nextPartition = check retrieveNextEventHubPartitionPointer(nextPointer);
            return currentPointer.cloneReadOnly();
        }
        return error("Could not find a valid partition");
    }
}

isolated function retrieveNextEventHubPartitionPointer(types:EventHubPartition eventHubPartition) returns types:EventHubPartition|int|error {
    string currentEventHub = eventHubPartition.eventHub;
    int currentPartitionId = eventHubPartition.partition;
    if currentPartitionId >= config:NUMBER_OF_PARTITIONS - 1 {
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
        // if there is no event-hub partition entry available, return `-1`
        if currentEventHubIdx == config:EVENT_HUBS.length() - 1 {
            return -1;
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
        if nextPartition is int {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
        }
        types:EventHubPartition nextPointer = check value:ensureType(nextPartition);
        string currentEventHub = nextPointer.eventHub;
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
        if eventHubIdx > currentEventHubIdx {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
            return;
        }
        if eventHubIdx == currentEventHubIdx && partitionDetails.partition > nextPointer.partition {
            nextPartition = check retrieveNextEventHubPartitionPointer(partitionDetails);
        }
    }
}

# Updates the removed partition assignments.
#
# + removedAssignment - Removed partition assignment
public isolated function removePartitionAssignment(types:EventHubPartition removedAssignment) {
    lock {
        removedPartitionAssignments.push(removedAssignment.cloneReadOnly());
    }
}

// todo: find a way to persist removed assignments
isolated map<types:EventHubConsumerGroup[]> removedConsumerGroupAssignments = {};
isolated map<types:EventHubConsumerGroup|int> nextConsumerGroupAssignment = initConsumerGroupAssignment();

isolated function initConsumerGroupAssignment() returns map<types:EventHubConsumerGroup> {
    map<types:EventHubConsumerGroup> assignments = {};
    foreach string eventHub in config:EVENT_HUBS {
        foreach int partitionId in 0..<config:NUMBER_OF_PARTITIONS {
            string eventHubPartitionId = string `${eventHub}_${partitionId}`;
            assignments[eventHubPartitionId] = {
                eventHub: eventHub,
                partition: partitionId,
                consumerGroup: config:CONSUMER_GROUPS[0]
            };
        }
    }
    return assignments;
}

# Retrieves the next available consumer-group mapping for partition in an event hub.
#
# + eventHubPartition - Requested partition details
# + return - Returns available consumer-group mapping if there is any available mapping or else `error`
public isolated function getNextConsumerGroup(types:EventHubPartition eventHubPartition) returns types:EventHubConsumerGroup|error {
    string partitionAssignmentKey = string `${eventHubPartition.eventHub}_${eventHubPartition.partition}`;
    lock {
        if removedConsumerGroupAssignments.hasKey(partitionAssignmentKey) {
            types:EventHubConsumerGroup[] availablePartitions = removedConsumerGroupAssignments.get(partitionAssignmentKey);
            return availablePartitions.pop().cloneReadOnly();
        }
    }
    lock {
        types:EventHubConsumerGroup|int currentConsumerGroup = nextConsumerGroupAssignment.get(partitionAssignmentKey);
        if currentConsumerGroup is int {
            return error ("Could not find a valid consumer-group");
        }
        nextConsumerGroupAssignment[partitionAssignmentKey] = check retrieveNextConsumerGroupPointer(currentConsumerGroup);
        return currentConsumerGroup.cloneReadOnly();
    }
}

isolated function retrieveNextConsumerGroupPointer(types:EventHubConsumerGroup consumerGroup) returns types:EventHubConsumerGroup|int|error {
    int currentConsumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(consumerGroup.consumerGroup));
    // if there is no consumer-group entry available, return `-1`
    if currentConsumerGroupIdx >= config:CONSUMER_GROUPS.length() - 1 {
        return -1;
    }
    string nextConsumerGroup = config:CONSUMER_GROUPS[currentConsumerGroupIdx + 1];
    return {
        eventHub: consumerGroup.eventHub,
        partition: consumerGroup.partition,
        consumerGroup: nextConsumerGroup
    };
}

# Updates the next available consumer-group mapping for a event-hub partition.
#
# + consumerGroup - Provided consumer-group mapping
# + return - Returns `error` if there is any exception while updating the information
public isolated function updateNextConsumerGroup(readonly & types:EventHubConsumerGroup consumerGroup) returns error? {
    string partitionAssignmentKey = string `${consumerGroup.eventHub}_${consumerGroup.partition}`;
    int consumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(consumerGroup.consumerGroup));
    lock {
        types:EventHubConsumerGroup|int currentConsumerGroup = nextConsumerGroupAssignment.get(partitionAssignmentKey);
        if currentConsumerGroup is int {
            nextConsumerGroupAssignment[partitionAssignmentKey] = check retrieveNextConsumerGroupPointer(consumerGroup);
            return;
        }
        int currentConsumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(currentConsumerGroup.consumerGroup));
        if currentConsumerGroupIdx < consumerGroupIdx {
            nextConsumerGroupAssignment[partitionAssignmentKey] = check retrieveNextConsumerGroupPointer(consumerGroup);
            return;
        }
    }
}

# Updates the removed partition assignments.
#
# + consumerGroup - Removed consumer-group assignment
public isolated function removeConsumerGroupAssignment(readonly & types:EventHubConsumerGroup consumerGroup) {
    string partitionAssignmentKey = string `${consumerGroup.eventHub}_${consumerGroup.partition}`;
    lock {
        if removedConsumerGroupAssignments.hasKey(partitionAssignmentKey) {
            removedConsumerGroupAssignments.get(partitionAssignmentKey).push(consumerGroup);
            return;
        }
        types:EventHubConsumerGroup[] consumerGroups = [consumerGroup];
        removedConsumerGroupAssignments[partitionAssignmentKey] = consumerGroups;
    }
}