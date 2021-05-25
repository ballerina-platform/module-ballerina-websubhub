import ballerina/log;
import ballerina/websubhub;

public function main() returns error? {
    log:printInfo("Starting hub-service initialization");
    
    websubhub:TopicRegistration[] availableTopics = check getAvailableTopics();

    websubhub:VerifiedSubscription[] availableSubscribers = check getAvailableSubscribers();

    check replayTopicRegistrations(availableTopics);

    check replaySubscriptions(availableSubscribers);

    check hubListener.attach(<websubhub:Service>hubService, "hub");

    check hubListener.'start();
}

function replayTopicRegistrations(websubhub:TopicRegistration[] topics) returns error? {
    foreach var topic in topics {
        registerTopic(topic, false);
    }
}

function replaySubscriptions(websubhub:VerifiedSubscription[] subscriptions) returns error? {
    foreach var subscription in subscriptions {
        check subscribe(subscription, false);
    }
}
