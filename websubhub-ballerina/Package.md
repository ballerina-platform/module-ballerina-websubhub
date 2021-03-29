## Package Overview

This package contains an API specification to implement W3C [**WebSub Hub**](https://www.w3.org/TR/websub/) which facilitates 
a push-based content delivery / notification mechanism.

This package contains following components :

1. API Specification of W3C [**WebSub Hub**](https://www.w3.org/TR/websub/#hub) specification.

2. `HTTP` based **Hub Listener** implementation.

3. ```HTTP``` based implementation of **Hub Client** which is responsible for delivering content to subscribers.

4. ```HTTP``` based implementation of W3C [**WebSub Publisher**](https://www.w3.org/TR/websub/#publisher) specification.

### Basic flow with WebSub

1. The subscriber discovers from the publisher, the topic it needs to subscribe to and the hub(s) that deliver notifications on updates of the topic.

2. The subscriber sends a subscription request to one or more discovered hub(s) specifying the discovered topic along 
 with other subscription parameters such as:
    - The callback URL to which content is expected to be delivered.
    - (Optional) The lease period (in seconds) the subscriber wants the subscription to stay active.
    - (Optional) A secret to use for [authenticated content distribution](https://www.w3.org/TR/websub/#signing-content).
  
3. The hub sends an intent verification request to the specified callback URL. If the response indicates
verification (by echoing a challenge specified in the request) by the subscriber, the subscription is added for the topic at the hub.

4. The publisher notifies the hub of updates to the topic and the content to deliver is identified.

5. The hub delivers the identified content to the subscribers of the topic.

### Features

#### WebSub Hub Specification

One of the key features of this package is the ```ballerina``` specific API abstraction for **WebSub Hub** specification.

According to the W3C [**WebSub**](https://www.w3.org/TR/websub/) specification **Hub** has following responsibilities.

- Register / Deregister ```topics``` advertised by the ```publishers```.
- Subscribe / Unsubscribe ```subscribers``` to advertised ```topics```.
- Verify the valid ```subscriptions```.
- Distribute published ```content``` to the ```subscriber base``` of a ```topic```.

In the API specification for **WebSub Hub**, package provides following abstractions to be implemented.

- Publisher Interactions

```ballerina
    remote function onRegisterTopic(websubhub:TopicRegistration msg)
                 returns websubhub:TopicRegistrationSuccess | websubhub:TopicRegistrationError;

    remote function onDeregisterTopic(websubhub:TopicDeregistration msg)
                 returns websubhub:TopicDeregistrationSuccess | websubhub:TopicDeregistrationError;

    remote function onUpdateMessage(websubhub:UpdateMessage msg)
                returns websubhub:Acknowledgement | websubhub:UpdateMessageError;
```

- Subscriber Interactions

```ballerina
   remote function onSubscription(websubhub:Subscription msg)
                returns websubhub:SubscriptionAccepted 
                        |websubhub:SubscriptionPermanentRedirect
                        |websubhub:SubscriptionTemporaryRedirect 
                        |websubhub:BadSubscriptionError 
                        |websubhub:InternalSubscriptionError;

   remote function onSubscriptionValidation(websubhub:Subscription msg)
                returns websubhub:SubscriptionDeniedError?;

   remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg); 

   remote function onUnsubscription(websubhub:Unsubscription msg)
                returns websubhub:UnsubscriptionAccepted
                        |websubhub:BadUnsubscriptionError
                        |websubhub:InternalUnsubscriptionError;

   remote function onUnsubscriptionIntenVerified(websubhub:VerifiedUnsubscription msg);
```

Since **WebSub Specification** is not thorough enough with regard to the relationship between the ```Publisher``` and ```Hub```;

- Below methods are strictly websub compliant
    - onSubscription
    - onSubscriptionIntentVerified
    - onUnsubscritpion
    - onUnsubscriptionIntenVerified

- Below methods are not strictly websub compliant
    - onRegisterTopic
    - onDeregisterTopic
    - onUpdateMessage

#### Hub Listener

HubListener is essentially a wrapper for ```ballerina HTTP Listener```. Following is a sample of the hub-listener.

* `websubhub:Listener` using `http:Listener`.
```ballerina
    listener websubhub:Listener hub = new(new http:Listener(9091));
```

* `websubhub:Listener` with port number.
```ballerina
    listener websubhub:Listener hub = new(9090);
```

#### Hub Client

**WebSub HubClient** can be used to distribute the published content among ```subscriber base```. Current implementation is based on
```ballerina HTTP Client```.

```ballerina
    client class HubClient {
        remote function notifyContentDistribution(websubhub:ContentDistributionMessage msg) 
                returns ContentDistributionSuccess | SubscriptionDeletedError | error?
    }
```

Following is a sample of **WebSub HubClient**.

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

#### WebSub Publisher Client

PublisherClient APIs are defined by the Ballerina standard library team and it has nothing to do with websub specification. As mentioned earlier, Even though the
websub specification extensively discusses the relationship between the subscriber and hub, it does not really discuss much about the relationship between the publisher and hub.

Following is a sample of **WebSub Publisher Client**.

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
