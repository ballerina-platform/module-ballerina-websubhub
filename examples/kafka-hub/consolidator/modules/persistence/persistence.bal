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

import consolidatorService.config;
import consolidatorService.connections as conn;
import consolidatorService.types;

public isolated function persistWebsubEventsSnapshot(types:SystemStateSnapshot systemStateSnapshot) returns error? {
    json payload = systemStateSnapshot.toJson();
    check produceKafkaMessage(config:WEBSUB_EVENTS_SNAPSHOT_TOPIC, payload);
}

isolated function produceKafkaMessage(string topicName, json payload) returns error? {
    byte[] serializedContent = payload.toJsonString().toBytes();
    check conn:statePersistProducer->send({ topic: topicName, value: serializedContent });
    check conn:statePersistProducer->'flush();
}
