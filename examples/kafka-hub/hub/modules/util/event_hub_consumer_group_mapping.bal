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

isolated map<types:EventHubConsumerGroup[]> vacantConsumerGroupAssignments = {};
isolated map<types:EventHubConsumerGroup?> nextConsumerGroupAssignment = initConsumerGroupAssignment();

isolated function initConsumerGroupAssignment() returns map<types:EventHubConsumerGroup?> {
    map<types:EventHubConsumerGroup?> assignments = {};
    foreach string namespaceId in config:AVAILABLE_NAMESPACE_IDS {
        foreach string eventHub in config:EVENT_HUBS {
            foreach int partitionId in 0 ..< config:NUMBER_OF_PARTITIONS {
                string eventHubPartitionId = string `${namespaceId}_${eventHub}_${partitionId}`;
                assignments[eventHubPartitionId] = {
                    namespaceId: namespaceId,
                    eventHub: eventHub,
                    partition: partitionId,
                    consumerGroup: config:CONSUMER_GROUPS[0]
                };
            }
        }
    }
    return assignments;
}

# Returns the availablity of a consumer-group for a given EventHub partition.
#
# + eventHubPartition - EventHub partition for which needs a consumer-group
# + return - Returns `true` if a consumer group is available or else `false`
public isolated function isConsumerGroupAvailable(types:EventHubPartition eventHubPartition) returns boolean {
    string partitionAssignmentKey = string `${eventHubPartition.namespaceId}_${eventHubPartition.eventHub}_${eventHubPartition.partition}`;
    lock {
        if vacantConsumerGroupAssignments.hasKey(partitionAssignmentKey) {
            types:EventHubConsumerGroup[] availableConsumerGroups = vacantConsumerGroupAssignments.get(partitionAssignmentKey);
            if availableConsumerGroups.length() > 0 {
                return true;
            }
        }
    }
    lock {
        types:EventHubConsumerGroup? currentConsumerGroup = nextConsumerGroupAssignment.get(partitionAssignmentKey);
        return currentConsumerGroup is types:EventHubConsumerGroup;
    }
}

# Retrieves the next available consumer-group mapping for partition in an event hub.
#
# + eventHubPartition - Requested partition details
# + return - Returns available consumer-group mapping if there is any available mapping or else `error`
public isolated function getNextConsumerGroup(types:EventHubPartition eventHubPartition) returns types:EventHubConsumerGroup|error {
    string partitionAssignmentKey = string `${eventHubPartition.namespaceId}_${eventHubPartition.eventHub}_${eventHubPartition.partition}`;
    lock {
        if vacantConsumerGroupAssignments.hasKey(partitionAssignmentKey) {
            types:EventHubConsumerGroup[] availableConsumerGroups = vacantConsumerGroupAssignments.get(partitionAssignmentKey);
            if availableConsumerGroups.length() > 0 {
                return availableConsumerGroups.pop().cloneReadOnly();
            }
        }
    }
    lock {
        types:EventHubConsumerGroup? currentConsumerGroup = nextConsumerGroupAssignment.get(partitionAssignmentKey);
        if currentConsumerGroup is () {
            return error ("Could not find a valid consumer-group");
        }
        nextConsumerGroupAssignment[partitionAssignmentKey] = check retrieveNextConsumerGroupPointer(currentConsumerGroup);
        return currentConsumerGroup.cloneReadOnly();
    }
}

isolated function retrieveNextConsumerGroupPointer(types:EventHubConsumerGroup consumerGroup) returns types:EventHubConsumerGroup|error? {
    int currentConsumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(consumerGroup.consumerGroup));
    // if there is no consumer-group entry available, return `nil`
    if currentConsumerGroupIdx >= config:CONSUMER_GROUPS.length() - 1 {
        return;
    }
    string nextConsumerGroup = config:CONSUMER_GROUPS[currentConsumerGroupIdx + 1];
    return {
        namespaceId: consumerGroup.namespaceId,
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
    string partitionAssignmentKey = string `${consumerGroup.namespaceId}_${consumerGroup.eventHub}_${consumerGroup.partition}`;
    int consumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(consumerGroup.consumerGroup));
    lock {
        types:EventHubConsumerGroup? currentConsumerGroup = nextConsumerGroupAssignment.get(partitionAssignmentKey);
        if currentConsumerGroup is () {
            nextConsumerGroupAssignment[partitionAssignmentKey] = check retrieveNextConsumerGroupPointer(consumerGroup);
            return;
        }
        int currentConsumerGroupIdx = check value:ensureType(config:CONSUMER_GROUPS.indexOf(currentConsumerGroup.consumerGroup));
        if currentConsumerGroupIdx <= consumerGroupIdx {
            nextConsumerGroupAssignment[partitionAssignmentKey] = check retrieveNextConsumerGroupPointer(consumerGroup);
            return;
        }
    }
}

# Updates the removed partition assignments.
#
# + consumerGroup - Removed consumer-group assignment
public isolated function removeConsumerGroupAssignment(readonly & types:EventHubConsumerGroup consumerGroup) {
    string partitionAssignmentKey = string `${consumerGroup.namespaceId}_${consumerGroup.eventHub}_${consumerGroup.partition}`;
    lock {
        if vacantConsumerGroupAssignments.hasKey(partitionAssignmentKey) {
            boolean isConsumerGroupMappingUnavailable = vacantConsumerGroupAssignments.get(partitionAssignmentKey)
                        .every(cg => cg.consumerGroup != consumerGroup.consumerGroup);
            if isConsumerGroupMappingUnavailable {
                vacantConsumerGroupAssignments.get(partitionAssignmentKey).push(consumerGroup);
            }
            return;
        }
        types:EventHubConsumerGroup[] consumerGroups = [consumerGroup];
        vacantConsumerGroupAssignments[partitionAssignmentKey] = consumerGroups;
    }
}
