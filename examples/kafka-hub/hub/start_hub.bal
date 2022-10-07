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
import kafkaHub.util;
import kafkaHub.connections as conn;
import kafkaHub.persistence as persist;
import kafkaHub.types;
import ballerina/mime;
import kafkaHub.config;

isolated map<types:TopicRegistration> registeredTopicsCache = {};
isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

const string PARTITION_MAPPING = "partitionMapping";
const string NAMESPACE_ID = "namespaceId";
const string EVENT_HUB_NAME = "eventHubName";
const string EVENT_HUB_PARTITION = "eventHubPartition";
const string CONSUMER_GROUP = "consumerGroup";

public function main() returns error? {    
    // Dispatch `hub` restart event to topics/subscriptions
    _ = check persist:persistRestartEvent();
    // Assign EventHub partitions to system-consumers
    _ = check assignPartitionsToSystemConsumers();
    
    // Initialize the Hub
    _ = @strand { thread: "any" } start syncRegsisteredTopicsCache();
    _ = @strand { thread: "any" } start syncSubscribersCache();
    
    // Start the HealthCheck Service
    http:Listener httpListener = check new (config:HUB_PORT);
    check httpListener.attach(healthCheckService, "/health");

    // Start the Hub
    websubhub:Listener hubListener = check new (httpListener);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();

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
    _ = check conn:registeredTopicsConsumer->assign([consolidatedTopicsPartition]);

    // assign relevant partitions to consolidated-subscribers consumer
    kafka:TopicPartition consolidatedSubscribersPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION
    };
    _ = check conn:subscribersConsumer->assign([consolidatedSubscribersPartition]);
}

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
                types:TopicRegistration unregisteredTopic = registeredTopicsCache.remove(topic);
                _ = util:removePartitionAssignment(unregisteredTopic.partitionMapping.cloneReadOnly());
            }
        }
    }
    foreach types:TopicRegistration topic in persistedTopics.cloneReadOnly() {
        string topicName = util:sanitizeTopicName(topic.topic);
        lock {
            if !registeredTopicsCache.hasKey(topicName) {
                registeredTopicsCache[topicName] = topic;
                check util:updateNextPartition(topic.partitionMapping);
            } 
        }
    }
}

function syncSubscribersCache() {
    do {
        while true {
            websubhub:VerifiedSubscription[] persistedSubscribers = check getPersistedSubscribers();
            check refreshSubscribersCache(persistedSubscribers);
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
    types:ConsolidatedSubscribersConsumerRecord[] records = check conn:subscribersConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        types:ConsolidatedSubscribersConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
}

function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) returns error? {
    final readonly & string[] subscriberIds = persistedSubscribers
        .'map(sub => util:generateSubscriberId(sub.hubTopic, sub.hubCallback))
        .cloneReadOnly();
    lock {
        if subscriberIds.length() != 0 {
            string[] unsubscribedSubscribers = subscribersCache.keys().filter('key => subscriberIds.indexOf('key) is ());
            foreach var sub in unsubscribedSubscribers {
                websubhub:VerifiedSubscription subscriber = subscribersCache.remove(sub);
                readonly & types:EventHubConsumerGroup consumerGroupMapping = {
                    namespaceId: check subscriber[NAMESPACE_ID].ensureType(), 
                    eventHub: check subscriber[EVENT_HUB_NAME].ensureType(),
                    partition: check subscriber[EVENT_HUB_PARTITION].ensureType(),
                    consumerGroup: check subscriber[CONSUMER_GROUP].ensureType()
                };
                _ = util:removeConsumerGroupAssignment(consumerGroupMapping);
            }
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
            string namespaceId = check subscriber[NAMESPACE_ID].ensureType();
            string consumerGroup = check subscriber[CONSUMER_GROUP].ensureType();
            readonly & types:EventHubConsumerGroup consumerGroupMapping = {
                namespaceId: namespaceId,
                eventHub: check subscriber[EVENT_HUB_NAME].ensureType(),
                partition: check subscriber[EVENT_HUB_PARTITION].ensureType(),
                consumerGroup: consumerGroup
            };
            _ = check util:updateNextConsumerGroup(consumerGroupMapping);
            kafka:Consumer consumerEp = check conn:createMessageConsumer(namespaceId, consumerGroup);
            _ = check consumerEp->assign([{topic: consumerGroupMapping.eventHub, partition: consumerGroupMapping.partition}]);
            websubhub:HubClient hubClientEp = check new (subscriber, {
                retryConfig: {
                    interval: config:MESSAGE_DELIVERY_RETRY_INTERVAL,
                    count: config:MESSAGE_DELIVERY_COUNT,
                    backOffFactor: 2.0,
                    maxWaitInterval: 20
                },
                timeout: config:MESSAGE_DELIVERY_TIMEOUT
            });
            _ = @strand { thread: "any" } start pollForNewUpdates(hubClientEp, consumerEp, topicName, subscriberId);
        }
    }
}

isolated function pollForNewUpdates(websubhub:HubClient clientEp, kafka:Consumer consumerEp, string topicName, string subscriberId) {
    do {
        while true {
            types:UpdateMessageConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
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

isolated function notifySubscribers(types:UpdateMessageConsumerRecord[] records, websubhub:HubClient clientEp, kafka:Consumer consumerEp) returns error? {
    foreach types:UpdateMessageConsumerRecord kafkaRecord in records {
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
