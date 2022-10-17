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

import ballerina/log;
import consolidatorService.config;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;
import consolidatorService.types;

const string EVENT_MODE_ADD = "add";

isolated function startEventHubMappingsConsolidator() returns error? {
    do {
        while true {
            types:VacantMappingsConsumerRecord[] records = check conn:eventHubMappingsConsumer->poll(config:POLLING_INTERVAL);
            foreach types:VacantMappingsConsumerRecord currentRecord in records {
                error? result = processPersistedWebSubEventData(currentRecord.value);
                if result is error {
                    log:printError("Error occurred while processing received event-hub mapping event ", 'error = result);
                }
            }
        }
    } on fail var e {
        log:printError("Error occurred while consuming records", 'error = e);
        _ = check conn:eventHubMappingsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        return e;
    }
}

isolated function processPersistedEventHubMappingsData(types:VacantMapping event) returns error? {
    types:EventHubPartition|types:EventHubConsumerGroup mapping = event.mapping;
    if mapping is types:EventHubConsumerGroup {
        _ = check processConsumerGroupMapping(mapping, event.mode);
    } else {
        _ = check processEventHubPartitionMapping(mapping, event.mode);
    }
}

isolated function processConsumerGroupMapping(types:EventHubConsumerGroup payload, string mode) returns error? {
    final string consumerGroupMappingKey = getConsumerGroupMappingKey(payload);
    if mode is EVENT_MODE_ADD {
        lock {
            boolean mappingNotAvailable = vacantEventHubConsumerGroups
                .every(mapping => consumerGroupMappingKey != getConsumerGroupMappingKey(mapping));
            if mappingNotAvailable {
                vacantEventHubConsumerGroups.push(payload.cloneReadOnly());
            }
        }
    } else {
        [int, types:EventHubConsumerGroup][] availableMappings = getAvailableConsumerGroupMappings(consumerGroupMappingKey);
        if availableMappings.length() > 0 {
            [int, types:EventHubConsumerGroup] [idx, _] = availableMappings[0];
            lock {
                _ = vacantEventHubConsumerGroups.remove(idx);
            }   
        }
    }
    lock {
        _ = check persist:persistConsumerGroupMappings(vacantEventHubConsumerGroups);
    }
}

isolated function getAvailableConsumerGroupMappings(string consumerGroupMappingKey) returns [int, types:EventHubConsumerGroup][] {
    lock {
        return vacantEventHubConsumerGroups.enumerate()
            .filter(entry => consumerGroupMappingKey == getConsumerGroupMappingKey(entry[1]))
            .cloneReadOnly();
    }
}

isolated function getConsumerGroupMappingKey(types:EventHubConsumerGroup consumerGroupMapping) returns string {
    return string `${consumerGroupMapping.namespaceId}_${consumerGroupMapping.eventHub}_${consumerGroupMapping.partition}_${consumerGroupMapping.consumerGroup}`;
}

isolated function processEventHubPartitionMapping(types:EventHubPartition payload, string mode) returns error? {
    final string partitionMappingKey = getPartitionMappingKey(payload);
    if mode is EVENT_MODE_ADD {
        lock {
            boolean mappingNotAvailable = vacantEventHubPartitions.every(mapping => partitionMappingKey != getPartitionMappingKey(mapping));
            if mappingNotAvailable {
                vacantEventHubPartitions.push(payload.cloneReadOnly());
            }
        }
    } else {
        [int, types:EventHubPartition][] availableMappings = getAvailablePartitionMappings(partitionMappingKey);
        if availableMappings.length() > 0 {
            [int, types:EventHubPartition] [idx, _] = availableMappings[0];
            lock {
                _ = vacantEventHubPartitions.remove(idx);
            }
        }
    }
    lock {
        _ = check persist:persistEventHubPartitionMappings(vacantEventHubPartitions);
    }
}

isolated function getAvailablePartitionMappings(string partitionMappingKey) returns [int, types:EventHubPartition][] {
    lock {
        return vacantEventHubPartitions.enumerate()
            .filter(entry => partitionMappingKey == getPartitionMappingKey(entry[1]))
            .cloneReadOnly();
    }
}

isolated function getPartitionMappingKey(types:EventHubPartition partitionMapping) returns string {
    return string `${partitionMapping.namespaceId}_${partitionMapping.eventHub}_${partitionMapping.partition}`;
}

