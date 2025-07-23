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
import jmshub.coordinator;
import jmshub.persistence as persist;

import ballerina/lang.runtime;
import ballerina/lang.value;
import ballerina/log;
import ballerinax/java.jms;

function init() returns error? {
    // Start `hub` node coordinator
    check coordinator:initCoordinator(persistStateSnapshot);
    while coordinator:isNodeReady() {
        runtime:sleep(2);
    }

    // Initialize the Hub
    check initHubState();
    // start hub state sync
    _ = start updateHubState();
    log:printInfo("Websubhub service started successfully");
}

isolated boolean systemInitCompleted = false;

function initHubState() returns error? {
    var [session, consumer] = conn:websubEventsSnapshotConnection;
    do {
        jms:BytesMessage? lastMessage = ();
        while true {
            jms:Message? message = check consumer->receive(config:pollingInterval);
            if message is () {
                if lastMessage is jms:BytesMessage {
                    common:SystemStateSnapshot lastPersistedState = check value:fromJsonStringWithType(check string:fromBytes(lastMessage.content));
                    log:printDebug("Processing system state snapshot", state = lastPersistedState);
                    check processWebsubTopicsSnapshotState(lastPersistedState.topics);
                    check processWebsubSubscriptionsSnapshotState(lastPersistedState.subscriptions);
                    check persist:persistWebsubEventsSnapshot(lastPersistedState);
                }
                check consumer->close();
                check session->close();
                lock {
                    systemInitCompleted = true;
                }
                return;
            }

            if message !is jms:BytesMessage {
                // This particular websubhub implementation relies on JMS byte-messages, hence ignore anything else
                continue;
            }
            lastMessage = message;
            check session->'commit();
        }
    } on fail error err {
        common:logError("Error occurred while initializing system-state", err, severity = "FATAL");
        check consumer->close();
        check session->close();
        return err;
    }
}

isolated function isSystemInitCompleted() returns boolean {
    lock {
        return systemInitCompleted;
    }
}
