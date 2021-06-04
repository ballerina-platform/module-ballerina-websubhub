import ballerina/log;
import ballerina/websubhub;
import ballerinax/kafka;

listener websubhub:Listener hubListener = new (9090);

public function main() returns error? {
    log:printInfo("Starting Hub-Service");
    
    // Initialize the Hub
    check replayTopicRegistrations();
    check replaySubscriptions();
    
    // Start the Hub
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();
}

function replayTopicRegistrations() returns error? {
    websubhub:TopicRegistration[] availableTopics = check getAvailableTopics();
    foreach var topicDetails in availableTopics {
        string topicName = generateTopicName(topicDetails.topic);
        lock {
            registeredTopics[topicName] = topicDetails.topic;
        }
    }
}

function replaySubscriptions() returns error? {
    websubhub:VerifiedSubscription[] availableSubscribers = check getAvailableSubscribers();
    foreach var subscription in availableSubscribers {
        string groupName = generateGroupName(subscription.hubTopic, subscription.hubCallback);
        kafka:Consumer consumerEp = check createMessageConsumer(subscription);
        websubhub:HubClient hubClientEp = check new (subscription);
        boolean shouldRunNotification = true;
        lock {
            subscribers[groupName] = shouldRunNotification;
        }
        var result = start notifySubscriber(hubClientEp, consumerEp, groupName);
    }
}
