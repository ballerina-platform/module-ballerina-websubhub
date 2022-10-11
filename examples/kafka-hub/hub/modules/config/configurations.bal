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

# Flag to check whether to enable/disable security
public configurable boolean SECURITY_ON = true;

# Server ID is is used to uniquely identify each server 
# Each server must have a unique ID
public configurable string SERVER_ID = "server-1";

# IP and Port of the Kafka bootstrap node
public configurable string SYSTEM_INFO_NAMESPACE = "localhost:9092";

# Azure Event Hub connection-string
public configurable string SYSTEM_INFO_NAMESPACE_CONNECTION_STRING = ?;

# Azure Event Hub related to the system-information
public configurable string SYSTEM_INFO_HUB = "system-info";

# Partitions in `system-info` EventHub which will get notified for websub topic registration/deregistration
public configurable int REGISTERED_WEBSUB_TOPICS_PARTITION = 0;

# Partitions in `system-info` EventHub which stores consolidated websub topics for the hub
public configurable int CONSOLIDATED_WEBSUB_TOPICS_PARTITION = 1;

# Partitions in `system-info` EventHub which will get notified for websub subscription/unsubscription
public configurable int WEBSUB_SUBSCRIBERS_PARTITION = 2;

# Partitions in `system-info` EventHub which is stores consolidated websub subscribers for this server
public configurable int CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION = 3;

# Partitions in `system-info` EventHub which will get notified for system events
public configurable int SYSTEM_EVENTS_PARTITION = 4;

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

# System Configurations Related to Azure Event Hub
public configurable types:NameSpaceConfiguration[] NAMESPACES = ?;

public configurable string[] EVENT_HUBS = ?;

public configurable int NUMBER_OF_PARTITIONS = ?;

public configurable string[] CONSUMER_GROUPS = ?;

public final readonly & string[] AVAILABLE_NAMESPACE_IDS = NAMESPACES.'map(ns => ns.namespaceId).cloneReadOnly();
