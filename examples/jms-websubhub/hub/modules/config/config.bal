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

import ballerinax/java.jms;

# Server ID is used to uniquely identify each server
# Each server must have a unique ID
public configurable string serverId = "server-1";

# The port that is used to start the hub
public configurable int hubPort = 9000;

# JMS topic which is stores websub-events for this server
public configurable string websubEventsTopic = "websub-events";

# Consolidator HTTP endpoint to be used to retrieve current state-snapshot
public configurable string stateSnapshotEndpoint = "http://localhost:10001";

# Enables automatic topic creation during the subscription process
# if the requested topic does not already exist.
public configurable boolean enableAutoTopicCreationOnSubscribe = true;

# Configurations related to the JMS provider connection
public configurable jms:ConnectionConfiguration brokerConfig = ?;

# The interval in which JMS consumers wait for new messages
public configurable int pollingInterval = 10;

# The period between retry requests
public configurable decimal messageDeliveryRetryInterval = 3;

# The maximum retry count
public configurable int messageDeliveryRetryCount = 3;

# The message delivery timeout
public configurable decimal messageDeliveryTimeout = 10;

public final string constructedServerId = string `${serverId}-${common:generateRandomString()}`;
