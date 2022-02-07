// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/lang.runtime;
import ballerina/websubhub;

public type Message readonly & record {|
    string & readonly topic;
    readonly & websubhub:ContentDistributionMessage payload;
|};

isolated Message[] queue = [];

public isolated function enqueue(readonly & websubhub:UpdateMessage request) {
    Message msg = {
        topic: request.hubTopic,
        payload: {
            contentType: request.contentType,
            content: request.content
        }
    };
    lock {
        queue.push(msg);
    }
}

public isolated function dequeue(readonly & string topic) returns Message? {
    lock {
        [int, Message][] availableMessages = queue.enumerate().filter(isolated function([int, Message] details) returns boolean {
            var [idx, msg] = details;
            return msg.topic == topic;
        });
        if availableMessages.length() < 1 {
            return;
        }
        var [idx, msg] = availableMessages[0];
        return queue.remove(idx);
    }
}

public isolated function poll(string topic, decimal timeout = 10.0) returns Message? {
    Message? message = dequeue(topic);
    if message is Message {
        return message;
    }
    runtime:sleep(timeout);
    return dequeue(topic);
}
