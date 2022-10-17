// Copyright (c) 2022, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/log;
import ballerina/websubhub;
import consolidatorService.config;
import consolidatorService.util;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;
import consolidatorService.types;

isolated function startWebSubEventConsolidator() returns error? {
    do {
        while true {
            types:EventConsumerRecord[] records = check conn:websubEventConsumer->poll(config:POLLING_INTERVAL);
            foreach types:EventConsumerRecord currentRecord in records {
                error? result = processPersistedWebSubEventData(currentRecord.value);
                if result is error {
                    log:printError("Error occurred while processing received event ", 'error = result);
                }
            }
        }
    } on fail var e {
        log:printError("Error occurred while consuming records", 'error = e);
        _ = check conn:websubEventConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        return e;
    }
}

isolated function processPersistedWebSubEventData(json event) returns error? {
    string hubMode = check event.hubMode;
    match event.hubMode {
        "register" => {
            check processTopicRegistration(event);
        }
        "deregister" => {
            check processTopicDeregistration(event);
        }
        "subscribe" => {
            check processSubscription(event);
        }
        "unsubscribe" => {
            check processUnsubscription(event);
        }
        "restart" => {
            check processRestartEvent();
        }
        _ => {
            return error(string `Error occurred while deserializing subscriber events with invalid hubMode [${hubMode}]`);
        }
    }
}

isolated function processTopicRegistration(json payload) returns error? {
    types:TopicRegistration registration = check payload.fromJsonWithType();
    string topicName = util:sanitizeTopicName(registration.topic);
    lock {
        // add the topic if topic-registration event received
        registeredTopicsCache[topicName] = registration.cloneReadOnly();
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function processTopicDeregistration(json payload) returns error? {
    websubhub:TopicDeregistration deregistration = check payload.fromJsonWithType();
    string topicName = util:sanitizeTopicName(deregistration.topic);
    lock {
        // remove the topic if topic-deregistration event received
        _ = registeredTopicsCache.removeIfHasKey(topicName);
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function processSubscription(json payload) returns error? {
    websubhub:VerifiedSubscription subscription = check payload.fromJsonWithType();
    string subscriberId = util:generatedSubscriberId(subscription.hubTopic, subscription.hubCallback);
    lock {
        // add the subscriber if subscription event received
        if !subscribersCache.hasKey(subscriberId) {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function processUnsubscription(json payload) returns error? {
    websubhub:VerifiedUnsubscription unsubscription = check payload.fromJsonWithType();
    string subscriberId = util:generatedSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    lock {
        // remove the subscriber if the unsubscription event received
        _ = subscribersCache.removeIfHasKey(subscriberId);
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function processRestartEvent() returns error? {
    lock {
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
    lock {
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}
