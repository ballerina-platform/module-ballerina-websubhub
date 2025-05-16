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
    if subscriberAlreadyAvailable || serverId != config:SERVER_ID {
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
    string topicName = util:sanitizeTopicName(subscription.hubTopic);
    string consumerGroup = check value:ensureType(subscription[CONSUMER_GROUP]);
    kafka:Consumer consumerEp = check conn:createMessageConsumer(topicName, consumerGroup);
    websubhub:HubClient clientEp = check new (subscription, {
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
    do {
        while true {
            kafka:BytesConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
            if !isValidConsumer(topicName, subscriberId) {
                fail error(string `Subscriber with Id ${subscriberId} or topic ${topicName} is invalid`);
            }
            _ = check notifySubscribers(records, clientEp, consumerEp);
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

isolated function notifySubscribers(kafka:BytesConsumerRecord[] records, websubhub:HubClient clientEp, kafka:Consumer consumerEp) returns error? {
    foreach var kafkaRecord in records {
        var message = deSerializeKafkaRecord(kafkaRecord);
        if message is websubhub:ContentDistributionMessage {
            var response = clientEp->notifyContentDistribution(message);
            if response is websubhub:ContentDistributionSuccess {
                _ = check consumerEp->commit();
                return;   
            }
            return response;
        } else {
            log:printError("Error occurred while retrieving message data", err = message.message());
        }
    }
}

isolated function deSerializeKafkaRecord(kafka:BytesConsumerRecord kafkaRecord) returns websubhub:ContentDistributionMessage|error {
    byte[] content = kafkaRecord.value;
    string message = check string:fromBytes(content);
    json payload =  check value:fromJsonString(message);
    websubhub:ContentDistributionMessage distributionMsg = {
        content: payload,
        contentType: mime:APPLICATION_JSON
    };
    return distributionMsg;
}
