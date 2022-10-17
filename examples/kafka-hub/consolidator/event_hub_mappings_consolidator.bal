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
    // todo: implement this method properly
}

isolated function processEventHubPartitionMapping(types:EventHubPartition payload, string mode) returns error? {
    // todo: implement this method properly
}


