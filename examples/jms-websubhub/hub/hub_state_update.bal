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
import ballerina/log;
import ballerina/websubhub;
import ballerinax/java.jms;

const int MAX_SEQUENCE_NUMBER = 9223372036854775807;
const int MIN_SEQUENCE_NUMBER = 0;

isolated int lastProcessedMessageSequenceNumber = 0;

isolated function setLastProcessedSequenceNumber(int sequenceNumber) {
    lock {
        lastProcessedMessageSequenceNumber = sequenceNumber;
    }
}

isolated function getLastProcessedSequenceNumber() returns int {
    lock {
        return lastProcessedMessageSequenceNumber;
    }
}

isolated function getNextSequenceNumber() returns int {
    lock {
        if (lastProcessedMessageSequenceNumber >= MAX_SEQUENCE_NUMBER) {
            return MIN_SEQUENCE_NUMBER;
        } else {
            return lastProcessedMessageSequenceNumber + 1;
        }
    }
}

function isNewerSeqNumber(int newSeq, int currentSeq) returns boolean {
    int delta = newSeq - currentSeq;
    return delta > 0 || (currentSeq > newSeq && currentSeq - newSeq > MAX_SEQUENCE_NUMBER / 2);
}

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
    common:WebSubEvent message = check value:fromJsonStringWithType(persistedData);
    common:EventType event = message.event;
    if event is websubhub:TopicRegistration {
        check processTopicRegistration(event);
    } else if event is websubhub:TopicDeregistration {
        check processTopicDeregistration(event);
    } else if event is websubhub:VerifiedSubscription {
        check processSubscription(event);
    } else if event is websubhub:VerifiedUnsubscription {
        check processUnsubscription(event);
    } else {
        return error(string `Could not identify the event type for the event: ${event.toJsonString()}`);
    }
    setLastProcessedSequenceNumber(message.sequenceNumber);
}

isolated function persistStateSnapshot() returns error? {
    common:SystemStateSnapshot stateSnapshot = {
        lastProcessedSequenceNumber: getLastProcessedSequenceNumber(),
        topics: getTopics(),
        subscriptions: getSubscriptions()
    };
    log:printDebug("Currrent state", state = stateSnapshot);
    check persist:persistWebsubEventsSnapshot(stateSnapshot);
}
