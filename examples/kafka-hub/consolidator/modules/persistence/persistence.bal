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

import ballerina/websubhub;
import consolidatorService.config;
import consolidatorService.connections as conn;
import consolidatorService.types;

public isolated function persistTopicRegistrations(map<types:TopicRegistration> registeredTopicsCache) returns error? {
    types:TopicRegistration[] availableTopics = [];
    foreach var topic in registeredTopicsCache {
        availableTopics.push(topic);
    }
    json[] jsonData = <json[]> availableTopics.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:CONSOLIDATED_WEBSUB_TOPICS_PARTITION, jsonData);
}

public isolated function persistSubscriptions(map<websubhub:VerifiedSubscription> subscribersCache) returns error? {
    websubhub:VerifiedSubscription[] availableSubscriptions = [];
    foreach var subscriber in subscribersCache {
        availableSubscriptions.push(subscriber);
    }
    json[] jsonData = <json[]> availableSubscriptions.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION, jsonData);
}

public isolated function persistEventHubPartitionMappings(types:EventHubPartition[] vacantPartitions) returns error? {
    json[] jsonData = <json[]> vacantPartitions.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:CONSOLIDATED_VACANT_EVENT_HUB_MAPPINGS_PARTITION, jsonData);
}

public isolated function persistConsumerGroupMappings(types:EventHubConsumerGroup[] vacantConsumerGroups) returns error? {
    json[] jsonData = <json[]> vacantConsumerGroups.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:CONSOLIDATED_VACANT_EVENT_HUB_MAPPINGS_PARTITION, jsonData);
}

isolated function produceKafkaMessage(string topicName, int partition, json payload) returns error? {
    byte[] serializedContent = payload.toJsonString().toBytes();
    check conn:statePersistProducer->send({ topic: topicName, partition: partition, value: serializedContent });
    check conn:statePersistProducer->'flush();
}
