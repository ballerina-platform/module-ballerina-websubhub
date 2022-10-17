// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/http;
import ballerina/websubhub;
import ballerinax/kafka;
import kafkaHub.connections as conn;
import kafkaHub.persistence as persist;
import kafkaHub.types;
import ballerina/log;
import kafkaHub.util;
import kafkaHub.config;

public function main() returns error? {    
    // Dispatch `hub` restart event to topics/subscriptions
    _ = check persist:persistRestartEvent();
    // Assign EventHub partitions to system-consumers
    _ = check assignPartitionsToSystemConsumers();
    
    // Initialize the Hub
    _ = @strand { thread: "any" } start syncRegsisteredTopicsCache();
    _ = @strand { thread: "any" } start syncSubscribersCache();
    _ = @strand { thread: "any" } start syncVacantEventHubMappins();
    _ = @strand { thread: "any" } start syncVacantConsumerGroupMappins();
    
    // Start the HealthCheck Service
    http:Listener httpListener = check new (config:HUB_PORT);
    check httpListener.attach(healthCheckService, "/health");

    // Start the Hub
    websubhub:Listener hubListener = check new (httpListener);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();

    lock {
        startupCompleted = true;
    }
}

function assignPartitionsToSystemConsumers() returns error? {
    // assign relevant partitions to consolidated-topics consumer
    kafka:TopicPartition consolidatedTopicsPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_TOPICS_PARTITION
    };
    check conn:registeredTopicsConsumer->assign([consolidatedTopicsPartition]);

    // assign relevant partitions to consolidated-subscribers consumer
    kafka:TopicPartition consolidatedSubscribersPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION
    };
    check conn:subscribersConsumer->assign([consolidatedSubscribersPartition]);

    // assign relevant partitions to consolidated vacant-event-hub-mapping consumer
    kafka:TopicPartition consolidatedEventHubMappingsPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_VACANT_EVENT_HUB_MAPPINGS_PARTITION
    };
    check conn:eventHubMappingsConsumer->assign([consolidatedEventHubMappingsPartition]);

    // assign relevant partitions to consolidated vacant-consumer-group-mapping consumer
    kafka:TopicPartition consolidatedConsumerGroupMappingsPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_VACANT_EVENT_HUB_CONSUMER_GROUP__MAPPINGS_PARTITION
    };
    check conn:consumerGroupsMappingsConsumer->assign([consolidatedConsumerGroupMappingsPartition]);
}

function syncVacantEventHubMappins() {
    do {
        while true {
            types:EventHubPartition[] persistedVacantPartitions = check getPersistedVacantEventHubMappings();
            _ = util:refreshVacantPartitionAssignments(persistedVacantPartitions);
        }
    } on fail var e {
        log:printError("Error occurred while syncing vacant event-hub-mappings ", err = e.message());
        kafka:Error? result = conn:eventHubMappingsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }  
}

function getPersistedVacantEventHubMappings() returns types:EventHubPartition[]|error {
    types:VacantEventHubPartitions[] records = check conn:eventHubMappingsConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        return records.pop().value;
    }
    return [];
}

function syncVacantConsumerGroupMappins() {
    do {
        while true {
            types:EventHubConsumerGroup[] persistedVacantPartitions = check getPersistedVacantConsumerGroupMappings();
            _ = util:refreshVacantConsumerGroupAssignments(persistedVacantPartitions);
        }
    } on fail var e {
        log:printError("Error occurred while syncing vacant consumer-group-mappings ", err = e.message());
        kafka:Error? result = conn:consumerGroupsMappingsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }  
}

function getPersistedVacantConsumerGroupMappings() returns types:EventHubConsumerGroup[]|error {
    types:VacantConsumerGroups[] records = check conn:consumerGroupsMappingsConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        return records.pop().value;
    }
    return [];
}
