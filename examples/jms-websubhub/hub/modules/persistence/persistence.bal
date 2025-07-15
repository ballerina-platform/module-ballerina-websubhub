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

public isolated function persistSystemInitEvent(common:SystemInitEvent event) returns error? {
    json payload = event.toJson();
    check produceJmsMessage(config:systemEventsTopic, payload);
}

public isolated function addRegsiteredTopic(websubhub:TopicRegistration message) returns error? {
    check updateHubState(message);
}

public isolated function removeRegsiteredTopic(websubhub:TopicDeregistration message) returns error? {
    check updateHubState(message);
}

public isolated function addSubscription(websubhub:VerifiedSubscription message) returns error? {
    check updateHubState(message);
}

public isolated function removeSubscription(websubhub:VerifiedUnsubscription message) returns error? {
    check updateHubState(message);
}

public isolated function persistWebsubEventsSnapshot(common:SystemStateSnapshot systemStateSnapshot) returns error? {
    json payload = systemStateSnapshot.toJson();
    check produceJmsMessage(config:websubEventsSnapshotTopic, payload);
}

isolated function updateHubState(websubhub:TopicRegistration|websubhub:TopicDeregistration|
                                websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription message) returns error? {
    json jsonData = message.toJson();
    do {
        check produceJmsMessage(config:websubEventsTopic, jsonData);
    } on fail error e {
        return error(string `Failed to send updates for hub-state: ${e.message()}`, cause = e);
    }
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
