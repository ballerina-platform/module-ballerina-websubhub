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
import ballerina/lang.value;

isolated map<websubhub:TopicRegistration> registeredTopicsCache = {};

isolated function refreshTopicCache(websubhub:TopicRegistration[] persistedTopics) {
    foreach var topic in persistedTopics.cloneReadOnly() {
        lock {
            registeredTopicsCache[topic.topic] = topic.cloneReadOnly();
        }
    }
}

isolated function processTopicRegistration(json payload) returns error? {
    websubhub:TopicRegistration registration = check value:cloneWithType(payload);
    lock {
        // add the topic if topic-registration event received
        registeredTopicsCache[registration.topic] = registration.cloneReadOnly();
    }
    check processStateUpdate();
}

isolated function processTopicDeregistration(json payload) returns error? {
    websubhub:TopicDeregistration deregistration = check value:cloneWithType(payload);
    lock {
        // remove the topic if topic-deregistration event received
        _ = registeredTopicsCache.removeIfHasKey(deregistration.topic);
    }
    check processStateUpdate();
}

isolated function getTopics() returns websubhub:TopicRegistration[] {
    lock {
        return registeredTopicsCache.toArray().cloneReadOnly();
    }
}
