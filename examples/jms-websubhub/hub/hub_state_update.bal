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
import jmshub.persistence as persist;

import ballerina/lang.value;
import ballerina/websubhub;
import ballerinax/java.jms;

function updateHubState() returns error? {
    var [session, consumer] = conn:websubEventsConnection;
    while true {
        jms:Message? message = check consumer->receive(config:pollingInterval);
        if message is () {
            continue;
        }

        error? result = processStateUpdateMessage(session, message);
        if result is error {
            common:logError("Error occurred while processing state-update event", result, severity = "FATAL");
            check consumer->close();
            check session->close();
            return result;
        }
    }
}

function processStateUpdateMessage(jms:Session session, jms:Message message) returns error? {
    if message !is jms:BytesMessage {
        // This particular websubhub implementation relies on JMS byte-messages, hence ignore anything else
        return;
    }

    do {
        string lastPersistedData = check string:fromBytes(message.content);
        check processStateUpdateEvent(lastPersistedData);
        check session->'commit();
    } on fail error err {
        check session->'rollback();
        return err;
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

isolated function persistStateSnapshot() returns error? {
    common:SystemStateSnapshot stateSnapshot = {
        topics: getTopics(),
        subscriptions: getSubscriptions()
    };
    check persist:persistWebsubEventsSnapshot(stateSnapshot);
}
