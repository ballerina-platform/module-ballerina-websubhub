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
import consolidatorService.util;
import ballerina/lang.value;

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

isolated function deSerializeSubscribersMessage(string lastPersistedData) returns websubhub:VerifiedSubscription[]|error {
    websubhub:VerifiedSubscription[] currentSubscriptions = [];
    json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
    foreach var data in payload {
        websubhub:VerifiedSubscription subscription = check data.cloneWithType(websubhub:VerifiedSubscription);
        currentSubscriptions.push(subscription);
    }
    return currentSubscriptions;
}

isolated function refreshSubscribersCache(websubhub:VerifiedSubscription[] persistedSubscribers) {
    foreach var subscriber in persistedSubscribers {
        string groupName = util:generatedSubscriberId(subscriber.hubTopic, subscriber.hubCallback);
        lock {
            subscribersCache[groupName] = subscriber.cloneReadOnly();
        }
    }
}

isolated function processSubscription(json payload) returns error? {
    websubhub:VerifiedSubscription subscription = check payload.cloneWithType(websubhub:VerifiedSubscription);
    string subscriberId = util:generatedSubscriberId(subscription.hubTopic, subscription.hubCallback);
    lock {
        // add the subscriber if subscription event received
        if !subscribersCache.hasKey(subscriberId) {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
    }
    check processStateUpdate();
}

isolated function processUnsubscription(json payload) returns error? {
    websubhub:VerifiedUnsubscription unsubscription = check payload.cloneWithType(websubhub:VerifiedUnsubscription);
    string subscriberId = util:generatedSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    lock {
        // remove the subscriber if the unsubscription event received
        _ = subscribersCache.removeIfHasKey(subscriberId);
    }
    check processStateUpdate();
}

isolated function getSubscriptions() returns websubhub:VerifiedSubscription[] {
    lock {
        return subscribersCache.toArray().cloneReadOnly();
    }
}
