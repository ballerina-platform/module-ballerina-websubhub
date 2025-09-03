// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
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

import ballerina/os;
import ballerina/time;
import ballerina/websub;

isolated function getCustomParams() returns map<string> {
    if consumerGroup !is () {
        return {
            consumerGroup: consumerGroup ?: ""
        };
    }

    if topicPartitions !is () {
        return {
            topicPartitions: topicPartitions ?: ""
        };
    }

    return {};
}

isolated function getListener() returns websub:Listener|error {
    if os:getEnv("SVC_PORT") == "" {
        return new (9100, host = os:getEnv("HOSTNAME"));
    }
    return new (check int:fromString(os:getEnv("SVC_PORT")), host = os:getEnv("HOSTNAME"));
}

service class SubscriberService {
    *websub:SubscriberService;

    remote function onEventNotification(websub:ContentDistributionMessage event) returns error? {
        int currentMessageCount = incrementAndGet();
        if currentMessageCount >= 1 && getStartTime() is () {
            setStartTime(time:utcNow());
        }
        if currentMessageCount >= numberOfRequests {
            setEndTime(time:utcNow());
        }
    }
}
