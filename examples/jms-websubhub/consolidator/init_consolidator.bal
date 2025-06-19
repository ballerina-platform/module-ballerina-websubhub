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
import ballerina/lang.runtime;
import ballerina/lang.value;
import ballerina/log;
import ballerinax/java.jms;

public function main() returns error? {
    // Initialize consolidator-service state
    error? stateSyncResult = syncSystemState();
    if stateSyncResult is error {
        common:logError("Error while syncing system state during startup", stateSyncResult, "FATAL");
        return;
    }

    // Start the HTTP endpoint
    http:Listener httpListener = check new (config:consolidatorHttpEpPort);
    runtime:registerListener(httpListener);
    check httpListener.attach(consolidatorService, "/consolidator");
    check httpListener.'start();
    log:printInfo("Starting Event Consolidator Service");

    // start the consolidator-service
    _ = start consolidateSystemState();
}

isolated function syncSystemState() returns error? {
    string subscriptionName = string `websub-events-snapshot-group-${config:constructedConsumerId}`;
    var [session, consumer] = check conn:createMessageConsumer(config:websubEventsSnapshotTopic, subscriptionName);
    do {
        while true {
            jms:BytesMessage? lastMessage = ();
            jms:Message? message = check consumer->receive(config:pollingInterval);
            if message is () {
                if lastMessage is jms:BytesMessage {
                    common:SystemStateSnapshot lastPersistedState = check value:fromJsonStringWithType(check string:fromBytes(lastMessage.content));
                    check persist:persistWebsubEventsSnapshot(lastPersistedState);
                }
                check session->unsubscribe(subscriptionName);
                return consumer->close();
            }

            if message !is jms:BytesMessage {
                // This particular consolidator implementation relies on JMS byte-messages, hence ignore anything else
                return;
            }

            lastMessage = message;
            check processWebsubEventsSnapshot(session, message);
        }
    } on fail error jmsError {
        common:logError("Error occurred while syncing system-state", jmsError, "FATAL");
        error? result = check consumer->close();
        if result is error {
            common:logError("Error occurred while gracefully closing JMS message-consumer", result);
        }
        return result;
    }
}

isolated function processWebsubEventsSnapshot(jms:Session session, jms:BytesMessage message) returns error? {
    do {
        common:SystemStateSnapshot stateSnapshot = check value:fromJsonStringWithType(check string:fromBytes(message.content));
        refreshTopicCache(stateSnapshot.topics);
        refreshSubscribersCache(stateSnapshot.subscriptions);
        check session->'commit();
    } on fail error e {
        check session->'rollback();
        return e;
    }
}
