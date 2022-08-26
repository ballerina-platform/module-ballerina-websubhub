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
import ballerina/http;
import ballerina/websubhub;
import ballerinax/kafka;
import ballerina/lang.value;
import kafkaHub.util;
import kafkaHub.connections as conn;
import ballerina/mime;
import kafkaHub.config;

isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};
isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

const string CONSUMER_GROUP = "consumerGroup";

public function main() returns error? {    
    // Initialize the Hub
    _ = @strand { thread: "any" } start syncRegsisteredTopicsCache();
    _ = @strand { thread: "any" } start syncSubscribersCache();
    
    // Start the HealthCheck Service
    http:Listener httpListener = check new (config:HUB_PORT, 
        secureSocket = {
            key: {
                certFile: "./resources/server.crt",
                keyFile: "./resources/server.key"
            }
        }
    );
    check httpListener.attach(healthCheckService, "/health");

    // Start the Hub
    websubhub:Listener hubListener = check new (httpListener);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}

function syncRegsisteredTopicsCache() {
    do {
        while true {
            websubhub:TopicRegistration[] persistedTopics = check getPersistedTopics();
            refreshTopicCache(persistedTopics);
        }
    } on fail var e {
        log:printError("Error occurred while syncing registered-topics-cache ", err = e.message());
        kafka:Error? result = conn:registeredTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

function getPersistedTopics() returns websubhub:TopicRegistration[]|error {
    kafka:TopicPartition partitionInfo = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_TOPICS_PARTITION
    };
    _ = check conn:registeredTopicsConsumer->assign([partitionInfo]);
    ConsolidatedTopicsConsumerRecord[] records = check conn:registeredTopicsConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        ConsolidatedTopicsConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
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
            websubhub:VerifiedSubscription[] persistedSubscribers = check getPersistedSubscribers();
            refreshSubscribersCache(persistedSubscribers);
            check startMissingSubscribers(persistedSubscribers);
        }
    } on fail var e {
        log:printError("Error occurred while syncing subscribers-cache ", err = e.message());
        kafka:Error? result = conn:subscribersConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }  
}

function getPersistedSubscribers() returns websubhub:VerifiedSubscription[]|error {
    kafka:TopicPartition partitionInfo = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION
    };
    _ = check conn:subscribersConsumer->assign([partitionInfo]);
    ConsolidatedSubscribersConsumerRecord[] records = check conn:subscribersConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        ConsolidatedSubscribersConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
}

function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) {
    final readonly & string[] subscriberIds = persistedSubscribers
        .'map(sub => util:generateSubscriberId(sub.hubTopic, sub.hubCallback))
        .cloneReadOnly();
    lock {
        string[] unsubscribedSubscribers = subscribersCache.keys().filter('key => subscriberIds.indexOf('key) is ());
        foreach var sub in unsubscribedSubscribers {
            _ = subscribersCache.removeIfHasKey(sub);
        }
    }
}

function startMissingSubscribers(websubhub:VerifiedSubscription[] persistedSubscribers) returns error? {
    foreach var subscriber in persistedSubscribers {
        string topicName = util:sanitizeTopicName(subscriber.hubTopic);
        string subscriberId = util:generateSubscriberId(subscriber.hubTopic, subscriber.hubCallback);
        boolean subscriberNotAvailable = true;
        lock {
            subscriberNotAvailable = !subscribersCache.hasKey(subscriberId);
            subscribersCache[subscriberId] = subscriber.cloneReadOnly();
        }
        if subscriberNotAvailable {
            string consumerGroup = check value:ensureType(subscriber[CONSUMER_GROUP]);
            kafka:Consumer consumerEp = check conn:createMessageConsumer(topicName, consumerGroup);
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
            _ = @strand { thread: "any" } start pollForNewUpdates(hubClientEp, consumerEp, topicName, subscriberId);
        }
    }
}

isolated function pollForNewUpdates(websubhub:HubClient clientEp, kafka:Consumer consumerEp, string topicName, string subscriberId) {
    do {
        while true {
            UpdateMessageConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
            if !isValidConsumer(topicName, subscriberId) {
                fail error(string `Subscriber with Id ${subscriberId} or topic ${topicName} is invalid`);
            }
            _ = check notifySubscribers(records, clientEp, consumerEp);
        }
    } on fail var e {
        lock {
            _ = subscribersCache.removeIfHasKey(subscriberId);
        }
        log:printError("Error occurred while sending notification to subscriber", err = e.message());

        kafka:Error? result = consumerEp->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

isolated function isValidConsumer(string topicName, string subscriberId) returns boolean {
    boolean topicAvailable = true;
    lock {
        topicAvailable = registeredTopicsCache.hasKey(topicName);
    }
    boolean subscriberAvailable = true;
    lock {
        subscriberAvailable = subscribersCache.hasKey(subscriberId);
    }
    return topicAvailable && subscriberAvailable;
}

isolated function notifySubscribers(UpdateMessageConsumerRecord[] records, websubhub:HubClient clientEp, kafka:Consumer consumerEp) returns error? {
    foreach UpdateMessageConsumerRecord kafkaRecord in records {
        websubhub:ContentDistributionMessage message = {
            content: kafkaRecord.value,
            contentType: mime:APPLICATION_JSON
        };
        websubhub:ContentDistributionSuccess|error response = clientEp->notifyContentDistribution(message);
        if response is error {
            return response;
        }
        _ = check consumerEp->commit();
    }
}
