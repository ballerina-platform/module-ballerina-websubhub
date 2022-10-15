Ballerina WebSubHub Library
===================

  [![Build](https://github.com/ballerina-platform/module-ballerina-websubhub/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-websubhub/actions/workflows/build-timestamped-master.yml)
  [![Trivy](https://github.com/ballerina-platform/module-ballerina-websubhub/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-websubhub/actions/workflows/trivy-scan.yml)
  [![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-websubhub.svg)](https://github.com/ballerina-platform/module-ballerina-websubhub/commits/main)
  [![Github issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-standard-library/module/websubhub.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-standard-library/labels/module%2Fwebsubhub)
  [![codecov](https://codecov.io/gh/ballerina-platform/module-ballerina-websubhub/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerina-websubhub) 

This library provides APIs for a WebSub Hub service and WebSub Publisher client.

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

#### Use `websubhub:HubClient`

* **WebSub HubClient** can be used to distribute the published content to subscribers. The current implementation is based on `Ballerina HTTP Client`.

```ballerina
type HubClient client object {
    remote function notifyContentDistribution(websubhub:ContentDistributionMessage msg)
                returns websubhub:ContentDistributionSuccess|websubhub:SubscriptionDeletedError|error?;
};
```

* The following is a sample usage for **WebSub HubClient**.

```ballerina
websubhub:Service hubService = service object {
    remote function onSubscriptionIntentVerified(websubhub:Subscription msg) returns error? {

        // you can pass client config if you want 
        // say maybe retry config
        websubhub:HubClient hubclient = check new (msg);
        _ = start self.notifySubscriber(hubclient);
    }

    function notifySubscriber(websubhub:HubClient hubclient) returns error? {
        while true {
            // fetch the message from MB
            _ = check hubclient->notifyContentDistribution({
                content: "This is sample content delivery"
            });
        }
    }
};
```

#### Use `websubhub:PublisherClient`

* The `PublisherClient` APIs are defined by Ballerina and it has no connection with the WebSub specification. As mentioned earlier, even though the
WebSub specification extensively discusses the relationship between the subscriber and hub, it does not discuss much the relationship between the publisher and hub.

* The following is a sample **WebSub Publisher Client**.

```ballerina
websubhub:PublisherClient publisherClient = check new ("http://localhost:9191/websub/hub");
websubhub:TopicDeregistrationSuccess topicRegResponse = check publisherClient->registerTopic("http://websubpubtopic.com");
json payload = {
    "action": "publish",
    "mode": "remote-hub"
};
websubhub:Acknowledgement publishResponse = check publisherClient->publishUpdate("http://websubpubtopic.com", payload);
```

#### Return errors from remote methods

* Remote functions in `websubhub:Service` can return `error` type.
```ballerina
service /websubhub on new websubhub:Listener(9090) {

    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error {
        boolean validationSuccessfull = check validateRegistration(message);
        if validationSuccessfull {
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
 
## Issues and projects

Issues and Projects tabs are disabled for this repository as this is part of the Ballerina Standard Library. To report bugs, request new features, start new discussions, view project boards, etc. please visit Ballerina Standard Library [parent repository](https://github.com/ballerina-platform/ballerina-standard-library).

This repository only contains the source code for the package.

## Build from the source

### Set up the prerequisites

* Download and install Java SE Development Kit (JDK) version 11 (from one of the following locations).

   * [Oracle](https://www.oracle.com/java/technologies/javase-jdk11-downloads.html)
   
   * [OpenJDK](https://adoptium.net/)
   
        > **Note:** Set the JAVA_HOME environment variable to the path name of the directory into which you installed JDK.
     
### Build the source

Execute the commands below to build from source.

1. To build the package:
        
        ./gradlew clean build

2. To build the package without the tests:
```
        ./gradlew clean build -x test
```

1. To debug the package tests:
3. To debug the package tests:

        ./gradlew clean build -Pdebug=<port>

4. To run a group of tests
    ```
    ./gradlew clean test -Pgroups=<test_group_names>
    ```

5. To debug with Ballerina language:
    ```
    ./gradlew clean build -PbalJavaDebug=<port>
    ```

6. Publish the generated artifacts to the local Ballerina central repository:
    ```
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

7. Publish the generated artifacts to the Ballerina central repository:
    ```
    ./gradlew clean build -PpublishToCentral=true
    ```

## Contribute to Ballerina

As an open source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information, go to the [`websubhub` library](https://lib.ballerina.io/ballerina/websubhub/latest).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
* View the [Ballerina performance test results](performance/benchmarks/summary.md).
