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

import ballerina/log;
import ballerina/websubhub;
import ballerina/io;
import ballerinax/kafka;
import ballerina/lang.value;
import kafkaHub.util;
import kafkaHub.connections as conn;
import ballerina/mime;

public function main() returns error? {
    log:printInfo("Starting Hub-Service");
    
    // Initialize the Hub
    _ = @strand { thread: "any" } start syncRegsisteredTopicsCache();
    _ = @strand { thread: "any" } start syncSubscribersCache();
    
    // Start the Hub
    websubhub:Listener hubListener = check new (9090);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}

isolated function syncRegsisteredTopicsCache() returns error? {
    while true {
        websubhub:TopicRegistration[]|error? topicDetails = getAvailableTopics();
        io:println("Executing topic-update with available topic details ", topicDetails is websubhub:TopicRegistration[]);
        if topicDetails is websubhub:TopicRegistration[] {
            lock {
                registeredTopicsCache.removeAll();
            }
            foreach var topic in topicDetails.cloneReadOnly() {
                string topicName = util:sanitizeTopicName(topic.topic);
                lock {
                    registeredTopicsCache[topicName] = topic.cloneReadOnly();
                }
            }
        }
    }
    _ = check conn:topicDetailsConsumer->close(5);
}

isolated function getAvailableTopics() returns websubhub:TopicRegistration[]|error? {
    kafka:ConsumerRecord[] records = check conn:topicDetailsConsumer->poll(10);
    if records.length() > 0 {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if lastPersistedData is string {
            websubhub:TopicRegistration[] currentTopics = [];
            log:printInfo("Last persisted-data set : ", message = lastPersistedData);
            json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
            foreach var data in payload {
                websubhub:TopicRegistration topic = check data.cloneWithType(websubhub:TopicRegistration);
                currentTopics.push(topic);
            }
            return currentTopics;
        } else {
            log:printError("Error occurred while retrieving topic-details ", err = lastPersistedData.message());
            return lastPersistedData;
        }
    }
}

function syncSubscribersCache() returns error? {
    while true {
        websubhub:VerifiedSubscription[]|error? subscriptionDetails = getAvailableSubscribers();
        io:println("Executing subscription-update with available subscription details ", subscriptionDetails is websubhub:VerifiedSubscription[]);
        if subscriptionDetails is websubhub:VerifiedSubscription[] {
            lock {
                subscribersCache.removeAll();
            }
            foreach var subscriber in subscriptionDetails {
                string groupName = util:generateGroupName(subscriber.hubTopic, subscriber.hubCallback);
                lock {
                    subscribersCache[groupName] = subscriber.cloneReadOnly();
                }
                kafka:Consumer consumerEp = check conn:createMessageConsumer(subscriber);
                websubhub:HubClient hubClientEp = check new (subscriber);
                _ = @strand { thread: "any" } start notifySubscriber(hubClientEp, consumerEp, groupName);
            }
        }
    }
    _ = check conn:subscriberDetailsConsumer->close(5);
}

isolated function getAvailableSubscribers() returns websubhub:VerifiedSubscription[]|error? {
    kafka:ConsumerRecord[] records = check conn:subscriberDetailsConsumer->poll(10);
    if records.length() > 0 {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if lastPersistedData is string {
            websubhub:VerifiedSubscription[] currentSubscriptions = [];
            log:printInfo("Last persisted-data set : ", message = lastPersistedData);
            json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
            foreach var data in payload {
                websubhub:VerifiedSubscription subscription = check data.cloneWithType(websubhub:VerifiedSubscription);
                currentSubscriptions.push(subscription);
            }
            return currentSubscriptions;
        } else {
            log:printError("Error occurred while retrieving subscriber-data ", err = lastPersistedData.message());
            return lastPersistedData;
        }
    } 
}

isolated function notifySubscriber(websubhub:HubClient clientEp, kafka:Consumer consumerEp, string groupName) returns error? {
    while true {
        kafka:ConsumerRecord[] records = check consumerEp->poll(10);
        boolean shouldProceed = true;
        lock {
            shouldProceed = subscribersCache.hasKey(groupName);
        }
        if !shouldProceed {
            break;
        }
        
        foreach var kafkaRecord in records {
            byte[] content = kafkaRecord.value;
            string|error message = string:fromBytes(content);
            if (message is string) {
                log:printInfo("Received message : ", message = message);
                json payload =  check value:fromJsonString(message);
                websubhub:ContentDistributionMessage distributionMsg = {
                    content: payload,
                    contentType: mime:APPLICATION_JSON
                };
                var publishResponse = clientEp->notifyContentDistribution(distributionMsg);
                if (publishResponse is error) {
                    log:printError("Error occurred while sending notification to subscriber ", err = publishResponse.message());
                } else {
                    _ = check consumerEp->commit();
                }
            } else {
                log:printError("Error occurred while retrieving message data", err = message.message());
            }
        }
    }
    _ = check consumerEp->close(5);
}
