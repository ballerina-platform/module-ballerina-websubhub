import ballerina/websubhub;
import ballerina/log;

public function main() returns error? {
    websubhub:PublisherClient publisherClient = check new ("http://localhost:9090/hub");    
    json params = { event: "event"};
    websubhub:Acknowledgement ack = check publisherClient->publishUpdate("test", params);
    log:printInfo("Received response for content-update", response = ack);
}
