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

import ballerina/lang.value;
import ballerinax/java.jms;

import wso2/mi;

@mi:Operation
public isolated function getStateSnapshot() returns json {
    common:SystemStateSnapshot stateSnapshot = constructStateSnapshot();
    return stateSnapshot.toJson();
}

function consolidateSystemState() returns error? {
    var [session, consumer] = conn:websubEventsConnection;
    while true {
        jms:Message? message = check consumer->receive(config:pollingInterval);
        if message is () {
            continue;
        }

        error? result = processStateUpdateMessage(session, message);
        if result is error {
            common:logError("Error occurred while processing received event ", result, severity = "FATAL");
            check consumer->close();
            check result;
        }
    }
}

isolated function processStateUpdateMessage(jms:Session session, jms:Message message) returns error? {
    if message !is jms:BytesMessage {
        // This particular consolidator implementation relies on JMS byte-messages, hence ignore anything else
        return;
    }

    do {
        string lastPersistedData = check string:fromBytes(message.content);
        check processPersistedData(lastPersistedData);
        check session->'commit();
    } on fail error err {
        check session->'rollback();
        return err;
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

isolated function constructStateSnapshot() returns common:SystemStateSnapshot => {
    topics: getTopics(),
    subscriptions: getSubscriptions()
};
