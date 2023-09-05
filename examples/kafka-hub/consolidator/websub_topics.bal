// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/websubhub;
import consolidatorService.connections as conn;
import consolidatorService.util;
import consolidatorService.persistence as persist;
import ballerina/lang.value;
import ballerinax/kafka;
import ballerina/log;
import consolidatorService.config;

isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};

isolated function syncRegsisteredTopicsCache() {
    do {
        websubhub:TopicRegistration[]? persistedTopics = check getPersistedTopics();
        if persistedTopics is websubhub:TopicRegistration[] {
            refreshTopicCache(persistedTopics);
        }
    } on fail var e {
        log:printError("Error occurred while syncing registered-topics-cache ", err = e.message());
        kafka:Error? result = conn:consolidatedTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

isolated function getPersistedTopics() returns websubhub:TopicRegistration[]|error? {
    kafka:ConsumerRecord[] records = check conn:consolidatedTopicsConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if lastPersistedData is string {
            return deSerializeTopicsMessage(lastPersistedData);
        } else {
            log:printError("Error occurred while retrieving topic-details ", err = lastPersistedData.message());
            return lastPersistedData;
        }
    }
    return;
}

isolated function deSerializeTopicsMessage(string lastPersistedData) returns websubhub:TopicRegistration[]|error {
    websubhub:TopicRegistration[] currentTopics = [];
    json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
    foreach var data in payload {
        websubhub:TopicRegistration topic = check data.cloneWithType(websubhub:TopicRegistration);
        currentTopics.push(topic);
    }
    return currentTopics;
}

isolated function refreshTopicCache(websubhub:TopicRegistration[] persistedTopics) {
    foreach var topic in persistedTopics.cloneReadOnly() {
        string topicName = util:sanitizeTopicName(topic.topic);
        lock {
            registeredTopicsCache[topicName] = topic.cloneReadOnly();
        }
    }
}

isolated function processTopicRegistration(json payload) returns error? {
    websubhub:TopicRegistration registration = check value:cloneWithType(payload);
    string topicName = util:sanitizeTopicName(registration.topic);
    lock {
        // add the topic if topic-registration event received
        registeredTopicsCache[topicName] = registration.cloneReadOnly();
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function processTopicDeregistration(json payload) returns error? {
    websubhub:TopicDeregistration deregistration = check value:cloneWithType(payload);
    string topicName = util:sanitizeTopicName(deregistration.topic);
    lock {
        // remove the topic if topic-deregistration event received
        _ = registeredTopicsCache.removeIfHasKey(topicName);
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function getTopics() returns websubhub:TopicRegistration[] {
    lock {
        return registeredTopicsCache.toArray().cloneReadOnly();
    }
}
