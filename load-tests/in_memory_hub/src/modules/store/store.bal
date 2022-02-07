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

import ballerina/websubhub;

isolated string[] topics = [];
isolated map<websubhub:Subscription[]> subscribers = {};

# Verifies whether the `topic` is available in the `hub`.
#
# + topic - The WebSub `topic`
# + return - `true` if the `topic` is currently available in the `hub` or else `false`
public isolated function isTopicAvailable(string topic) returns boolean {
    lock {
        return topics.filter(val => val == topic).length() == 1;
    }
}

# Adds the `topic` to the internal state of the `hub`
#
# + topicRegistration - The details regarding the topic-registration
public isolated function registerTopic(readonly & websubhub:TopicRegistration topicRegistration) {
    lock {
        topics.push(topicRegistration.topic);
    }
}

# Removes the `topic` from the internal state of the `hub`
#
# + topicDeregistration - The details regarding the topic-deregistration
public isolated function deregisterTopic(readonly & websubhub:TopicDeregistration topicDeregistration) {
    lock {
        int? idx = topics.indexOf(topicDeregistration.topic);
        if idx is int {
            _ = topics.remove(idx);
        }
    }
}

# Retrieves all available `topics` in the `hub`.
# 
# + return - `string[]` containing the all available `topics` in the `hub`
public isolated function retrieveAvailableTopics() returns readonly & string[] {
    lock {
        return topics.cloneReadOnly();
    }
}

# Verifies whether the `subscription` is available in the `hub`.
#
# + topic - The WebSub `topic`  
# + hubCallback - The `callback` provided by the `subscriber`
# + return - `true` if the `subscription` is currently available in the `hub` or else `false`
public isolated function isSubscriptionAvailale(string topic, string hubCallback) returns boolean {
    lock {
        return subscribers.hasKey(topic) &&
            subscribers.get(topic).filter(sub => sub.hubCallback == hubCallback).length() == 1;
    }
}

# Adds the `subscription` details to the internal state of the `hub`
#
# + subscriber - The details of the `subscriber`
public isolated function addSubscription(readonly & websubhub:Subscription subscriber) {
    lock {
        if subscribers.hasKey(subscriber.hubTopic) {
            subscribers.get(subscriber.hubTopic).push(subscriber);
        } else {
            websubhub:Subscription[] newSubscribers = [];
            newSubscribers.push(subscriber);
            subscribers[subscriber.hubTopic] = newSubscribers;
        }
    }
}

# Removes the `subscription` details from the internal state of the `hub` 
#
# + topic - The WebSub `topic`  
# + hubCallback - The `callback` provided by the `subscriber`
public isolated function removeSubscription(string topic, string hubCallback) {
    lock {
        if !subscribers.hasKey(topic) {
            return;
        }
        websubhub:Subscription[] updatedSubscriptions = subscribers.get(topic).filter(sub => sub.hubCallback != hubCallback);
        subscribers[topic] = updatedSubscriptions;
    }
}

# Retrieves the all the `subscriptions` related to a `topic`
#
# + topic - The WebSub `topic`  
# + return - `websubhub:Subscription[]` if the `subscriptions` are available for the `topic` or else `()`
public isolated function retrieveAvailableSubscriptions(string topic) returns readonly & websubhub:Subscription[]? {
    lock {
        return subscribers[topic].cloneReadOnly();
    }
}
