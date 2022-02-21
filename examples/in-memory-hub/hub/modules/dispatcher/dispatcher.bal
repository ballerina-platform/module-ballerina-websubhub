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

import in_memory_hub.message_queue as mq;
import in_memory_hub.store;
import ballerina/websubhub;

type ClientDetails record {|
    readonly & websubhub:Subscription subscription;
    websubhub:HubClient clientEp;
|};

isolated map<ClientDetails[]> dispatcherClients = {};

# Updates the internal state of the content dispatcher.
# 
# + return - `error` if there is any exception occurred while executing the update
public function syncDispatcherState() returns error? {
    while true {
        readonly & string[] availableTopics = store:retrieveAvailableTopics();
        lock {
            // remove unavailable topics from the dispatchers
            foreach string dispatcher in dispatcherClients.keys() {
                if availableTopics.indexOf(dispatcher) is () {
                    lock {
                        _ = dispatcherClients.removeIfHasKey(dispatcher);
                    }
                }
            }
        }

        // update the dispatcher-clients for available topics and start the message consuming for new `topics` 
        foreach string topic in availableTopics {
            boolean newTopic = false;
            lock {
                newTopic = !dispatcherClients.hasKey(topic);
            }
            if newTopic {
                _ = @strand {thread: "any"} start consumeMessages(topic);
            }

            readonly & websubhub:Subscription[]? subscribers = store:retrieveAvailableSubscriptions(topic);
            if subscribers is () {
                lock {
                    dispatcherClients[topic] = [];
                }
                continue;
            }

            lock {
                ClientDetails[] clientDetails = newTopic ? [] : retrieveValidClientDetails(subscribers, dispatcherClients.get(topic));
                readonly & websubhub:Subscription[] newSubscribers = retrieveNewSubscribers(subscribers, clientDetails);
                foreach var subscriber in newSubscribers {
                    websubhub:HubClient clientEp = check new (subscriber);
                    clientDetails.push({subscription: subscriber, clientEp: clientEp});
                }
                dispatcherClients[topic] = clientDetails;
            }
        }
    }
}

isolated function retrieveValidClientDetails(websubhub:Subscription[] availableSubscriptions, ClientDetails[] availableClientDetails) returns ClientDetails[] {
    final readonly & string[] subscriberCallbacks = availableSubscriptions.'map(sub => sub.hubCallback).cloneReadOnly();
    return availableClientDetails.filter(cd => subscriberCallbacks.indexOf(cd.subscription.hubCallback) is int);
}

isolated function retrieveNewSubscribers(websubhub:Subscription[] availableSubscriptions, ClientDetails[] availableClientDetails) returns readonly & websubhub:Subscription[] {
    final readonly & string[] subscriberCallbacksForClients = availableClientDetails.'map(cd => cd.subscription.hubCallback).cloneReadOnly();
    return availableSubscriptions.filter(sub => subscriberCallbacksForClients.indexOf(sub.hubCallback) == ()).cloneReadOnly();
}

isolated function consumeMessages(string topic) {
    while store:isTopicAvailable(topic) {
        readonly & websubhub:UpdateMessage? message = mq:poll(topic);
        if message is () {
            continue;
        }
        readonly & websubhub:ContentDistributionMessage payload = constructContentDistributionMessage(message);
        lock {
            if dispatcherClients.hasKey(topic) {
                foreach ClientDetails clientDetails in dispatcherClients.get(topic) {
                    readonly & websubhub:Subscription subscription = clientDetails.subscription;
                    // skip invalid subscriptions
                    if !store:isSubscriptionAvailale(subscription.hubTopic, subscription.hubCallback) {
                        continue;
                    }
                    websubhub:HubClient clientEp = clientDetails.clientEp;
                    websubhub:ContentDistributionSuccess|error response = clientEp->notifyContentDistribution(payload);
                    if response is websubhub:SubscriptionDeletedError {
                        store:removeSubscription(subscription.hubTopic, subscription.hubCallback);
                    }
                }
            }
        }
    }
}

isolated function constructContentDistributionMessage(readonly & websubhub:UpdateMessage message) returns readonly & websubhub:ContentDistributionMessage {
    return {
        contentType: message.contentType,
        content: message.content
    };
}
