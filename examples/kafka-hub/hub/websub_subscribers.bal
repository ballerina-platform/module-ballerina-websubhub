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

import kafkaHub.config;
import kafkaHub.connections as conn;
import kafkaHub.persistence as persist;
import kafkaHub.types;
import kafkaHub.util;

import ballerina/lang.value;
import ballerina/log;
import ballerina/mime;
import ballerina/websubhub;
import ballerinax/kafka;

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
    websubhub:VerifiedSubscription? existingSubscription = getSubscription(subscriberId);
    boolean isFreshSubscription = existingSubscription is ();
    boolean isRenewingStaleSubscription = false;
    if existingSubscription is websubhub:VerifiedSubscription {
        isRenewingStaleSubscription = existingSubscription.hasKey(STATUS) && existingSubscription.get(STATUS) is STALE_STATE;
    }
    boolean isMarkingSubscriptionAsStale = subscription.hasKey(STATUS) && subscription.get(STATUS) is STALE_STATE;

    lock {
        // add the subscriber if subscription event received for a new subscription or a stale subscription, when renewing a stale subscription
        if isFreshSubscription || isRenewingStaleSubscription || isMarkingSubscriptionAsStale {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
    }
    string serverId = check subscription[SERVER_ID].ensureType();
    if serverId != config:SERVER_ID {
        log:printDebug(string `Subscriber ${subscriberId} does not belong to the current server, hence not starting the consumer`);
        return;
    }
    if !isFreshSubscription {
        log:printDebug(string `Subscriber ${subscriberId} is already available in the 'hub', hence not starting the consumer`);
        return;
    }
    if isMarkingSubscriptionAsStale {
        log:printDebug(string `Subscriber ${subscriberId} has been marked as stale, hence not starting the consumer`);
        return;
    }
    _ = @strand {thread: "any"} start pollForNewUpdates(subscriberId, subscription);
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
            readonly & kafka:BytesConsumerRecord[] records = check consumerEp->poll(config:POLLING_INTERVAL);
            if !isValidConsumer(topicName, subscriberId) {
                fail error(string `Subscriber with Id ${subscriberId} or topic ${topicName} is invalid`);
            }
            _ = check notifySubscribers(records, clientEp);
            check consumerEp->'commit();
        }
    } on fail var e {
        util:logError("Error occurred while sending notification to subscriber", e);
        kafka:Error? result = consumerEp->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }

        // Persist the subscription as a `stale` subscription whenever the content delivery fails
        types:StaleSubscription staleSubscription = {
            ...subscription
        };
        error? persistingResult = persist:addSubscription(staleSubscription.cloneReadOnly());
        if persistingResult is error {
            util:logError("Error occurred while persisting the stale subscription", persistingResult);
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

isolated function getSubscription(string subscriberId) returns websubhub:VerifiedSubscription? {
    lock {
        return subscribersCache[subscriberId].cloneReadOnly();
    }
}

isolated function notifySubscribers(kafka:BytesConsumerRecord[] records, websubhub:HubClient clientEp) returns error? {
    future<websubhub:ContentDistributionSuccess|error>[] distributionResponses = [];
    foreach var kafkaRecord in records {
        websubhub:ContentDistributionMessage message = check constructContentDistMsg(kafkaRecord);
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
}

isolated function waitAndGetResult(future<websubhub:ContentDistributionSuccess|error> response) returns websubhub:ContentDistributionSuccess|error {
    websubhub:ContentDistributionSuccess|error responseValue = wait response;
    return responseValue;
}

isolated function constructContentDistMsg(kafka:BytesConsumerRecord kafkaRecord) returns websubhub:ContentDistributionMessage|error {
    byte[] content = kafkaRecord.value;
    string message = check string:fromBytes(content);
    json payload = check value:fromJsonString(message);
    websubhub:ContentDistributionMessage distributionMsg = {
        content: payload,
        contentType: mime:APPLICATION_JSON
    };
    return distributionMsg;
}
