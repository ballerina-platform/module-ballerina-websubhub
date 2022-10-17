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
import kafkaHub.config;
import kafkaHub.connections as conn;
import kafkaHub.types;
import ballerina/lang.value;

public isolated function addRegsiteredTopic(types:TopicRegistration message) returns error? {
    check updateTopicDetails(message);
}

public isolated function removeRegsiteredTopic(websubhub:TopicDeregistration message) returns error? {
    check updateTopicDetails(message);
}

isolated function updateTopicDetails(types:TopicRegistration|websubhub:TopicDeregistration message) returns error? {
    json jsonData = message.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:REGISTERED_WEBSUB_TOPICS_PARTITION, jsonData);
}

public isolated function addSubscription(websubhub:VerifiedSubscription message) returns error? {
    check updateSubscriptionDetails(message); 
}

public isolated function removeSubscription(websubhub:VerifiedUnsubscription message) returns error? {
    check updateSubscriptionDetails(message); 
}

isolated function updateSubscriptionDetails(websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription message) returns error? {
    json jsonData = message.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:WEBSUB_SUBSCRIBERS_PARTITION, jsonData); 
}

public isolated function persistRestartEvent() returns error? {
    types:HubRestartEvent message = {};
    json jsonData = message.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:SYSTEM_EVENTS_PARTITION, jsonData);
}

public isolated function addVacantEventHubMapping(types:EventHubPartition mapping) returns error? {
    check updateVacantMappings({mode: "add", mapping: mapping}, config:VACANT_EVENT_HUB_MAPPINGS_PARTITION);
}

public isolated function removeVacantEventHubMapping(types:EventHubPartition mapping) returns error? {
    check updateVacantMappings({mode: "remove", mapping: mapping}, config:VACANT_EVENT_HUB_MAPPINGS_PARTITION);
}

public isolated function addVacantEventHubConsumerGroupMapping(types:EventHubConsumerGroup mapping) returns error? {
    check updateVacantMappings({mode: "add", mapping: mapping}, config:VACANT_EVENT_HUB_CONSUMER_GROUP_MAPPINGS_PARTITION);
}

public isolated function removeVacantEventHubConsumerGroupMapping(types:EventHubConsumerGroup mapping) returns error? {
    check updateVacantMappings({mode: "remove", mapping: mapping}, config:VACANT_EVENT_HUB_CONSUMER_GROUP_MAPPINGS_PARTITION);
}

public isolated function updateVacantMappings(types:VacantMapping message, int partition) returns error? {
    json jsonData = message.toJson();
    check produceKafkaMessage(config:SYSTEM_INFO_HUB, config:VACANT_EVENT_HUB_MAPPINGS_PARTITION, jsonData);
}

public isolated function addUpdateMessage(string namespaceId, string topicName, int partition, websubhub:UpdateMessage message) returns error? {
    json payload = check value:ensureType(message.content);
    kafka:Producer producerEp = conn:getKafkaProducer(namespaceId);
    check produceKafkaMessage(topicName, partition, payload, producerEp);
}

isolated function produceKafkaMessage(string topicName, int partition, json payload, kafka:Producer producerEp = conn:statePersistProducer) returns error? {
    byte[] serializedContent = payload.toJsonString().toBytes();
    check producerEp->send({ topic: topicName, partition: partition, value: serializedContent });
    check producerEp->'flush();
}
