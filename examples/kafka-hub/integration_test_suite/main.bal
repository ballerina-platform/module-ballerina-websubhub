import ballerina/websub;
import ballerina/websubhub;

configurable string HUB = ?;
configurable string TOPIC = ?;
configurable string CALLBACK_URL = ?;
final string SECRET = "test123$";

final websub:Listener websubListener = check new (9090);

public function main() returns error? {
    websubhub:PublisherClient publisherClientEp = check new(HUB);
    websubhub:TopicRegistrationSuccess|error registrationResponse = registerTopic(publisherClientEp);
    // todo: how to handle the topic-reg success/failure

    error? subscriptionStatus = subscribe(websubListener, subscriberService);
    // todo: how to handle the subscription success/failure
    if subscriptionStatus is error {

    }

    websubhub:UpdateMessageError? contentPublishStatus = publishContent(publisherClientEp);
    // todo: how to handle content publish success/failure

    error? unsubscriptionStatus = subscribe(websubListener, subscriberService);
    // todo: how to handle unsubscription success/failure
    if unsubscriptionStatus is error {

    }

    websubhub:TopicDeregistrationSuccess|error deRegistrationResponse = deregisterTopic(publisherClientEp);
    // todo: how to handle topic-dereg success/failure
}

isolated function registerTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicRegistrationSuccess|error {
    return publisherClientEp->registerTopic(TOPIC);
}

isolated function subscribe(websub:Listener websubListener, websub:SubscriberService subscriberService) returns error? {
    websub:SubscriberServiceConfiguration config = {
        target: [HUB, TOPIC],
        callback: CALLBACK_URL,
        secret: SECRET,
        unsubscribeOnShutdown: true
    };
    check websubListener.attachWithConfig(subscriberService, config);
    return websubListener.'start();
}

isolated function publishContent(websubhub:PublisherClient publisherClientEp) returns websubhub:UpdateMessageError? {
    foreach json message in messages {
        var publishResponse = publisherClientEp->publishUpdate(TOPIC, message);
        if publishResponse is websubhub:UpdateMessageError {
            return publishResponse;
        }
    }
}

isolated function unsubscribe(websub:Listener websubListener) returns error? {
    return websubListener.gracefulStop();
}

isolated function deregisterTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicDeregistrationSuccess|error {
    return publisherClientEp->deregisterTopic(TOPIC);
}
