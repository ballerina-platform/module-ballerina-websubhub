// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
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

import jmshub.common;
import jmshub.config;
import jmshub.connections as conn;
import jmshub.persistence as persist;

import ballerina/lang.value;
import ballerina/log;
import ballerina/mime;
import ballerina/websubhub;
import ballerinax/java.jms;

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

const string SUBSCRIPTION_NAME = "subscriptionName";
const string SERVER_ID = "SERVER_ID";
const string STATUS = "status";
const string STALE_STATE = "stale";

function processWebsubSubscriptionsSnapshotState(websubhub:VerifiedSubscription[] subscriptions) returns error? {
    log:printDebug("Received latest state-snapshot for websub subscriptions", newState = subscriptions);
    foreach websubhub:VerifiedSubscription subscription in subscriptions {
        check processSubscription(subscription);
    }
}

function processSubscription(websubhub:VerifiedSubscription subscription) returns error? {
    string subscriberId = common:generateSubscriberId(subscription.hubTopic, subscription.hubCallback);
    log:printDebug(string `Subscription event received for the subscriber ${subscriberId}`);
    websubhub:VerifiedSubscription? existingSubscription = getSubscription(subscriberId);
    boolean isFreshSubscription = existingSubscription is ();
    boolean isRenewingStaleSubscription = false;
    if existingSubscription is websubhub:VerifiedSubscription {
        isRenewingStaleSubscription = existingSubscription.hasKey(STATUS) && existingSubscription.get(STATUS) is STALE_STATE;
    }
    boolean isMarkingSubscriptionAsStale = subscription.hasKey(STATUS) && subscription.get(STATUS) is STALE_STATE;

    lock {
        // add the subscriber if subscription event received for a new subscription or a stale subscription, when renewing a stale subscription
        if isFreshSubscription || isRenewingStaleSubscription || isMarkingSubscriptionAsStale {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
    }
    string serverId = check subscription[SERVER_ID].ensureType();
    if serverId != config:serverId {
        log:printDebug(string `Subscriber ${subscriberId} does not belong to the current server, hence not starting the consumer`);
        return;
    }

    if !isFreshSubscription && !isRenewingStaleSubscription {
        log:printDebug(string `Subscriber ${subscriberId} is already available in the 'hub', hence not starting the consumer`, existing = existingSubscription.toJsonString());
        return;
    }
    if isMarkingSubscriptionAsStale {
        log:printDebug(string `Subscriber ${subscriberId} has been marked as stale, hence not starting the consumer`);
        return;
    }
    _ = start pollForNewUpdates(subscriberId, subscription);
}

isolated function processUnsubscription(websubhub:VerifiedUnsubscription unsubscription) returns error? {
    string subscriberId = common:generateSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    log:printDebug(string `Unsubscription event received for the subscriber ${subscriberId}, hence removing the subscriber from the internal state`);
    lock {
        _ = subscribersCache.removeIfHasKey(subscriberId);
    }
}

isolated function pollForNewUpdates(string subscriberId, websubhub:VerifiedSubscription subscription) returns error? {
    string topic = subscription.hubTopic;
    string subscriptionName = check value:ensureType(subscription[SUBSCRIPTION_NAME]);
    var [session, consumerEp] = check conn:createMessageConsumer(topic, subscriptionName);
    websubhub:HubClient clientEp = check new (subscription, {
        retryConfig: {
            interval: config:messageDeliveryRetryInterval,
            count: config:messageDeliveryRetryCount,
            backOffFactor: 2.0,
            maxWaitInterval: 20
        },
        timeout: config:messageDeliveryTimeout
    });
    do {
        while true {
            if !isValidConsumer(topic, subscriberId) {
                fail error common:InvalidSubscriptionError(
                    string `Subscriber with Id ${subscriberId} or topic ${topic} is invalid`, 
                    topic = topic, subscriberId = subscriberId
                );
            }

            jms:Message? message = check consumerEp->receive(config:pollingInterval);
            if message is () {
                continue;
            }

            check processSubscriberNotification(session, message, clientEp);
        }
    } on fail error e {
        common:logError("Error occurred while sending notification to subscriber", e);
        jms:Error? result = consumerEp->close();
        if result is jms:Error {
            common:logError("Error occurred while gracefully closing JMS message consumer", result);
        }

        if e is common:InvalidSubscriptionError {
            return session->unsubscribe(subscriptionName);
        }

        // If subscription-deleted error received, remove the subscription
        if e is websubhub:SubscriptionDeletedError {
            check session->unsubscribe(subscriptionName);
            websubhub:VerifiedUnsubscription unsubscription = {
                hubMode: "unsubscribe",
                hubTopic: subscription.hubTopic,
                hubCallback: subscription.hubCallback,
                hubSecret: subscription.hubSecret
            };
            error? persistingResult = persist:removeSubscription(unsubscription);
            if persistingResult is error {
                common:logError(
                        "Error occurred while removing the subscription", persistingResult, subscription = unsubscription);
            }
            return;
        }

        // Persist the subscription as a `stale` subscription whenever the content delivery fails
        common:StaleSubscription staleSubscription = {
            ...subscription
        };
        error? persistingResult = persist:addSubscription(staleSubscription);
        if persistingResult is error {
            common:logError(
                    "Error occurred while persisting the stale subscription", persistingResult, subscription = staleSubscription);
        }
    }
}

isolated function processSubscriberNotification(jms:Session session, jms:Message message, websubhub:HubClient clientEp) returns error? {
    if message !is jms:BytesMessage {
        // This particular websubhub implementation relies on JMS byte-messages, hence ignore anything else
        return;
    }
    do {
        websubhub:ContentDistributionMessage contentDistributionMsg = check constructContentDistMsg(message);
        _ = check clientEp->notifyContentDistribution(contentDistributionMsg);
        check session->'commit();
    } on fail error err {
        check session->'rollback();
        return err;
    }
}

isolated function constructContentDistMsg(jms:BytesMessage byteMessage) returns websubhub:ContentDistributionMessage|error {
    string message = check string:fromBytes(byteMessage.content);
    json payload = check value:fromJsonString(message);
    websubhub:ContentDistributionMessage distributionMsg = {
        content: payload,
        contentType: mime:APPLICATION_JSON
    };
    return distributionMsg;
}

isolated function isValidConsumer(string topicName, string subscriberId) returns boolean {
    return isTopicAvailable(topicName) && isSubscriptionAvailable(subscriberId);
}

isolated function getSubscription(string subscriberId) returns websubhub:VerifiedSubscription? {
    lock {
        return subscribersCache[subscriberId].cloneReadOnly();
    }
}

isolated function isSubscriptionAvailable(string subscriberId) returns boolean {
    lock {
        return subscribersCache.hasKey(subscriberId);
    }
}
