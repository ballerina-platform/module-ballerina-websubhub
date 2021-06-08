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
import ballerina/log;
import kafkaHub.config;
import kafkaHub.connections as conn;

public isolated function persistTopicRegistrations(map<websubhub:TopicRegistration> registeredTopics, websubhub:TopicRegistration message) returns error? {
    websubhub:TopicRegistration[] availableTopics = [];
    foreach var topic in registeredTopics {
        availableTopics.push(topic);
    }
    availableTopics.push(message.cloneReadOnly());
    log:printInfo("Updated persistent data ", current = availableTopics);
    json[] jsonData = availableTopics;
    check publishHousekeepingData(config:REGISTERED_TOPICS_TOPIC, jsonData);
}

public isolated function persistTopicDeregistration(map<websubhub:TopicRegistration> registeredTopics, websubhub:TopicDeregistration message) returns error? {
    websubhub:TopicRegistration[] availableTopics = [];
    foreach var topic in registeredTopics {
        availableTopics.push(topic);
    }
    availableTopics = 
        from var registration in availableTopics
        where registration.topic != message.topic
        select registration.cloneReadOnly();
    log:printInfo("Updated persistent data ", current = availableTopics);
    json[] jsonData = availableTopics;
    check publishHousekeepingData(config:REGISTERED_TOPICS_TOPIC, jsonData);
}

public isolated function persistSubscription(map<websubhub:VerifiedSubscription> registeredSubscribers, websubhub:VerifiedSubscription message) returns error? {
    websubhub:VerifiedSubscription[] availableSubscriptions = [];
    foreach var subscriber in registeredSubscribers {
        availableSubscriptions.push(subscriber);
    }
    availableSubscriptions.push(message.cloneReadOnly());
    log:printInfo("Updated subscriptions ", current = availableSubscriptions);
    json[] jsonData = <json[]> availableSubscriptions.toJson();
    check publishHousekeepingData(config:SUBSCRIBERS_TOPIC, jsonData); 
}

public isolated function persistUnsubscription(map<websubhub:VerifiedSubscription> subscribersCache, websubhub:VerifiedUnsubscription message) returns error? {
    websubhub:VerifiedUnsubscription[] availableSubscriptions = [];
    foreach var subscriber in subscribersCache {
        availableSubscriptions.push(subscriber);
    }
    availableSubscriptions = 
        from var subscription in availableSubscriptions
        where subscription.hubTopic != message.hubTopic && subscription.hubCallback != message.hubCallback
        select subscription.cloneReadOnly();
    log:printInfo("Updated subscriptions ", current = availableSubscriptions);
    json[] jsonData = <json[]> availableSubscriptions.toJson();
    check publishHousekeepingData(config:SUBSCRIBERS_TOPIC, jsonData);
}

isolated function publishHousekeepingData(string topicName, json payload) returns error? {
    log:printInfo("Publish house-keeping data ", topic = topicName, payload = payload);
    byte[] serializedContent = payload.toJsonString().toBytes();
    check conn:statePersistProducer->send({ topic: topicName, value: serializedContent });
    check conn:statePersistProducer->'flush();
}
