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
import ballerina/lang.value;
import ballerinax/kafka;
import ballerina/log;
import kafkaHub.config;
import kafkaHub.connections as conn;
import kafkaHub.util;
import ballerina/mime;

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

const string CONSUMER_GROUP = "consumerGroup";
const string CONSUMER_TOPIC_PARTITIONS = "topicPartitions";
const string SERVER_ID = "SERVER_ID";
const string STATUS = "status";
const string STALE_STATE = "stale";

function processWebsubSubscriptionsSnapshotState(websubhub:VerifiedSubscription[] subscriptions) returns error? {
    log:printDebug("Received latest state-snapshot for websub subscriptions", newState = subscriptions);
    foreach websubhub:VerifiedSubscription subscription in subscriptions {
        check processSubscription(subscription);
    }
}

function processSubscription(websubhub:VerifiedSubscription subscription) returns error? {
    string subscriberId = util:generateSubscriberId(subscription.hubTopic, subscription.hubCallback);
    log:printDebug(string `Subscription event received for the subscriber ${subscriberId}`);
    boolean subscriberAlreadyAvailable = true;
    lock {
        // add the subscriber if subscription event received
        if !subscribersCache.hasKey(subscriberId) {
            subscriberAlreadyAvailable = false;
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
    }
    string serverId = check subscription[SERVER_ID].ensureType();
    // if the subscription already exists in the `hub` instance, or the given subscription
    // does not belong to the `hub` instance do not start the consumer
    if subscriberAlreadyAvailable || serverId != config:SERVER_IDENTIFIER {
        log:printDebug(string `Subscriber ${subscriberId} is already available or it does not belong to the current server, hence not starting the consumer`, 
            subscriberAvailable = subscriberAlreadyAvailable, serverId = serverId);
        return;
    }
    _ = @strand {thread: "any"} start pollForNewUpdates( subscriberId, subscription);
}

isolated function processUnsubscription(websubhub:VerifiedUnsubscription unsubscription) returns error? {
    string subscriberId = util:generateSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    log:printDebug(string `Unsubscription event received for the subscriber ${subscriberId}, hence removing the subscriber from the internal state`);
    lock {
        _ = subscribersCache.removeIfHasKey(subscriberId);
    }
}

isolated function pollForNewUpdates(string subscriberId, websubhub:VerifiedSubscription subscription) returns error? {
    string consumerGroup = check value:ensureType(subscription[CONSUMER_GROUP]);
    int[]? topicPartitions = check getTopicPartitions(subscription);
    kafka:Consumer consumerEp = check conn:createMessageConsumer(subscription.hubTopic, consumerGroup, topicPartitions);
    websubhub:HubClient clientEp = check new (subscription, {
        retryConfig: {
            interval: config:MESSAGE_DELIVERY_RETRY_INTERVAL,
            count: config:MESSAGE_DELIVERY_COUNT,
            backOffFactor: 2.0,
            maxWaitInterval: 20,
            statusCodes: config:RETRYABLE_STATUS_CODES
        },
        timeout: config:MESSAGE_DELIVERY_TIMEOUT
    });
    do {
        while true {
            readonly & kafka:BytesConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
            if !isValidConsumer(subscription.hubTopic, subscriberId) {
                fail error(string `Subscriber with Id ${subscriberId} or topic ${subscription.hubTopic} is invalid`);
            }
            _ = check notifySubscribers(consumerEp, records, clientEp);
        }
    } on fail var e {
        util:logError("Error occurred while sending notification to subscriber", e);
        lock {
            _ = subscribersCache.removeIfHasKey(subscriberId);
        }
        kafka:Error? result = consumerEp->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    }
}

isolated function isValidConsumer(string topicName, string subscriberId) returns boolean {
    return isValidTopic(topicName) && isValidSubscription(subscriberId);
}

isolated function isValidSubscription(string subscriberId) returns boolean {
    lock {
        return subscribersCache.hasKey(subscriberId);
    }
}

isolated function notifySubscribers(kafka:Consumer consumerEp, kafka:BytesConsumerRecord[] records, websubhub:HubClient clientEp) returns error? {
    do {
        future<websubhub:ContentDistributionSuccess|error>[] distributionResponses = [];
        foreach var kafkaRecord in records {
            websubhub:ContentDistributionMessage message = check deSerializeKafkaRecord(kafkaRecord);
            future<websubhub:ContentDistributionSuccess|error> distributionResponse = start clientEp->notifyContentDistribution(message.cloneReadOnly());
            distributionResponses.push(distributionResponse);
        }

        boolean hasErrors = distributionResponses
            .'map(f => waitAndGetResult(f))
            .'map(r => r is error)
            .reduce(isolated function (boolean a, boolean b) returns boolean => a && b, false);
        
        if hasErrors {
            return error("Error occurred while distributing content to the subscriber");
        }
        return consumerEp->'commit();
    } on fail error e {
        log:printError("Error occurred while delivering messages to the subscriber", err = e.message());
    }
}

isolated function waitAndGetResult(future<websubhub:ContentDistributionSuccess|error> response) returns websubhub:ContentDistributionSuccess|error {
    websubhub:ContentDistributionSuccess|error responseValue = wait response;
    return responseValue;
}

isolated function deSerializeKafkaRecord(kafka:BytesConsumerRecord kafkaRecord) returns websubhub:ContentDistributionMessage|error {
    byte[] content = kafkaRecord.value;
    string message = check string:fromBytes(content);
    json payload =  check value:fromJsonString(message);
    websubhub:ContentDistributionMessage distributionMsg = {
        content: payload,
        contentType: mime:APPLICATION_JSON,
        headers: check getHeaders(kafkaRecord)
    };
    return distributionMsg;
}

isolated function getHeaders(kafka:BytesConsumerRecord kafkaRecord) returns map<string|string[]>|error {
    map<string|string[]> headers = {};
    foreach var ['key, value] in kafkaRecord.headers.entries().toArray() {
        if value is byte[] {
            headers['key] = check string:fromBytes(value);
        } else if value is byte[][] {
            string[] headerValue = value.'map(v => check string:fromBytes(v));
            headers['key] = headerValue;
        }
    }
    return headers;
}

isolated function getTopicPartitions(websubhub:VerifiedSubscription subscription) returns int[]|error? {
    if !subscription.hasKey(CONSUMER_TOPIC_PARTITIONS) {
        return;
    }
    // Kafka topic partitions will be a string with comma separated integers eg: "1,2,3,4"
    string partitionInfo = check value:ensureType(subscription[CONSUMER_TOPIC_PARTITIONS]);
    return re `,`.split(partitionInfo).'map(p => p.trim()).'map(p => check int:fromString(p));
}
