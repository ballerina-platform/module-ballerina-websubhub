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

import ballerina/io;
import ballerina/os;
import kafkaHub.types;

# Flag to check whether to enable/disable security
public configurable boolean SECURITY_ON = true;

# Server ID is is used to uniquely identify each server 
# Each server must have a unique ID
# `SERVER_ID` value is retrieved from an environment variable.
public final string SERVER_ID = os:getEnv("SERVER_ID");

# IP and Port of the Kafka bootstrap node
public configurable string SYSTEM_INFO_NAMESPACE = "localhost:9092";

# Path to the file containing the system-info EventHub connection-string
public configurable string SYSTEM_INFO_NAMESPACE_CONNECTION_STRING_FILE = ?;

# system-inf EventHub connection-string
public final string SYSTEM_INFO_NAMESPACE_CONNECTION_STRING = check io:fileReadString(SYSTEM_INFO_NAMESPACE_CONNECTION_STRING_FILE);

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

# SSL keystore file path
public configurable string SSL_KEYSTORE_PATH = "./resources/keystore.p12";

# SSL keystore password
public configurable string KEYSTORE_PASSWORD_FILE = "./resources/keystore-password";

# JWKS endpoint to validate the JWT
public configurable string JWT_JWKS_ENDPOINT = "https://sts.preview-dv.choreo.dev/oauth2/jwks";

# The period between retry requests
public configurable decimal MESSAGE_DELIVERY_RETRY_INTERVAL = 3;

# The maximum retry count
public configurable int MESSAGE_DELIVERY_COUNT = 3;

# The message delivery timeout
public configurable decimal MESSAGE_DELIVERY_TIMEOUT = 10;

# System Configurations Related to Azure Event Hub
public configurable string[] EVENT_HUBS = ?;

public configurable int NUMBER_OF_PARTITIONS = ?;

public configurable string[] CONSUMER_GROUPS = ?;

public configurable string NAMESPACE_CONFIG_FILE = "./resources/namespace-config.json";

public final readonly & types:NameSpaceConfiguration[] NAMESPACES = check retrieveNamespaceConfig().cloneReadOnly();

public final readonly & string[] AVAILABLE_NAMESPACE_IDS = NAMESPACES.'map(ns => ns.namespaceId).cloneReadOnly();

isolated function retrieveNamespaceConfig() returns types:NameSpaceConfiguration[]|error {
    json configs = check io:fileReadJson(NAMESPACE_CONFIG_FILE);
    record {|
        string namespaceId;
        string namespace;
        string connectionStringFile;
    |}[] namespaceConfigs = check configs.fromJsonWithType();
    return namespaceConfigs.'map(
        config => {
            namespaceId: config.namespaceId,
            namespace: config.namespace,
            connectionString: check io:fileReadString(config.connectionStringFile)
        }
    );
}
