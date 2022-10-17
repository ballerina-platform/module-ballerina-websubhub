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
import ballerina/websubhub;
import ballerinax/kafka;
import kafkaHub.util;
import kafkaHub.connections as conn;
import kafkaHub.types;
import ballerina/mime;
import kafkaHub.persistence as persist;
import kafkaHub.config;

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

const string NAMESPACE_ID = "namespaceId";
const string EVENT_HUB_NAME = "eventHubName";
const string EVENT_HUB_PARTITION = "eventHubPartition";
const string CONSUMER_GROUP = "consumerGroup";
const string SERVER_ID = "SERVER_ID";

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
                _ = check persist:addVacantEventHubConsumerGroupMapping(consumerGroupMapping);
            }
        }
    }
}

function startMissingSubscribers(websubhub:VerifiedSubscription[] persistedSubscribers) returns error? {
    foreach var subscriber in persistedSubscribers {
        string namespaceId = check subscriber[NAMESPACE_ID].ensureType();
        string consumerGroup = check subscriber[CONSUMER_GROUP].ensureType();
        readonly & types:EventHubConsumerGroup consumerGroupMapping = {
            namespaceId: namespaceId,
            eventHub: check subscriber[EVENT_HUB_NAME].ensureType(),
            partition: check subscriber[EVENT_HUB_PARTITION].ensureType(),
            consumerGroup: consumerGroup
        };
        // update the consumer-group mapping to identify the next available consumer-group
        _ = check util:updateNextConsumerGroup(consumerGroupMapping);
        string subscriberId = util:generateSubscriberId(subscriber.hubTopic, subscriber.hubCallback);
        boolean subscriberAvailable = true;
        lock {
            if !subscribersCache.hasKey(subscriberId) {
                subscribersCache[subscriberId] = subscriber.cloneReadOnly();
                subscriberAvailable = false;
            }
        }
        string serverId = check subscriber[SERVER_ID].ensureType();
        // if the subscription already exists in the `hub` instance, or the given subscription
        // does not belong to the `hub` instance do not start the consumer
        if subscriberAvailable || serverId != config:SERVER_ID {
            continue;
        }
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
        string topicName = util:sanitizeTopicName(subscriber.hubTopic);
        _ = @strand {thread: "any"} start pollForNewUpdates(hubClientEp, consumerEp, topicName, subscriberId);
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
    boolean subscriberAvailable = true;
    lock {
        subscriberAvailable = subscribersCache.hasKey(subscriberId);
    }
    return isValidTopic(topicName) && subscriberAvailable;
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
    }
    return consumerEp->'commit();
}
