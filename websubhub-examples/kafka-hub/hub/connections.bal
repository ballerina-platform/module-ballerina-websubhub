import ballerinax/kafka;
import ballerina/websubhub;

kafka:ProducerConfiguration producerConfig = {
    clientId: "update-message",
    acks: "1",
    retryCount: 3
};
final kafka:Producer updateMessageProducer = check new ("localhost:9092", producerConfig);

kafka:ProducerConfiguration statePersistConfig = {
    clientId: "housekeeping-service",
    acks: "1",
    retryCount: 3
};
final kafka:Producer statePersistProducer = check new ("localhost:9092", statePersistConfig);

kafka:ConsumerConfiguration subscriberDetailsConsumerConfig = {
    groupId: "registered-consumers-group-" + constructedServerId,
    offsetReset: "earliest",
    topics: [ REGISTERED_CONSUMERS ]
};
final kafka:Consumer subscriberDetailsConsumer = check new ("localhost:9092", subscriberDetailsConsumerConfig);

kafka:ConsumerConfiguration topicDetailsConsumerConfig = {
    groupId: "registered-topics-group-" + constructedServerId,
    offsetReset: "earliest",
    topics: [ REGISTERED_TOPICS ]
};
final kafka:Consumer topicDetailsConsumer = check new ("localhost:9092", topicDetailsConsumerConfig);

isolated function createMessageConsumer(websubhub:VerifiedSubscription message) returns kafka:Consumer|error {
    string topicName = generateTopicName(message.hubTopic);
    string groupName = generateGroupName(message.hubTopic, message.hubCallback);
    kafka:ConsumerConfiguration consumerConfiguration = {
        groupId: groupName,
        offsetReset: "latest",
        topics: [topicName],
        autoCommit: false
    };
    return check new ("localhost:9092", consumerConfiguration);  
}



