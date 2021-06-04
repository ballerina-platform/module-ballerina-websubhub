import ballerina/websubhub;
import ballerina/log;
import ballerina/lang.value;
import ballerinax/kafka;

const string REGISTERED_TOPICS = "registered-topics";
const string REGISTERED_CONSUMERS = "registered-consumers";

kafka:ProducerConfiguration houseKeepingProducerConfig = {
    clientId: "housekeeping-service",
    acks: "1",
    retryCount: 3
};
final kafka:Producer houseKeepingService = check new ("localhost:9092", houseKeepingProducerConfig);

kafka:ConsumerConfiguration topicDetailsConsumerConfig = {
    groupId: "registered-topics-group",
    offsetReset: "earliest",
    topics: [ "registered-topics" ]
};
final kafka:Consumer topicDetailsConsumer = check new ("localhost:9092", topicDetailsConsumerConfig);

kafka:ConsumerConfiguration subscriberDetailsConsumerConfig = {
    groupId: "registered-consumers-group",
    offsetReset: "earliest",
    topics: [ "registered-consumers" ]
};
final kafka:Consumer subscriberDetailsConsumer = check new ("localhost:9092", subscriberDetailsConsumerConfig);

isolated function persistTopicRegistrations(websubhub:TopicRegistration message) returns error? {
    websubhub:TopicRegistration[] topics = check getAvailableTopics();
    topics.push(message);
    log:printInfo("Updated topics ", current = topics);
    json[] jsonData = topics;
    check publishHousekeepingData(REGISTERED_TOPICS, jsonData);
}

isolated function persistTopicDeregistration(websubhub:TopicDeregistration message) returns error? {
    websubhub:TopicRegistration[] availableTopics = check getAvailableTopics();
    availableTopics = 
        from var registration in availableTopics
        where registration.topic != message.topic
        select registration;
    log:printInfo("Updated topics ", current = availableTopics);
    json[] jsonData = availableTopics;
    check publishHousekeepingData(REGISTERED_TOPICS, jsonData);
}

isolated function persistSubscription(websubhub:VerifiedSubscription message) returns error? {
    websubhub:VerifiedSubscription[] subscriptions = check getAvailableSubscribers();
    subscriptions.push(message);
    log:printInfo("Updated subscriptions ", current = subscriptions);
    json[] jsonData = <json[]> subscriptions.toJson();
    check publishHousekeepingData(REGISTERED_CONSUMERS, jsonData);
}

isolated function persistUnsubscription(websubhub:VerifiedUnsubscription message) returns error? {
    websubhub:VerifiedUnsubscription[] subscriptions = check getAvailableSubscribers();
    subscriptions = 
        from var subscription in subscriptions
        where subscription.hubTopic != message.hubTopic && subscription.hubCallback != message.hubCallback
        select subscription;
    log:printInfo("Updated subscriptions ", current = subscriptions);
    json[] jsonData = <json[]> subscriptions.toJson();
    check publishHousekeepingData(REGISTERED_CONSUMERS, jsonData);
}

isolated function publishHousekeepingData(string topicName, json payload) returns error? {
    log:printInfo("Publish house-keeping data ", topic = topicName, payload = payload);
    byte[] serializedContent = payload.toJsonString().toBytes();
    check houseKeepingService->send({ topic: topicName, value: serializedContent });
    check houseKeepingService->'flush();
}

isolated function getAvailableTopics() returns websubhub:TopicRegistration[]|error {
    kafka:ConsumerRecord[] records = check topicDetailsConsumer->poll(1);
    websubhub:TopicRegistration[] currentTopics = [];
    if (records.length() > 0) {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if (lastPersistedData is string) {
            log:printInfo("Last persisted-data set : ", message = lastPersistedData);
            json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
            foreach var data in payload {
                websubhub:TopicRegistration topic = check data.cloneWithType(websubhub:TopicRegistration);
                currentTopics.push(topic);
            }
        } else {
            log:printError("Error occurred while retrieving topic-details ", err = lastPersistedData.message());
        }
    }
    return currentTopics;
}

isolated function getAvailableSubscribers() returns websubhub:VerifiedSubscription[]|error {
    kafka:ConsumerRecord[] records = check subscriberDetailsConsumer->poll(1);
    websubhub:VerifiedSubscription[] currentSubscriptions = [];
    if (records.length() > 0) {
        kafka:ConsumerRecord lastRecord = records.pop();
        string|error lastPersistedData = string:fromBytes(lastRecord.value);
        if (lastPersistedData is string) {
            log:printInfo("Last persisted-data set : ", message = lastPersistedData);
            json[] payload =  <json[]> check value:fromJsonString(lastPersistedData);
            foreach var data in payload {
                websubhub:VerifiedSubscription subscription = check data.cloneWithType(websubhub:VerifiedSubscription);
                currentSubscriptions.push(subscription);
            }
        } else {
            log:printError("Error occurred while retrieving subscriber-data ", err = lastPersistedData.message());
        }
    }
    return currentSubscriptions;  
}
