## Overview

This module provides APIs for WebSub Hub service and WebSub Publisher client.

[**WebSub**](https://www.w3.org/TR/websub/) is a common mechanism for communication between publishers of any kind of web content and their subscribers based on HTTP webhooks. Subscription requests are relayed through hubs, which validate and verify the requests. Hubs then distribute new and updated content to subscribers when it becomes available. WebSub was previously known as PubSubHubbub.

[**WebSub Hub**](https://www.w3.org/TR/websub/#hub) is an implementation that handles subscription requests and distributes the content to subscribers when the corresponding topic URL has been updated.

[**WebSub Publisher**](https://www.w3.org/TR/websub/#publisher) is an implementation that advertises a topic and hub URL on one or more resource URLs.

### Basic flow with WebSub

1. The subscriber discovers (from the publisher) the topic it needs to subscribe to and the hub(s) that deliver notifications on the updates of the topic.

2. The subscriber sends a subscription request to one or more discovered hub(s) specifying the discovered topic along 
 with other subscription parameters such as:
    - The callback URL to which the content is expected to be delivered.
    - (Optional) The lease period (in seconds) the subscriber wants the subscription to stay active.
    - (Optional) A secret to use for [authenticated content distribution](https://www.w3.org/TR/websub/#signing-content).
  
3. The hub sends an intent verification request to the specified callback URL. If the response indicates
verification (by echoing a challenge specified in the request) by the subscriber, the subscription is added for the topic at the hub.

4. The publisher notifies the hub of the updates to the topic and the content to deliver is identified.

5. The hub delivers the identified content to the subscribers of the topic.

#### Using Hub Client

* **WebSub HubClient** can be used to distribute the published content among the `subscriber base`. The current implementation is based on
a `ballerina HTTP Client`.

```ballerina
    client class HubClient {
        remote function notifyContentDistribution(websubhub:ContentDistributionMessage msg) 
                returns ContentDistributionSuccess | SubscriptionDeletedError | error?
    }
```

* The following is a sample **WebSub HubClient**.

```ballerina
    type HubService service object {
        remote function onSubscriptionIntentVerified(websubhub:Subscription msg) {

            // you can pass client config if you want 
            // say maybe retry config
            websub:HubClient hubclient = new(msg);
            check start notifySubscriber(hubclient);
        }

        function notifySubscriber(websubhub:HubClient hubclient) returns error? {
            while (true) {
                // fetch the message from MB
                check hubclient->notifyContentDistribution({
                    content: "This is sample content delivery"
                });
            }   
        }
    }
```

#### Using Publisher Client

* The `PublisherClient` APIs are defined by Ballerina and it has no connection with the WebSub specification. As mentioned earlier, even though the
WebSub specification extensively discusses the relationship between the subscriber and hub, it does not discuss much the relationship between the publisher and hub.

* The following is a sample **WebSub Publisher Client**.

```ballerina
    websubhub:PublisherClient publisherClient = new ("http://localhost:9191/websub/hub");

    check publisherClient->registerTopic("http://websubpubtopic.com");
   
    var publishResponse = publisherClient->publishUpdate(
                "http://websubpubtopic.com",
                {
                    "action": "publish", 
                    "mode": "remote-hub"
                });
```

# Returning Errors from Remote Methods

* Remote functions in `websubhub:Service` can return `error` type.
```ballerina
service /websubhub on new websubhub:Listener(9090) {

    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error {
        boolean validationSuccessfull = check validateRegistration(message);
        if (validationSuccessfull) {
            websubhub:TOPIC_REGISTRATION_SUCCESS;
        } else {
            return websubhub:TOPIC_REGISTRATION_ERROR;
        }
    }

    // implement other remote methods
}

function validateRegistration(websubhub:TopicRegistration message) returns boolean|error {
   // implement validation
}
```

* For each remote method `error` return has a different meaning. Following table depicts the meaning inferred from `error` returned from all available remote methods.

| Method        | Interpreted meaning for Error Return |
| ----------- | ---------------- |
| onRegisterTopic | Topic registration failure |
| onDeregisterTopic | Topic de-registration failure |
| onUpdateMessage | Update message error |
| onSubscription | Subscription internal server error |
| onSubscriptionValidation | Subscription validation failure |
| onSubscriptionIntentVerified | Subscription intent verification failure |
| onUnsubscription | Unsubscription internal server error |
| onUnsubscriptionValidation | Unsubscription validation failure |
| onUnsubscriptionIntentVerified | Unsubscription intent verification failure |
