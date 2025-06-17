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

import ballerinax/java.jms;

# Configurations related to the JMS provider connection
public configurable jms:ConnectionConfiguration brokerConfig = ?;

# JMS topic which stores websub-events for this server
public configurable string websubEventsTopic = "websub-events";

# JMS topic which stores the current snapshot for the websub-events
public configurable string websubEventsSnapshotTopic = "websub-events-snapshot";

# The interval in which JMS consumers wait for new messages
public configurable int pollingInterval = 10;

# The period in which JMS close method waits to complete
public configurable decimal gracefulClosePeriod = 5;

public final string constructedConsumerId = common:generateRandomString();

# The port that is used to start the HTTP endpoint for consolidator
public configurable int consolidatorHttpEpPort = 10001;
