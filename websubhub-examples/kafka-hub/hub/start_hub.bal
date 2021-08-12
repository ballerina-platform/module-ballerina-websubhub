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

import ballerina/log;
import ballerina/websubhub;
import ballerinax/kafka;
import ballerina/lang.value;
import kafkaHub.util;
import kafkaHub.connections as conn;
import ballerina/mime;
import kafkaHub.config;

isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};
isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

public function main() returns error? {    
    // Initialize the Hub
    _ = @strand { thread: "any" } start syncRegsisteredTopicsCache();
    _ = @strand { thread: "any" } start syncSubscribersCache();
    
    // Start the Hub
    websubhub:Listener hubListener = check new (config:HUB_PORT, 
        secureSocket = {
            key: {
                certFile: "./resources/server.crt",
                keyFile: "./resources/server.key"
            }
        }
    );
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}

function syncRegsisteredTopicsCache() {
    do {
        while true {
            websubhub:TopicRegistration[]? persistedTopics = check getPersistedTopics();
            if persistedTopics is websubhub:TopicRegistration[] {
                refreshTopicCache(persistedTopics);
            }
        }
    } on fail var e {
        log:printError("Error occurred while syncing registered-topics-cache ", err = e.message());

        kafka:Error? result = conn:registeredTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

function getPersistedTopics() returns websubhub:TopicRegistration[]|error? {
    kafka:ConsumerRecord[] records = check conn:registeredTopicsConsumer->poll(config:POLLING_INTERVAL);
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
}

function deSerializeTopicsMessage(string lastPersistedData) returns websubhub:TopicRegistration[]|error {
    websubhub:TopicRegistration[] currentTopics = [];
    json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
    foreach var data in payload {
        websubhub:TopicRegistration topic = check data.cloneWithType(websubhub:TopicRegistration);
        currentTopics.push(topic);
    }
    return currentTopics;
}

function refreshTopicCache(websubhub:TopicRegistration[] persistedTopics) {
    lock {
        registeredTopicsCache.removeAll();
    }
    foreach var topic in persistedTopics.cloneReadOnly() {
        string topicName = util:sanitizeTopicName(topic.topic);
        lock {
            registeredTopicsCache[topicName] = topic.cloneReadOnly();
        }
    }
}

function syncSubscribersCache() {
    do {
        while true {
            websubhub:VerifiedSubscription[]? persistedSubscribers = check getPersistedSubscribers();
            if persistedSubscribers is websubhub:VerifiedSubscription[] {
                refreshSubscribersCache(persistedSubscribers);
                check startMissingSubscribers(persistedSubscribers);
            }
        }
    } on fail var e {
        log:printError("Error occurred while syncing subscribers-cache ", err = e.message());

        kafka:Error? result = conn:subscribersConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }  
}

function getPersistedSubscribers() returns websubhub:VerifiedSubscription[]|error? {
    kafka:ConsumerRecord[] records = check conn:subscribersConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if lastPersistedData is string {
            return deSerializeSubscribersMessage(lastPersistedData);
        } else {
            log:printError("Error occurred while retrieving subscriber-data ", err = lastPersistedData.message());
            return lastPersistedData;
        }
    } 
}

function deSerializeSubscribersMessage(string lastPersistedData) returns websubhub:VerifiedSubscription[]|error {
    websubhub:VerifiedSubscription[] currentSubscriptions = [];
    json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
    foreach var data in payload {
        websubhub:VerifiedSubscription subscription = check data.cloneWithType(websubhub:VerifiedSubscription);
        currentSubscriptions.push(subscription);
    }
    return currentSubscriptions;
}

function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) {
    string[] groupNames = persistedSubscribers.'map(sub => util:generateGroupName(sub.hubTopic, sub.hubCallback));
    lock {
        string[] unsubscribedSubscribers = subscribersCache.keys().filter('key => groupNames.indexOf('key) is ());
        foreach var sub in unsubscribedSubscribers {
            _ = subscribersCache.removeIfHasKey(sub);
        }
    }
}

function startMissingSubscribers(websubhub:VerifiedSubscription[] persistedSubscribers) returns error? {
    foreach var subscriber in persistedSubscribers {
        string topicName = util:sanitizeTopicName(subscriber.hubTopic);
        string groupName = util:generateGroupName(subscriber.hubTopic, subscriber.hubCallback);
        boolean subscriberNotAvailable = true;
        lock {
            subscriberNotAvailable = !subscribersCache.hasKey(groupName);
            subscribersCache[groupName] = subscriber.cloneReadOnly();
        }
        if subscriberNotAvailable {
            kafka:Consumer consumerEp = check conn:createMessageConsumer(subscriber);
            websubhub:HubClient hubClientEp = check new (subscriber, {
                retryConfig: {
                    interval: config:MESSAGE_DELIVERY_RETRY_INTERVAL,
                    count: config:MESSAGE_DELIVERY_COUNT,
                    backOffFactor: 2.0,
                    maxWaitInterval: 20
                },
                timeout: config:MESSAGE_DELIVERY_TIMEOUT,
                secureSocket: {
                    cert: "./resources/server.crt"
                }
            });
            _ = @strand { thread: "any" } start pollForNewUpdates(hubClientEp, consumerEp, topicName, groupName);
        }
    }
}

isolated function pollForNewUpdates(websubhub:HubClient clientEp, kafka:Consumer consumerEp, string topicName, string groupName) {
    do {
        while true {
            kafka:ConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
            if !isValidConsumer(topicName, groupName) {
                fail error(string `Consumer with group name ${groupName} or topic ${topicName} is invalid`);
            }
            _ = check notifySubscribers(records, clientEp, consumerEp);
        }
    } on fail var e {
        lock {
            _ = subscribersCache.remove(groupName);
        }
        log:printError("Error occurred while sending notification to subscriber", err = e.message());

        kafka:Error? result = consumerEp->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

isolated function isValidConsumer(string topicName, string groupName) returns boolean {
    boolean topicAvailable = true;
    lock {
        topicAvailable = registeredTopicsCache.hasKey(topicName);
    }
    boolean subscriberAvailable = true;
    lock {
        subscriberAvailable = subscribersCache.hasKey(groupName);
    }
    return topicAvailable && subscriberAvailable;
}

isolated function notifySubscribers(kafka:ConsumerRecord[] records, websubhub:HubClient clientEp, kafka:Consumer consumerEp) returns error? {
    foreach var kafkaRecord in records {
        var message = deSerializeKafkaRecord(kafkaRecord);
        if (message is websubhub:ContentDistributionMessage) {
            var response = clientEp->notifyContentDistribution(message);
            if (response is error) {
                return response;
            } else {
                _ = check consumerEp->commit();
            }
        } else {
            log:printError("Error occurred while retrieving message data", err = message.message());
        }
    }
}

isolated function deSerializeKafkaRecord(kafka:ConsumerRecord kafkaRecord) returns websubhub:ContentDistributionMessage|error {
    byte[] content = kafkaRecord.value;
    string message = check string:fromBytes(content);
    json payload =  check value:fromJsonString(message);
    websubhub:ContentDistributionMessage distributionMsg = {
        content: payload,
        contentType: mime:APPLICATION_JSON
    };
    return distributionMsg;
}
