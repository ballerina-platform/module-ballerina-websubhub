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
                certFile: "../_resources/server.crt",
                keyFile: "../_resources/server.key"
            }
        }
    );
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}

function syncRegsisteredTopicsCache() returns error? {
    while true {
        websubhub:TopicRegistration[]|error? persistedTopics = getPersistedTopics();
        if persistedTopics is websubhub:TopicRegistration[] {
            refreshTopicCache(persistedTopics);
        }
    }
    _ = check conn:registeredTopicsConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
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

function syncSubscribersCache() returns error? {
    while true {
        websubhub:VerifiedSubscription[]|error? persistedSubscribers = getPersistedSubscribers();
        if persistedSubscribers is websubhub:VerifiedSubscription[] {
            refreshSubscribersCache(persistedSubscribers);
            check startMissingSubscribers(persistedSubscribers);
        }
    }
    _ = check conn:subscribersConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
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
                    cert: "../_resources/server.crt"
                }
            });
            _ = @strand { thread: "any" } start notifySubscriber(hubClientEp, consumerEp, topicName, groupName);
        }
    }
}

isolated function notifySubscriber(websubhub:HubClient clientEp, kafka:Consumer consumerEp, string topicName, string groupName) returns error? {
    while true {
        kafka:ConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
        
        if !isValidConsumer(topicName, groupName) {
            _ = check consumerEp->close(config:GRACEFUL_CLOSE_PERIOD);
            break;
        }
        
        foreach var kafkaRecord in records {
            var message = deSerializeKafkaRecord(kafkaRecord);
            if (message is websubhub:ContentDistributionMessage) {
                var response = clientEp->notifyContentDistribution(message);
                if (response is error) {
                    log:printError("Error occurred while sending notification to subscriber ", err = response.message());
                    lock {
                        _ = subscribersCache.remove(groupName);
                    }
                    break;
                } else {
                    _ = check consumerEp->commit();
                }
            } else {
                log:printError("Error occurred while retrieving message data", err = message.message());
            }
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
    if !topicAvailable || !subscriberAvailable {
        return false;
    } else {
        return true;
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
