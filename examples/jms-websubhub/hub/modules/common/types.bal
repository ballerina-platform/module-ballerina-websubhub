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

import ballerina/websubhub;

public type StateSyncConfig record {|
    int maxItemLimit;
    decimal produceTimeout;
    decimal consumeTimeout;
|};

public type SystemEvent StateInitRequest|StatePersistCommand;

public type StateInitRequest record {|
    string serverId;
    string eventType = "init-state";
|};

public type StatePersistCommand record {|
    string serverId;
    int sequenceNumber;
    string eventType = "persist-state";
|};

public type SystemStateSnapshot record {|
    int lastProcessedSequenceNumber;
    websubhub:TopicRegistration[] topics;
    websubhub:VerifiedSubscription[] subscriptions;
|};

public type StaleSubscription record {|
    *websubhub:VerifiedSubscription;
    string status = "stale";
|};

public type SubscriptionDetails record {|
    string topic;
    string subscriberId;
|};

public type InvalidSubscriptionError distinct error<SubscriptionDetails>;

# WebSub Event type
public type EventType websubhub:TopicRegistration|websubhub:TopicDeregistration|websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription;

public type WebSubEvent record {|
    int sequenceNumber;
    EventType event;
|};
