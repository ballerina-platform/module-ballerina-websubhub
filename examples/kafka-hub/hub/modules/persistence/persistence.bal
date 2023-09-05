// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/websubhub;
import kafkaHub.config;
import kafkaHub.connections as conn;

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

isolated function updateHubState(websubhub:TopicRegistration|websubhub:TopicDeregistration|
                                websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription message) returns error? {
    json jsonData = message.toJson();
    do {
        check produceKafkaMessage(config:WEBSUB_EVENTS_TOPIC, jsonData);
    } on fail error e {
        return error (string `Failed to send updates for hub-state: ${e.message()}`, cause = e);
    }
}

public isolated function addUpdateMessage(string topicName, websubhub:UpdateMessage message) returns error? {
    json payload = <json>message.content;
    check produceKafkaMessage(topicName, payload);
}

isolated function produceKafkaMessage(string topicName, json payload) returns error? {
    byte[] serializedContent = payload.toJsonString().toBytes();
    check conn:statePersistProducer->send({ topic: topicName, value: serializedContent });
    check conn:statePersistProducer->'flush();
}
