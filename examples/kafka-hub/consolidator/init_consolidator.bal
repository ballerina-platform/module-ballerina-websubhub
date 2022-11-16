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

import ballerinax/kafka;
import ballerina/log;
import consolidatorService.config;
import ballerina/http;
import consolidatorService.connections as conn;

public function main() returns error? {
    _ = check assignPartitionsToSystemConsumers();
    // Initialize consolidator-service state
    check syncRegsisteredTopicsCache();
    _ = check conn:consolidatedTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
    check syncSubscribersCache();
    _ = check conn:consolidatedSubscriberConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
    
    // Start the HealthCheck Service
    http:Listener httpListener = check new (config:HEALTH_PROBE_PORT);
    check httpListener.attach(healthCheckService, "/health");
    check httpListener.'start();

    log:printInfo("Starting Event Consolidator Service");
    // start the consolidator-service
    _ = @strand { thread: "any" } start startConsolidator();
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
    _ = check conn:consolidatedTopicsConsumer->assign([consolidatedTopicsPartition]);

    // assign relevant partitions to consolidated-subscribers consumer
    kafka:TopicPartition consolidatedSubscribersPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION
    };
    _ = check conn:consolidatedSubscriberConsumer->assign([consolidatedSubscribersPartition]);

    kafka:TopicPartition[] websubEventsPartitions = [
        { topic: config:SYSTEM_INFO_HUB, partition: config:REGISTERED_WEBSUB_TOPICS_PARTITION },
        { topic: config:SYSTEM_INFO_HUB, partition: config:WEBSUB_SUBSCRIBERS_PARTITION },
        { topic: config:SYSTEM_INFO_HUB, partition: config:SYSTEM_EVENTS_PARTITION }
    ];
    _ = check conn:websubEventConsumer->assign(websubEventsPartitions);
}
