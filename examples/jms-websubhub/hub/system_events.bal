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
import ballerinax/java.jms;

isolated function notifySystemInit() returns error? {
    common:SystemInitEvent initEvent = {
        serverId: config:serverId
    };
    check persist:persistSystemInitEvent(initEvent);
}

isolated function receiveSystemEvents() returns error? {
    var [session, consumer] = check conn:createMessageConsumer(
            config:systemEventsTopic, string `system-events-receiver`, true);
    while true {
        jms:Message? message = check consumer->receive(config:pollingInterval);
        if message is () {
            continue;
        }

        error? result = processSystemInitEvent(session, message);
        if result is error {
            common:logError("Error occurred while processing system-init event", result, severity = "FATAL");
            check consumer->close();
            check session->close();
            return result;
        }
    }
}

isolated function processSystemInitEvent(jms:Session session, jms:Message message) returns error? {
    if message !is jms:BytesMessage {
        // This particular websubhub implementation relies on JMS byte-messages, hence ignore anything else
        return;
    }

    do {
        common:SystemInitEvent systemInit = check value:fromJsonStringWithType(check string:fromBytes(message.content));
        log:printDebug("Processing system-init event", event = systemInit);
        if config:serverId !== systemInit.serverId {
            check persistStateSnapshot();
        }
        check session->'commit();
    } on fail error err {
        check session->'rollback();
        return err;
    }
}
