import ballerina/websubhub;
import ballerina/log;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new ("http://localhost:9090/hub");
    websubhub:TopicRegistrationSuccess registrationResponse = check websubHubClientEP->registerTopic("test");
    log:printInfo("Received topic-registration response", response = registrationResponse);
}
