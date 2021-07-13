// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerinax/kafka;
import ballerina/websubhub;
import ballerina/lang.value;
import ballerina/log;
import consolidatorService.config;
import consolidatorService.util;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;

isolated function startConsolidator() returns error? {
    do {
        while true {
            kafka:ConsumerRecord[] records = check conn:websubEventConsumer->poll(config:POLLING_INTERVAL);
            if records.length() > 0 {
                kafka:ConsumerRecord lastRecord = records.pop();
                string lastPersistedData = check string:fromBytes(lastRecord.value);
                error? result = processPersistedData(lastPersistedData);
                if result is error {
                    log:printError("Error occurred while processing received event ", 'error = result);
                }
            }
        }
    } on fail var e {
        _ = check conn:websubEventConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        return e;
    }
}

isolated function processPersistedData(string persistedData) returns error? {
    json payload = check value:fromJsonString(persistedData);
    string hubMode = check payload.hubMode;
    match hubMode {
        "register" => {
            check processTopicRegistration(payload);
        }
        "deregister" => {
            check processTopicDeregistration(payload);
        }
        "subscribe" => {
            check processSubscription(payload);
        }
        "unsubscribe" => {
            check processUnsubscription(payload);
        }
        _ => {
            return error(string `Error occurred while deserializing subscriber events with invalid hubMode [${hubMode}]`);
        }
    }
}

isolated function processTopicRegistration(json payload) returns error? {
    websubhub:TopicRegistration registration = check retrieveTopicRegistration(payload);
    string topicName = util:sanitizeTopicName(registration.topic);
    lock {
        // add the topic if topic-registration event received
        registeredTopicsCache[topicName] = registration.cloneReadOnly();
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function retrieveTopicRegistration(json payload) returns websubhub:TopicRegistration|error {
    string topic = check payload.topic;
    return {
        topic: topic
    };
}

isolated function processTopicDeregistration(json payload) returns error? {
    websubhub:TopicDeregistration deregistration = check retrieveTopicDeregistration(payload);
    string topicName = util:sanitizeTopicName(deregistration.topic);
    lock {
        // remove the topic if topic-deregistration event received
        _ = registeredTopicsCache.removeIfHasKey(topicName);
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function retrieveTopicDeregistration(json payload) returns websubhub:TopicDeregistration|error {
    string topic = check payload.topic;
    return {
        topic: topic
    };
}

isolated function processSubscription(json payload) returns error? {
    websubhub:VerifiedSubscription subscription = check payload.cloneWithType(websubhub:VerifiedSubscription);
    string groupName = util:generateGroupName(subscription.hubTopic, subscription.hubCallback);
    lock {
        // add the subscriber if subscription event received
        subscribersCache[groupName] = subscription.cloneReadOnly();
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function processUnsubscription(json payload) returns error? {
    websubhub:VerifiedUnsubscription unsubscription = check payload.cloneWithType(websubhub:VerifiedUnsubscription);
    string groupName = util:generateGroupName(unsubscription.hubTopic, unsubscription.hubCallback);
    lock {
        // remove the subscriber if the unsubscription event received
        _ = subscribersCache.removeIfHasKey(groupName);
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}
