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
import consolidatorService.config;
import consolidatorService.connections as conn;
import consolidatorService.util;
import consolidatorService.persistence as persist;
import ballerina/lang.value;
import ballerina/log;
import ballerinax/kafka;

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

isolated function syncSubscribersCache() {
    do {
        websubhub:VerifiedSubscription[]? persistedSubscribers = check getPersistedSubscribers();
        if persistedSubscribers is websubhub:VerifiedSubscription[] {
            refreshSubscribersCache(persistedSubscribers);
        }
    } on fail var e {
        log:printError("Error occurred while syncing subscribers-cache ", err = e.message());
        kafka:Error? result = conn:consolidatedSubscriberConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        if result is kafka:Error {
            log:printError("Error occurred while gracefully closing kafka-consumer", err = result.message());
        }
    } 
}

isolated function getPersistedSubscribers() returns websubhub:VerifiedSubscription[]|error? {
    kafka:ConsumerRecord[] records = check conn:consolidatedSubscriberConsumer->poll(config:POLLING_INTERVAL);
    if records.length() > 0 {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if lastPersistedData is string {
            return deSerializeSubscribersMessage(lastPersistedData);
        } else {
            log:printError("Error occurred while retrieving consolidated-subscriber-details ", err = lastPersistedData.message());
            return lastPersistedData;
        }
    }
    return;
}

isolated function deSerializeSubscribersMessage(string lastPersistedData) returns websubhub:VerifiedSubscription[]|error {
    websubhub:VerifiedSubscription[] currentSubscriptions = [];
    json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
    foreach var data in payload {
        websubhub:VerifiedSubscription subscription = check data.cloneWithType(websubhub:VerifiedSubscription);
        currentSubscriptions.push(subscription);
    }
    return currentSubscriptions;
}

isolated function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) {
    foreach var subscriber in persistedSubscribers {
        string groupName = util:generatedSubscriberId(subscriber.hubTopic, subscriber.hubCallback);
        lock {
            subscribersCache[groupName] = subscriber.cloneReadOnly();
        }
    }
}

isolated function processSubscription(json payload) returns error? {
    websubhub:VerifiedSubscription subscription = check payload.cloneWithType(websubhub:VerifiedSubscription);
    string subscriberId = util:generatedSubscriberId(subscription.hubTopic, subscription.hubCallback);
    lock {
        // add the subscriber if subscription event received
        if !subscribersCache.hasKey(subscriberId) {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function processUnsubscription(json payload) returns error? {
    websubhub:VerifiedUnsubscription unsubscription = check payload.cloneWithType(websubhub:VerifiedUnsubscription);
    string subscriberId = util:generatedSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    lock {
        // remove the subscriber if the unsubscription event received
        _ = subscribersCache.removeIfHasKey(subscriberId);
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function getSubscriptions() returns websubhub:VerifiedSubscription[] {
    lock {
        return subscribersCache.toArray().cloneReadOnly();
    }
}
