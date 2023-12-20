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

import consolidatorService.util;
import ballerina/os;
import consolidatorService.types;

# IP and Port of the Kafka bootstrap node
public configurable string KAFKA_BOOTSTRAP_NODE = "localhost:9092";

public final string KAFKA_URL = os:getEnv("KAFKA_BOOTSTRAP_NODE") == "" ? KAFKA_BOOTSTRAP_NODE : os:getEnv("KAFKA_BOOTSTRAP_NODE");

# Kafka topic which stores websub-events for this server
public configurable string WEBSUB_EVENTS_TOPIC = "websub-events";

# Kafka topic which stores the current snapshot for the websub-events
public configurable string WEBSUB_EVENTS_SNAPSHOT_TOPIC = "websub-events-snapshot";

# The interval in which Kafka consumers wait for new messages
public configurable decimal POLLING_INTERVAL = 10;

# The period in which Kafka close method waits to complete
public configurable decimal GRACEFUL_CLOSE_PERIOD = 5;

# The MTLS configurations related to Kafka connection
public configurable types:KafkaMtlsConfig KAFKA_MTLS_CONFIG = ?;

# The port that is used to start the HTTP endpoint for consolidator
public configurable int CONSOLIDATOR_HTTP_ENDPOINT_PORT = 10001;

# Consumer group name for `websub-events` consumer
public final string WEBSUB_EVENTS_CONSUMER_GROUP = os:getEnv("WEBSUB_EVENTS_CONSUMER_GROUP") == "" ? constructSystemConsumerGroup("websub-events") : os:getEnv("WEBSUB_EVENTS_CONSUMER_GROUP");

# Consumer group name for `websub-events` consumer
public final string WEBSUB_EVENTS_SNAPSHOT_CONSUMER_GROUP = os:getEnv("WEBSUB_EVENTS_SNAPSHOT_CONSUMER_GROUP") == "" ? constructSystemConsumerGroup("websub-events-snapshot") : os:getEnv("WEBSUB_EVENTS_SNAPSHOT_CONSUMER_GROUP");

isolated function constructSystemConsumerGroup(string prefix) returns string {
    return string `${prefix}-receiver-consolidator-${util:generateRandomString()}`;
}
