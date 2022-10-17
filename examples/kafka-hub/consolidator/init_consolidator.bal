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
import ballerina/websubhub;
import ballerina/log;
import consolidatorService.config;
import consolidatorService.types;
import consolidatorService.util;
import ballerina/http;
import consolidatorService.connections as conn;

isolated map<types:TopicRegistration> registeredTopicsCache = {};
isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

public function main() returns error? {
    _ = check assignPartitionsToSystemConsumers();
    // Initialize consolidator-service state
    syncRegsisteredTopicsCache();
    _ = check conn:consolidatedTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
    syncSubscribersCache();
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

isolated function syncRegsisteredTopicsCache() {
    do {
        types:TopicRegistration[] persistedTopics = check getPersistedTopics();
        refreshTopicCache(persistedTopics);
    } on fail var e {
        log:printError("Error occurred while syncing registered-topics-cache ", err = e.message());
        kafka:Error? result = conn:consolidatedTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

isolated function getPersistedTopics() returns types:TopicRegistration[]|error {
    types:ConsolidatedTopicsConsumerRecord[] records = check conn:consolidatedTopicsConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        types:ConsolidatedTopicsConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
}

isolated function refreshTopicCache(types:TopicRegistration[] persistedTopics) {
    foreach var topic in persistedTopics.cloneReadOnly() {
        string topicName = util:sanitizeTopicName(topic.topic);
        lock {
            registeredTopicsCache[topicName] = topic.cloneReadOnly();
        }
    }
}

isolated function syncSubscribersCache() {
    do {
        websubhub:VerifiedSubscription[] persistedSubscribers = check getPersistedSubscribers();
        refreshSubscribersCache(persistedSubscribers);
    } on fail var e {
        log:printError("Error occurred while syncing subscribers-cache ", err = e.message());
        kafka:Error? result = conn:consolidatedSubscriberConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    } 
}

isolated function getPersistedSubscribers() returns websubhub:VerifiedSubscription[]|error {
    types:ConsolidatedSubscribersConsumerRecord[] records = check conn:consolidatedSubscriberConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        types:ConsolidatedSubscribersConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
}

isolated function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) {
    foreach var subscriber in persistedSubscribers {
        string groupName = util:generatedSubscriberId(subscriber.hubTopic, subscriber.hubCallback);
        lock {
            subscribersCache[groupName] = subscriber.cloneReadOnly();
        }
    }
}
