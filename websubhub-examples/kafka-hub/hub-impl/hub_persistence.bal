import ballerinax/kafka;
import ballerina/websubhub;
import ballerina/log;
import ballerina/mime;
import ballerina/lang.value;

kafka:ProducerConfiguration producerConfig = {
    clientId: "update-message",
    acks: "1",
    retryCount: 3
};

final kafka:Producer updateMessageProducer = check new ("localhost:9092", producerConfig);

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

isolated function notifySubscriber(websubhub:HubClient clientEp, kafka:Consumer consumerEp, string groupName) returns error? {
    while true {
        kafka:ConsumerRecord[] records = check consumerEp->poll(10);
        boolean shouldProceed = true;
        lock {
            shouldProceed = registeredSubscribers.hasKey(groupName);
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

isolated function publishContent(websubhub:UpdateMessage message, string topicName) returns error? {
    log:printInfo("Distributing content to ", Topic = topicName);
    // here we have assumed that the payload will be in `json` format
    json payload = <json>message.content;
    byte[] content = payload.toJsonString().toBytes();
    check updateMessageProducer->send({ topic: topicName, value: content });
    check updateMessageProducer->'flush();
}
