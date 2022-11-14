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
import ballerinax/kafka;
import kafkaHub.util;
import kafkaHub.connections as conn;
import kafkaHub.types;
import kafkaHub.config;

isolated map<types:TopicRegistration> registeredTopicsCache = {};

function syncRegsisteredTopicsCache() {
    do {
        while true {
            types:TopicRegistration[] persistedTopics = check getPersistedTopics();
            check refreshTopicCache(persistedTopics);
        }
    } on fail var e {
        log:printError("Error occurred while syncing registered-topics-cache ", err = e.message());
        kafka:Error? result = conn:registeredTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

function getPersistedTopics() returns types:TopicRegistration[]|error {
    types:ConsolidatedTopicsConsumerRecord[] records = check conn:registeredTopicsConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        types:ConsolidatedTopicsConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
}

function refreshTopicCache(types:TopicRegistration[] persistedTopics) returns error? {
    final readonly & string[] topicNames = persistedTopics
        .'map(topicReg => util:sanitizeTopicName(topicReg.topic))
        .cloneReadOnly();
    lock {
        if topicNames.length() != 0 {
            string[] unregisteredTopics = registeredTopicsCache.keys().filter('key => topicNames.indexOf('key) is ());
            foreach string topic in unregisteredTopics {
                _ = registeredTopicsCache.removeIfHasKey(topic);
            }
        }
    }
    foreach types:TopicRegistration topic in persistedTopics.cloneReadOnly() {
        string topicName = util:sanitizeTopicName(topic.topic);
        lock {
            if !registeredTopicsCache.hasKey(topicName) {
                registeredTopicsCache[topicName] = topic;
            } 
        }
    }
}

isolated function isValidTopic(string topicName) returns boolean {
    lock {
        return registeredTopicsCache.hasKey(topicName);
    }
}
