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

import ballerinax/kafka;
import ballerina/log;
import consolidatorService.config;
import consolidatorService.types;
import consolidatorService.util;
import ballerina/websubhub;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;

isolated map<types:TopicRegistration> registeredTopicsCache = {};

isolated function syncRegsisteredTopicsCache() returns error? {
    do {
        types:TopicRegistration[] persistedTopics = check getPersistedTopics();
        check refreshTopicCache(persistedTopics);
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

isolated function refreshTopicCache(types:TopicRegistration[] persistedTopics) returns error? {
    foreach var topic in persistedTopics.cloneReadOnly() {
        string topicName = util:sanitizeTopicName(topic.topic);
        lock {
            registeredTopicsCache[topicName] = topic.cloneReadOnly();
        }
        types:EventHubPartition partitionMapping = check topic?.partitionMapping.ensureType();
        check util:updateNextPartition(partitionMapping.cloneReadOnly());
    }
}

isolated function processTopicRegistration(json payload) returns error? {
    types:TopicRegistration registration = check payload.fromJsonWithType();
    readonly & types:EventHubPartition partitionMapping = check util:getNextPartition().cloneReadOnly();
    string topicName = util:sanitizeTopicName(registration.topic);
    lock {
        // add the topic if topic-registration event received
        if !registeredTopicsCache.hasKey(topicName) {
            registeredTopicsCache[topicName] = {
                topic: registration.topic,
                hubMode: registration.hubMode,
                partitionMapping: partitionMapping
            };
        }
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function processTopicDeregistration(json payload) returns error? {
    websubhub:TopicDeregistration deregistration = check payload.fromJsonWithType();
    string topicName = util:sanitizeTopicName(deregistration.topic);
    types:TopicRegistration? topicRegistration = removeTopicRegistration(topicName);
    if topicRegistration is types:TopicRegistration {
        types:EventHubPartition partitionMapping = check topicRegistration?.partitionMapping.ensureType();
        util:updateVacantPartitionAssignment(partitionMapping.cloneReadOnly());
    }
    lock {
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function removeTopicRegistration(string topicName) returns types:TopicRegistration? {
    lock {
        return registeredTopicsCache.removeIfHasKey(topicName).cloneReadOnly();
    }
}
