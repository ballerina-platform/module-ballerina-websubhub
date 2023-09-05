// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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
import ballerina/log;

isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};

isolated function processWebsubTopicsSnapshotState(websubhub:TopicRegistration[] topics) returns error? {
    log:printDebug("Received latest state-snapshot for websub topics", newState = topics);
    foreach websubhub:TopicRegistration topicReg in topics {
        check processTopicRegistration(topicReg);
    }
}

isolated function processTopicRegistration(websubhub:TopicRegistration topicRegistration) returns error? {
    string topicName = topicRegistration.topic;
    log:printDebug(string `Topic registration event received for topic ${topicName}, hence adding the topic to the internal state`);
    lock {
        // add the topic if topic-registration event received
        if !registeredTopicsCache.hasKey(topicName) {
            registeredTopicsCache[topicName] = topicRegistration.cloneReadOnly();
        }
    }
}

isolated function processTopicDeregistration(websubhub:TopicDeregistration topicDeregistration) returns error? {
    string topicName = topicDeregistration.topic;
    log:printDebug(string `Topic deregistration event received for topic ${topicName}, hence removing the topic from the internal state`);
    lock {
        _ = registeredTopicsCache.removeIfHasKey(topicName);
    }
}

isolated function isValidTopic(string topicName) returns boolean {
    lock {
        return registeredTopicsCache.hasKey(topicName);
    }
}
