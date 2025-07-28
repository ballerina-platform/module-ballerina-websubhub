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

import ballerina/websubhub;
import ballerinax/java.jms;

public isolated function persistStateInitRequest(common:StateInitRequest request) returns error? {
    json payload = request.toJson();
    check produceJmsMessage(config:systemEventsTopic, payload);
}

public isolated function persistStatePersistCommand(common:StatePersistCommand command) returns error? {
    json payload = command.toJson();
    check produceJmsMessage(config:systemEventsTopic, payload);
}

public isolated function updateHubState(common:WebSubEvent message) returns error? {
    json jsonData = message.toJson();
    do {
        check produceJmsMessage(config:websubEventsTopic, jsonData);
    } on fail error e {
        return error(string `Failed to send updates for hub-state: ${e.message()}`, cause = e);
    }
}

public isolated function persistWebsubEventsSnapshot(common:SystemStateSnapshot systemStateSnapshot) returns error? {
    json payload = systemStateSnapshot.toJson();
    check produceJmsMessage(config:websubEventsSnapshotTopic, payload);
}

public isolated function addUpdateMessage(string topic, websubhub:UpdateMessage message) returns error? {
    json payload = <json>message.content;
    check produceJmsMessage(topic, payload);
}

isolated function produceJmsMessage(string topic, json payload) returns error? {
    jms:BytesMessage message = {
        content: payload.toJsonString().toBytes()
    };
    check conn:statePersistProducer->sendTo({'type: jms:TOPIC, name: topic}, message);
}
