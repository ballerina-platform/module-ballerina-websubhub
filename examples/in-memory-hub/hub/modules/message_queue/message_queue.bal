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

import ballerina/time;
import ballerina/websubhub;

isolated websubhub:UpdateMessage[] queue = [];

# Add messages to the end of the `queue`.
#
# + message - Received content-update request
public isolated function enqueue(readonly & websubhub:UpdateMessage message) {
    lock {
        queue.push(message);
    }
}

# Retrieves the first message for the `topic` from the `queue`.
#
# + topic - Requested `topic`
# + return - `message_queue:Message` if a message is available for the `topic` or else `()`
public isolated function dequeue(readonly & string topic) returns readonly & websubhub:UpdateMessage? {
    lock {
        [int, websubhub:UpdateMessage][] availableMessages = queue.enumerate().filter(isolated function([int, websubhub:UpdateMessage] details) returns boolean {
            var [idx, msg] = details;
            return msg.hubTopic == topic;
        });
        if availableMessages.length() < 1 {
            return;
        }
        var [idx, msg] = availableMessages[0];
        return queue.remove(idx).cloneReadOnly();
    }
}

# Polls the queue for the first message for a `topic`.
#
# + topic - Requested `topic`  
# + timeout - Polling time-out
# + return - `Message` if a message is available for the `topic` or else `()`
public isolated function poll(string topic, decimal timeout = 10.0) returns readonly & websubhub:UpdateMessage? {
    readonly & websubhub:UpdateMessage? message = dequeue(topic);
    if message is websubhub:UpdateMessage {
        return message;
    }
    time:Utc expiaryTime = time:utcAddSeconds(time:utcNow(), timeout);
    while message is () && time:utcDiffSeconds(expiaryTime, time:utcNow()) > 0D {
        message = dequeue(topic);
    }
    return message;
}
