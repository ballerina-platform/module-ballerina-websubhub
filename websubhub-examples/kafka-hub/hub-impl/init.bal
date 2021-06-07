import ballerina/log;
import ballerina/websubhub;
import ballerina/io;
import ballerinax/kafka;
import ballerina/lang.value;

listener websubhub:Listener hubListener = new (9090);

public function main() returns error? {
    log:printInfo("Starting Hub-Service");
    
    // Initialize the Hub
    _ = @strand { thread: "any" } start updateSubscriptionDetails();
    _ = @strand { thread: "any" } start updateTopicDetails();
    
    // Start the Hub
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}

configurable string serverId = ?;
const string REGISTERED_TOPICS = "registered-topics";
const string REGISTERED_CONSUMERS = "registered-consumers";
string constructedServerId = string`${serverId}-${generateRandomString()}`;

kafka:ConsumerConfiguration topicDetailsConsumerConfig = {
    groupId: "registered-topics-group-" + constructedServerId,
    offsetReset: "earliest",
    topics: [ REGISTERED_TOPICS ]
};
final kafka:Consumer topicDetailsConsumer = check new ("localhost:9092", topicDetailsConsumerConfig);

kafka:ConsumerConfiguration subscriberDetailsConsumerConfig = {
    groupId: "registered-consumers-group-" + constructedServerId,
    offsetReset: "earliest",
    topics: [ REGISTERED_CONSUMERS ]
};
final kafka:Consumer subscriberDetailsConsumer = check new ("localhost:9092", subscriberDetailsConsumerConfig);

isolated function updateTopicDetails() returns error? {
    while true {
        websubhub:TopicRegistration[]|error? topicDetails = getAvailableTopics();
        io:println("Executing topic-update with available topic details ", topicDetails is websubhub:TopicRegistration[]);
        if topicDetails is websubhub:TopicRegistration[] {
            lock {
                registeredTopics.removeAll();
            }
            foreach var topic in topicDetails.cloneReadOnly() {
                string topicName = generateTopicName(topic.topic);
                lock {
                    registeredTopics[topicName] = topic.cloneReadOnly();
                }
            }
        }
    }
    _ = check topicDetailsConsumer->close(5);
}

isolated function getAvailableTopics() returns websubhub:TopicRegistration[]|error? {
    kafka:ConsumerRecord[] records = check topicDetailsConsumer->poll(10);
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

function updateSubscriptionDetails() returns error? {
    while true {
        websubhub:VerifiedSubscription[]|error? subscriptionDetails = getAvailableSubscribers();
        io:println("Executing subscription-update with available subscription details ", subscriptionDetails is websubhub:VerifiedSubscription[]);
        if subscriptionDetails is websubhub:VerifiedSubscription[] {
            string[] groupNames = subscriptionDetails.'map(
                function (websubhub:VerifiedSubscription sub) returns string => generateGroupName(sub.hubTopic, sub.hubCallback));
            lock {
                string[] unsubscribedSubscribers = registeredSubscribers.keys().filter(function (string 'key) returns boolean => groupNames.indexOf('key) is ());
                foreach var sub in unsubscribedSubscribers {
                    _ = registeredSubscribers.removeIfHasKey(sub);
                }
            }
            foreach var subscriber in subscriptionDetails {
                string groupName = generateGroupName(subscriber.hubTopic, subscriber.hubCallback);
                boolean isSubAvailable = false;
                lock {
                    isSubAvailable = registeredSubscribers.hasKey(groupName);
                    if !isSubAvailable {
                        registeredSubscribers[groupName] = subscriber.cloneReadOnly();
                    }
                }
                if !isSubAvailable {
                    kafka:Consumer consumerEp = check createMessageConsumer(subscriber);
                    websubhub:HubClient hubClientEp = check new (subscriber);
                    _ = @strand { thread: "any" } start notifySubscriber(hubClientEp, consumerEp, groupName);
                }
            }
        }
    }
    _ = check subscriberDetailsConsumer->close(5);
}

isolated function getAvailableSubscribers() returns websubhub:VerifiedSubscription[]|error? {
    kafka:ConsumerRecord[] records = check subscriberDetailsConsumer->poll(10);
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
