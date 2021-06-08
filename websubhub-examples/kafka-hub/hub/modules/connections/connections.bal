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
import kafkaHub.util;

kafka:ProducerConfiguration producerConfig = {
    clientId: "update-message",
    acks: "1",
    retryCount: 3
};
public final kafka:Producer updateMessageProducer = check new ("localhost:9092", producerConfig);

kafka:ProducerConfiguration statePersistConfig = {
    clientId: "housekeeping-service",
    acks: "1",
    retryCount: 3
};
public final kafka:Producer statePersistProducer = check new ("localhost:9092", statePersistConfig);

kafka:ConsumerConfiguration subscriberDetailsConsumerConfig = {
    groupId: "registered-consumers-group-" + config:CONSTRUCTED_SERVER_ID,
    offsetReset: "earliest",
    topics: [ config:REGISTERED_CONSUMERS ]
};
public final kafka:Consumer subscriberDetailsConsumer = check new ("localhost:9092", subscriberDetailsConsumerConfig);

kafka:ConsumerConfiguration topicDetailsConsumerConfig = {
    groupId: "registered-topics-group-" + config:CONSTRUCTED_SERVER_ID,
    offsetReset: "earliest",
    topics: [ config:REGISTERED_TOPICS ]
};
public final kafka:Consumer topicDetailsConsumer = check new ("localhost:9092", topicDetailsConsumerConfig);

public isolated function createMessageConsumer(websubhub:VerifiedSubscription message) returns kafka:Consumer|error {
    string topicName = util:generateTopicName(message.hubTopic);
    string groupName = util:generateGroupName(message.hubTopic, message.hubCallback);
    kafka:ConsumerConfiguration consumerConfiguration = {
        groupId: groupName,
        offsetReset: "latest",
        topics: [topicName],
        autoCommit: false
    };
    return check new ("localhost:9092", consumerConfiguration);  
}
