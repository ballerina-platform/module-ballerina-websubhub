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
import jmshub.config;

import ballerina/log;
import ballerina/websubhub;

import xlibb/pipe;

final pipe:Pipe regTopicStateSync = new ('limit = config:stateSyncConfig.maxItemLimit);
isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};

isolated function processWebsubTopicsSnapshotState(websubhub:TopicRegistration[] topics) returns error? {
    log:printDebug("Received latest state-snapshot for websub topics", newState = topics);
    foreach websubhub:TopicRegistration topicReg in topics {
        check processTopicRegistration(topicReg, true);
    }
}

isolated function processTopicRegistration(websubhub:TopicRegistration topicRegistration, boolean stateInit = false) returns error? {
    string topic = topicRegistration.topic;
    log:printDebug(string `Topic registration event received for topic ${topic}, hence adding the topic to the internal state`);
    error? stateSync = regTopicStateSync.produce(topic, config:stateSyncConfig.produceTimeout);
    if stateSync is error {
        common:logError("Error occurred while syncing register-topic state", stateSync);
    }
    lock {
        // add the topic if topic-registration event received
        if !registeredTopicsCache.hasKey(topic) {
            registeredTopicsCache[topic] = topicRegistration.cloneReadOnly();
        }
    }

    if stateInit {
        return;
    }
    check persistStateSnapshot();
}

isolated function processTopicDeregistration(websubhub:TopicDeregistration topicDeregistration, boolean stateInit = false) returns error? {
    string topic = topicDeregistration.topic;
    log:printDebug(string `Topic deregistration event received for topic ${topic}, hence removing the topic from the internal state`);
    lock {
        _ = registeredTopicsCache.removeIfHasKey(topic);
    }

    if stateInit {
        return;
    }
    check persistStateSnapshot();
}

isolated function isTopicAvailable(string topic, boolean skipStateSync = false) returns boolean {
    boolean hasTopic = false;
    lock {
        hasTopic = registeredTopicsCache.hasKey(topic);
    }
    if skipStateSync || hasTopic {
        return hasTopic;
    }
    string|error latestRegisteredTopic = regTopicStateSync.consume(config:stateSyncConfig.consumeTimeout);
    return topic === latestRegisteredTopic;
}

isolated function getTopics() returns websubhub:TopicRegistration[] {
    lock {
        return registeredTopicsCache.toArray().cloneReadOnly();
    }
}
