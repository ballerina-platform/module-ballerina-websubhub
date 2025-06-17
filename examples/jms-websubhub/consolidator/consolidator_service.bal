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

import consolidatorsvc.common;
import consolidatorsvc.config;
import consolidatorsvc.connections as conn;
import consolidatorsvc.persistence as persist;

import ballerina/http;
import ballerina/lang.value;
import ballerina/log;
import ballerinax/java.jms;

http:Service consolidatorService = service object {
    isolated resource function get state\-snapshot() returns common:SystemStateSnapshot {
        common:SystemStateSnapshot stateSnapshot = {
            topics: getTopics(),
            subscriptions: getSubscriptions()
        };
        log:printInfo("Request received to retrieve state-snapshot, hence responding with the current state-snapshot", state = stateSnapshot);
        return stateSnapshot;
    }
};

isolated function consolidateSystemState() returns error? {
    do {
        while true {
            jms:Message? message = check conn:websubEventsConsumer->receive(config:pollingInterval);
            if message is () || message !is jms:BytesMessage {
                continue;
            }

            string lastPersistedData = check string:fromBytes(message.content);
            error? result = processPersistedData(lastPersistedData);
            if result is error {
                log:printError("Error occurred while processing received event ", 'error = result);
            }
        }
    } on fail var e {
        _ = check conn:websubEventsConsumer->close();
        return e;
    }
}

isolated function processPersistedData(string persistedData) returns error? {
    json payload = check value:fromJsonString(persistedData);
    string hubMode = check payload.hubMode;
    match hubMode {
        "register" => {
            check processTopicRegistration(payload);
        }
        "deregister" => {
            check processTopicDeregistration(payload);
        }
        "subscribe" => {
            check processSubscription(payload);
        }
        "unsubscribe" => {
            check processUnsubscription(payload);
        }
        _ => {
            return error(string `Error occurred while deserializing subscriber events with invalid hubMode [${hubMode}]`);
        }
    }
}

isolated function processStateUpdate() returns error? {
    common:SystemStateSnapshot stateSnapshot = {
        topics: getTopics(),
        subscriptions: getSubscriptions()
    };
    check persist:persistWebsubEventsSnapshot(stateSnapshot);
}
