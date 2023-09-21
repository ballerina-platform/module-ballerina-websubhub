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

import kafkaHub.types;
import kafkaHub.util;

# Flag to check whether to enable/disable security
public configurable boolean SECURITY_ON = true;

# Server ID is is used to uniquely identify each server 
# Each server must have a unique ID
public configurable string SERVER_ID = "server-1";

# IP and Port of the Kafka bootstrap node
public configurable string KAFKA_BOOTSTRAP_NODE = "localhost:9092";

# Kafka topic which is stores websub-events for this server
public configurable string WEBSUB_EVENTS_TOPIC = "websub-events";

# Consolidator HTTP endpoint to be used to retrieve current state-snapshot
public configurable string STATE_SNAPSHOT_ENDPOINT = "http://localhost:10001";

# The interval in which Kafka consumers wait for new messages
public configurable decimal POLLING_INTERVAL = 10;

# The period in which Kafka close method waits to complete
public configurable decimal GRACEFUL_CLOSE_PERIOD = 5;

# The port that is used to start the hub
public configurable int HUB_PORT = 9000;

# The period between retry requests
public configurable decimal MESSAGE_DELIVERY_RETRY_INTERVAL = 3;

# The maximum retry count
public configurable int MESSAGE_DELIVERY_COUNT = 3;

# The message delivery timeout
public configurable decimal MESSAGE_DELIVERY_TIMEOUT = 10;

# The base URL of IDP
public configurable types:OAuth2Config OAUTH2_CONFIG = ?;

public final string CONSTRUCTED_SERVER_ID = string `${SERVER_ID}-${util:generateRandomString()}`;
