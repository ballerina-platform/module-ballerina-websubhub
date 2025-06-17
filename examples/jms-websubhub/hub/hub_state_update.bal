// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
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

import jmshub.common;
import jmshub.config;
import jmshub.connections as conn;

import ballerina/http;
import ballerina/websubhub;
import ballerinax/java.jms;
import ballerina/lang.value;

function initializeHubState() returns error? {
    http:Client stateSnapshotClient = check new (config:stateSnapshotEndpoint);
    do {
        common:SystemStateSnapshot systemStateSnapshot = check stateSnapshotClient->/consolidator/state\-snapshot;
        check processWebsubTopicsSnapshotState(systemStateSnapshot.topics);
        check processWebsubSubscriptionsSnapshotState(systemStateSnapshot.subscriptions);
        // Start hub-state update worker
        _ = start updateHubState();
    } on fail error httpError {
        common:logError("Error occurred while initializing the hub-state using the latest state-snapshot", httpError, severity = "FATAL");
        return httpError;
    }
}

function updateHubState() returns error? {
    while true {
        jms:Message? message = check conn:websubEventsConsumer->receive(config:pollingInterval);
        if message is () || message !is jms:BytesMessage {
            continue;
        }

        string lastPersistedData = check string:fromBytes(message.content);
        error? result = processStateUpdateEvent(lastPersistedData);
        if result is error {
            common:logError("Error occurred while processing state-update event", result, severity = "FATAL");
            return result;
        }
        check conn:websubEventsConsumer->acknowledge(message);
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
