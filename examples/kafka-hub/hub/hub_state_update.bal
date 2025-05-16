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

import ballerina/http;
import kafkaHub.config;
import kafkaHub.types;
import kafkaHub.util;
import ballerina/lang.value;
import ballerina/websubhub;
import kafkaHub.connections as conn;
import ballerinax/kafka;

function initializeHubState() returns error? {
    http:Client stateSnapshotClient = check new (config:STATE_SNAPSHOT_ENDPOINT);
    do {
        types:SystemStateSnapshot systemStateSnapshot = check stateSnapshotClient->/consolidator/state\-snapshot;
        check processWebsubTopicsSnapshotState(systemStateSnapshot.topics);
        check processWebsubSubscriptionsSnapshotState(systemStateSnapshot.subscriptions);
        // Start hub-state update worker
        _ = @strand {thread: "any"} start updateHubState();
    } on fail error httpError {
        util:logError("Error occurred while initializing the hub-state using the latest state-snapshot", httpError, severity = "FATAL");
        return httpError;
    }    
}

function updateHubState() returns error? {
    while true {
        kafka:BytesConsumerRecord[] records = check conn:websubEventsConsumer->poll(config:POLLING_INTERVAL);
        if records.length() <= 0 {
            continue;
        }
        foreach kafka:BytesConsumerRecord currentRecord in records {
            string lastPersistedData = check string:fromBytes(currentRecord.value);
            error? result = processStateUpdateEvent(lastPersistedData);
            if result is error {
                util:logError("Error occurred while processing state-update event", result, severity = "FATAL");
                return result;
            }
        }
    }
}

function processStateUpdateEvent(string persistedData) returns error? {
    json event = check value:fromJsonString(persistedData);
    string hubMode = check event.hubMode;
    match event.hubMode {
        "register" => {
            websubhub:TopicRegistration topicRegistration = check event.fromJsonWithType();
            check processTopicRegistration(topicRegistration);
        }
        "deregister" => {
            websubhub:TopicDeregistration topicDeregistration = check event.fromJsonWithType();
            check processTopicDeregistration(topicDeregistration);
        }
        "subscribe" => {
            websubhub:VerifiedSubscription subscription = check event.fromJsonWithType();
            check processSubscription(subscription);
        }
        "unsubscribe" => {
            websubhub:VerifiedUnsubscription unsubscription = check event.fromJsonWithType();
            check processUnsubscription(unsubscription);
        }
        _ => {
            return error(string `Error occurred while deserializing state-update events with invalid hubMode [${hubMode}]`);
        }
    }
}
