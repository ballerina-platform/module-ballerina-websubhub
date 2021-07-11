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

import ballerinax/kafka;
import ballerina/websubhub;
import ballerina/lang.value;
import ballerina/log;
import consolidatorService.config;
import consolidatorService.util;
import consolidatorService.connections as conn;

public function main() returns error? {
    // Initialize consolidator-service
    check syncSubscribersCache();
}

function syncSubscribersCache() returns error? {
    do {
        websubhub:VerifiedSubscription[]|error? persistedSubscribers = getPersistedSubscribers();
        if persistedSubscribers is websubhub:VerifiedSubscription[] {
            refreshSubscribersCache(persistedSubscribers);
        }
    } on fail var e {
        _ = check conn:consolidatedSubscriberConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        return e;
    } 
}

function getPersistedSubscribers() returns websubhub:VerifiedSubscription[]|error? {
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
    foreach var subscriber in persistedSubscribers {
        string groupName = util:generateGroupName(subscriber.hubTopic, subscriber.hubCallback);
        lock {
            subscribersCache[groupName] = subscriber.cloneReadOnly();
        }
    }
}