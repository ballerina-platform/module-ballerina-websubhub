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

import ballerinax/kafka;
import ballerina/log;
import consolidatorService.config;
import consolidatorService.types;
import consolidatorService.util;
import ballerina/websubhub;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;

const string NAMESPACE_ID = "namespaceId";
const string EVENT_HUB_NAME = "eventHubName";
const string EVENT_HUB_PARTITION = "eventHubPartition";
const string CONSUMER_GROUP = "consumerGroup";

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

isolated function syncSubscribersCache() returns error? {
    do {
        websubhub:VerifiedSubscription[] persistedSubscribers = check getPersistedSubscribers();
        check refreshSubscribersCache(persistedSubscribers);
    } on fail var e {
        log:printError("Error occurred while syncing subscribers-cache ", err = e.message());
        kafka:Error? result = conn:consolidatedSubscriberConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    } 
}

isolated function getPersistedSubscribers() returns websubhub:VerifiedSubscription[]|error {
    types:ConsolidatedSubscribersConsumerRecord[] records = check conn:consolidatedSubscriberConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        types:ConsolidatedSubscribersConsumerRecord lastRecord = records.pop();
        return lastRecord.value;
    }
    return [];
}

isolated function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) returns error? {
    foreach var subscriber in persistedSubscribers {
        string groupName = util:generatedSubscriberId(subscriber.hubTopic, subscriber.hubCallback);
        lock {
            subscribersCache[groupName] = subscriber.cloneReadOnly();
        }
        readonly & types:EventHubConsumerGroup consumerGroupMapping = {
            namespaceId: check subscriber[NAMESPACE_ID].ensureType(),
            eventHub: check subscriber[EVENT_HUB_NAME].ensureType(),
            partition: check subscriber[EVENT_HUB_PARTITION].ensureType(),
            consumerGroup: check subscriber[CONSUMER_GROUP].ensureType()
        };
        _ = check util:updateNextConsumerGroup(consumerGroupMapping);
    }
}

isolated function processSubscription(json payload) returns error? {
    websubhub:VerifiedSubscription subscription = check payload.fromJsonWithType();
    types:EventHubPartition partitionMapping = check retrieveTopicPartitionMapping(subscription.hubTopic);
    types:EventHubConsumerGroup consumerGroupMapping = check util:getNextConsumerGroup(partitionMapping);
    subscription[NAMESPACE_ID] = consumerGroupMapping.namespaceId;
    subscription[EVENT_HUB_NAME] = consumerGroupMapping.eventHub;
    subscription[EVENT_HUB_PARTITION] = consumerGroupMapping.partition;
    subscription[CONSUMER_GROUP] = consumerGroupMapping.consumerGroup;
    string subscriberId = util:generatedSubscriberId(subscription.hubTopic, subscription.hubCallback);
    lock {
        // add the subscriber if subscription event received
        if !subscribersCache.hasKey(subscriberId) {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function retrieveTopicPartitionMapping(string hubTopic) returns types:EventHubPartition|error {
    string topicName = util:sanitizeTopicName(hubTopic);
    lock {
        types:TopicRegistration topicRegistration = registeredTopicsCache.get(topicName);
        types:EventHubPartition partitionMapping = check topicRegistration?.partitionMapping.ensureType();
        return partitionMapping.cloneReadOnly();
    }
}

isolated function processUnsubscription(json payload) returns error? {
    websubhub:VerifiedUnsubscription unsubscription = check payload.fromJsonWithType();
    string subscriberId = util:generatedSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    websubhub:VerifiedSubscription? subscription = removeSubscription(subscriberId);
    if subscription is websubhub:VerifiedSubscription {
        readonly & types:EventHubConsumerGroup consumerGroupMapping = {
            namespaceId: check subscription[NAMESPACE_ID].ensureType(),
            eventHub: check subscription[EVENT_HUB_NAME].ensureType(),
            partition: check subscription[EVENT_HUB_PARTITION].ensureType(),
            consumerGroup: check subscription[CONSUMER_GROUP].ensureType()
        };
        util:updateVacantConsumerGroupAssignment(consumerGroupMapping.cloneReadOnly());
    }
    lock {
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function removeSubscription(string subscriberId) returns websubhub:VerifiedSubscription? {
    lock {
        return subscribersCache.removeIfHasKey(subscriberId).cloneReadOnly();
    }
}

