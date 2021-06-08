import ballerina/websubhub;
import ballerina/log;

isolated function persistTopicRegistrations(websubhub:TopicRegistration message) returns error? {
    lock {
        websubhub:TopicRegistration[] availableTopics = [];
        foreach var topic in registeredTopics {
            availableTopics.push(topic);
        }
        availableTopics.push(message.cloneReadOnly());
        log:printInfo("Updated persistent data ", current = availableTopics);
        json[] jsonData = availableTopics;
        check publishHousekeepingData(REGISTERED_TOPICS, jsonData);
    }
}

isolated function persistTopicDeregistration(websubhub:TopicDeregistration message) returns error? {
    lock {
        websubhub:TopicRegistration[] availableTopics = [];
        foreach var topic in registeredTopics {
            availableTopics.push(topic);
        }
        availableTopics = 
            from var registration in availableTopics
            where registration.topic != message.topic
            select registration.cloneReadOnly();
        log:printInfo("Updated persistent data ", current = availableTopics);
        json[] jsonData = availableTopics;
        check publishHousekeepingData(REGISTERED_TOPICS, jsonData);
    }
}

isolated function persistSubscription(websubhub:VerifiedSubscription message) returns error? {
    lock {
        websubhub:VerifiedSubscription[] availableSubscriptions = [];
        foreach var subscriber in registeredSubscribers {
            availableSubscriptions.push(subscriber);
        }
        availableSubscriptions.push(message.cloneReadOnly());
        log:printInfo("Updated subscriptions ", current = availableSubscriptions);
        json[] jsonData = <json[]> availableSubscriptions.toJson();
        check publishHousekeepingData(REGISTERED_CONSUMERS, jsonData);  
    }
}

isolated function persistUnsubscription(websubhub:VerifiedUnsubscription message) returns error? {
    lock {
        websubhub:VerifiedUnsubscription[] availableSubscriptions = [];
        foreach var subscriber in registeredSubscribers {
            availableSubscriptions.push(subscriber);
        }
        availableSubscriptions = 
            from var subscription in availableSubscriptions
            where subscription.hubTopic != message.hubTopic && subscription.hubCallback != message.hubCallback
            select subscription.cloneReadOnly();
        log:printInfo("Updated subscriptions ", current = availableSubscriptions);
        json[] jsonData = <json[]> availableSubscriptions.toJson();
        check publishHousekeepingData(REGISTERED_CONSUMERS, jsonData);
    }
}

isolated function publishHousekeepingData(string topicName, json payload) returns error? {
    log:printInfo("Publish house-keeping data ", topic = topicName, payload = payload);
    byte[] serializedContent = payload.toJsonString().toBytes();
    check statePersistProducer->send({ topic: topicName, value: serializedContent });
    check statePersistProducer->'flush();
}
