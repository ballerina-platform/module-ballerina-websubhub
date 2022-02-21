import ballerina/log;
import ballerina/websub;

@websub:SubscriberServiceConfig {
    target: ["http://0.0.0.0:9090/hub", "test"],
    leaseSeconds: 36000,
    unsubscribeOnShutdown: true
}
service /JuApTOXq19 on new websub:Listener(9091) {
    remote function onEventNotification(readonly & websub:ContentDistributionMessage msg) returns websub:Acknowledgement {
        log:printInfo("Received content update: ", payload = msg);
        return websub:ACKNOWLEDGEMENT;
    }
}

