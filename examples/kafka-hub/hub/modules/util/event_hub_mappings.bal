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

isolated types:EventHubPartition[] removedPartitionAssignments = [];
isolated types:EventHubPartition nextPartition = {
    eventHub: config:EVENT_HUBS[0],
    partition: 0
};

# Retrieves the next available partition mapping.
# 
# + return - Return available partition mapping if the action is successfull or else `error`
public isolated function getNextPartition() returns types:EventHubPartition|error {
    lock {
        if removedPartitionAssignments.length() >= 1 {
            return removedPartitionAssignments.pop().cloneReadOnly();
        }
    }
    lock {
        types:EventHubPartition currentPartition = nextPartition;
        // if the next partition is greater than or equal to the last available partition, 
        // update counter to next event-hub
        if nextPartition.partition >= config:NUMBER_OF_PARTITIONS - 1 {
            string currentEventHub = nextPartition.eventHub;
            int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
            if currentEventHubIdx == config:EVENT_HUBS.length() - 1 {
                return error("Could not find a valid partition");
            }
            string nextEventHub = config:EVENT_HUBS[currentEventHubIdx + 1];
            nextPartition = {
                eventHub: nextEventHub,
                partition: 0
            };
        } else {
            nextPartition.partition += 1; 
        }
        return currentPartition.cloneReadOnly();
    }
}

# Updates the next available partition mapping.
#
# + partitionDetails - Provided partition mapping
# + return - Returns `error` if the action fails
public isolated function updateNextPartition(types:EventHubPartition partitionDetails) returns error? {
    string eventHub = partitionDetails.eventHub;
    int partition = partitionDetails.partition;
    int eventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(partitionDetails.eventHub));
    lock {
        string currentEventHub = nextPartition.eventHub;
        int currentEventHubIdx = check value:ensureType(config:EVENT_HUBS.indexOf(currentEventHub));
        if eventHubIdx > currentEventHubIdx {
            nextPartition = {
                eventHub: eventHub,
                partition: partition
            };
        } else if eventHubIdx == currentEventHubIdx {
            int currentPartition = nextPartition.partition;
            int nextPartitionIdx = partition > currentPartition? partition: currentPartition;
            nextPartition = {
                eventHub: eventHub,
                partition: nextPartitionIdx
            };
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

isolated map<types:EventHubConsumerGroup[]> removedConsumerGroupAssignments = {};
isolated map<types:EventHubConsumerGroup> nextConsumerGroupAssignment = initConsumerGroupAssignment();

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

public isolated function getNextConsumerGroup(types:EventHubPartition eventHubPartition) returns types:EventHubConsumerGroup|error {
    string partitionAssignmentKey = string `${eventHubPartition.eventHub}_${eventHubPartition.partition}`;
    lock {
        if removedConsumerGroupAssignments.hasKey(partitionAssignmentKey) {
            types:EventHubConsumerGroup[] availablePartitions = removedConsumerGroupAssignments.get(partitionAssignmentKey);
            return availablePartitions.pop().cloneReadOnly();
        }
    }
    lock {
        types:EventHubConsumerGroup nextConsumerGroup = nextConsumerGroupAssignment.get(partitionAssignmentKey);
        int currentConsumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(nextConsumerGroup.consumerGroup));
    }
}

// mapping related to websub-topic -> event-hub + partition
// mapping related to websub-sub -> event-hub + partition + consumer-group
// - how can we revoke the earlier-assigned partitions
// - how can we revoke the earlier-assigned consumer groups
