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

import ballerinax/java.jms;

public isolated function persistWebsubEventsSnapshot(common:SystemStateSnapshot systemStateSnapshot) returns error? {
    json payload = systemStateSnapshot.toJson();
    check produceJmsMessage(config:websubEventsSnapshotTopic, payload);
}

isolated function produceJmsMessage(string topic, json payload) returns error? {
    jms:BytesMessage message = {
        content: payload.toJsonString().toBytes()
    };
    check conn:statePersistProducer->sendTo({'type: jms:TOPIC, name: topic}, message);
}
