# Specification: Ballerina WebSubHub Library

_Owners_: @shafreenAnfar @chamil321 @ayeshLK    
_Reviewers_: @shafreenAnfar    
_Created_: 2021/11/23  
_Updated_: 2021/12/17  
_Issue_: [#786](https://github.com/ballerina-platform/ballerina-standard-library/issues/786)

# Introduction

This is the specification for WebSubHub standard library which is used to implement WebSub compliant `hub` services 
and `publisher` clients using [Ballerina programming language](https://ballerina.io/), which is an open-source 
programming language for the cloud that makes it easier to use, combine, and create network services. 

# Contents  
1. [Overview](#1-overview)  
2. [Hub](#2-hub)
   * 2.1. [Hub Listener](#21-hub-listener)
     * 2.1.1 [Listener Configuration](#211-listener-configuration)
     * 2.1.2 [Initialization](#212-initialization)
     * 2.1.3 [Dynamically Attach and Detach `websubhub:Service` objects](#213-dynamically-attach-and-detach-websubhubservice-objects)
     * 2.1.4 [Dynamically Start and Stop](#214-dynamically-start-and-stop)
   * 2.2. [Hub Service](#22-hub-service)
     * 2.2.1. [Service Annotation](#221-service-annotation)
   * 2.3. [Hub Client](#23-hub-client)
3. [Publisher Client](#3-publisher-client)

## 1. Overview

[WebSub](https://www.w3.org/TR/websub/) is a real-time content delivery protocol over HTTP(S) and it is a specification 
which evolved from [PubSubHubbub](https://github.com/pubsubhubbub/PubSubHubbub).

WebSub specification describes three main roles: 
- Publisher: Advertises a topic and hub URL on one or more resource URLs.
- Subscriber: Discovers the `hub` and topic URL given a resource URL, subscribes to updates at the `hub`, and accepts 
content distribution requests from the `hub`.
- Hub: Handles subscription requests and distributes the content to subscribers when the corresponding topic URL has 
been updated.

`WebSubHub` is a library which is derived from the WebSub specification which could be used by developers to implement 
WebSub compliant `hub` services and `publisher` clients. Since WebSub specification has limited details on the 
relationship between `publisher` and `hub`, the Ballerina standard library team has made minor improvements to the 
original protocol to provide a seamless developer experience.

## 2. Hub

WebSub `hub` is the exchange point for `publisher` and `subscriber`. 

It has the following responsibilities:
* Handles/manages WebSub topics.
* Handles/manages WebSub subscriptions.
* Handles WebSub content distribution.

The `hub` is designed in the form of `listener` and `service`.
- `websubhub:Listener`: A listener end-point to which `websubhub:Service` could be attached. 
- `websubhub:Service`: An API service, which receives WebSub events.

In addition to `websubhub:Listener` and `websubhub:Service`, `websubhub:HubClient` is available which could be used to 
notify content updates to the subscribers.

### 2.1. Listener

The `websubhub:Listener` will opens the given port and attaches the provided `websubhub:Service` object to the given 
service-path. We can initialize a `websubhub:Listener` either by providing a port with listener configurations or by 
providing an `http:Listener`.

#### 2.1.1. Listener Configuration 

When initializing a `websubhub:Listener`, developer could pass `websubhub:ListenerConfiguration`.   
```ballerina
# Provides a set of configurations for configure the underlying HTTP listener of the WebSubHub listener.
public type ListenerConfiguration record {|
    *http:ListenerConfiguration;
|};
```

For more details on the available configurations please refer [`http:ListenerConfiguration`](https://lib.ballerina.io/ballerina/http/latest/records/ListenerConfiguration).

#### 2.1.2. Initialization

The `websubhub:Listener` could be initialized by providing either a port with `websubhub:ListenerConfiguration` or by 
providing an `http:Listener`.  
```ballerina
# Initiliazes the `websubhub:Listener` instance.
# ```ballerina
# listener websubhub:Listener hubListenerEp = check new (9090);
# ```
#
# + listenTo - Port number or an `http:Listener` instance
# + config - Custom `websubhub:ListenerConfiguration` to be provided to the underlying HTTP listener
# + return - The `websubhub:Listener` or an `websubhub:Error` if the initialization failed
public isolated function init(int|http:Listener listenTo, *ListenerConfiguration config) returns Error? {
```

#### 2.1.3. Dynamically Attach and Detach `websubhub:Service` objects  

Following APIs should be available in the `websubhub:Listener` to dynamically attach/detach `websubhub:Service` objects 
to/from it.  
```ballerina
# Attaches the provided `websubhub:Service` to the `websubhub:Listener`.
# ```ballerina
# check hubListenerEp.attach('service, "/hub");
# ```
# 
# + 'service - The `websubhub:Service` object to attach
# + name - The path of the service to be hosted
# + return - An `websubhub:Error` if an error occurred during the service attaching process or else `()`
public isolated function attach(Service 'service, string[]|string? name = ()) returns Error?

# Detaches the provided `websubhub:Service` from the `websubhub:Listener`.
# ```ballerina
# check hubListenerEp.detach('service);
# ```
# 
# + s - The `websubhub:Service` object to be detached
# + return - An `websubhub:Error` if an error occurred during the service detaching process or else `()`
public isolated function detach(Service s) returns Error?
```

#### 2.1.4. Dynamically Start and Stop  

Following APIs should be available to dynamically start/stop `websubhub:Listener`.
```ballerina
# Starts the registered service programmatically.
# ```ballerina
# check hubListenerEp.'start();
# ```
# 
# + return - An `websubhub:Error` if an error occurred during the listener-starting process or else `()`
public isolated function 'start() returns Error?

# Gracefully stops the hub listener. Already-accepted requests will be served before the connection closure.
# ```ballerina
# check hubListenerEp.gracefulStop();
# ```
# 
# + return - An `websubhub:Error` if an error occurred during the listener-stopping process
public isolated function gracefulStop() returns Error?

# Stops the service listener immediately.
# ```ballerina
# check hubListenerEp.immediateStop();
# ```
# 
# + return - An `websubhub:Error` if an error occurred during the listener-stopping process or else `()`
public isolated function immediateStop() returns Error?
```

### 2.2 Hub Service

`websubhub:Service` is responsible for handling the received events. Underlying `http:Service` will receive the original 
request, and then it will trigger the WebSubHub dispatcher which will invoke the respective remote method with the event 
details.

Following is the type-definition for `websubhub:Service`.
```ballerina
public type Service distinct service object {
    // Sample POST request hub.mode=register&hub.topic=http://foo.com/bar
    // Sample 200 OK response hub.mode=accepted or 200 OK hub.mode=denied&hub.reason=unauthorized
    remote function onRegisterTopic(websubhub:TopicRegistration msg)
        returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error;

    // Sample POST request hub.mode=unregister&hub.topic=http://foo.com/bar
    // Sample 200 OK response hub.mode=accepted or 200 OK hub.mode=denied&hub.reason=unauthorized 
    remote function onDeregisterTopic(websubhub:TopicDeregistration msg)
        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError|error;

    // Sample POST request with content type x-www-form-urlencoded hub.mode=publish&hub.topic=http://foo.com/bar
    // for other content types such as xml, json and octect-stream hub.mode=publish should be in query string.
    // Sample 200 OK response hub.mode=accepted or 200 OK hub.mode=denied&hub.reason=unauthorized 
    remote function onUpdateMessage(websubhub:UpdateMessage msg)
        returns websubhub:Acknowledgement|websubhub:UpdateMessageError|error;

    // Sample POST request hub.mode=subscribe&hub.topic=http://foo.com/bar 
    remote function onSubscription(websubhub:Subscription msg)
        returns websubhub:SubscriptionAccepted|websubhub:SubscriptionPermanentRedirect|
        websubhub:SubscriptionTemporaryRedirect|websubhub:BadSubscriptionError|
        websubhub:InternalSubscriptionError|error;
        
    remote function onSubscriptionValidation(websubhub:Subscription msg)
        returns websubhub:SubscriptionDeniedError|error?;

    remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg) returns error?;

    // Sample POST request hub.mode=unsubscribe&hub.topic=http://foo.com/bar
    remote function onUnsubscription(websubhub:Unsubscription msg)
        returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|
        websubhub:InternalUnsubscriptionError|error;

    remote function onUnsubscriptionValidation(websubhub:Unsubscription msg)
        returns websubhub:UnsubscriptionDeniedError|error?;

    remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg) returns error?;
};
```

**onRegisterTopic**
This remote method is invoked when the `publisher` sends a request to register a `topic` to the `hub`.
```ballerina
# Registers a `topic` in the hub.
# 
# + msg - Details related to the topic-registration
# + return - `websubhub:TopicRegistrationSuccess` if topic registration is successful, `websubhub:TopicRegistrationError`
#            if topic registration failed or `error` if there is any unexpected error
remote function onRegisterTopic(websubhub:TopicRegistration msg)
    returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error;
```

**onUnregisterTopic**
This remote method is invoked when the `publisher` sends a request to remove a `topic` from the `hub`.
```ballerina
# Deregisters a `topic` in the hub.
# 
# + msg - Details related to the topic-deregistration
# + return - `websubhub:TopicDeregistrationSuccess` if topic deregistration is successful, `websubhub:TopicDeregistrationError`
#            if topic deregistration failed or `error` if there is any unexpected error
remote function onDeregisterTopic(websubhub:TopicDeregistration msg)
    returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError|error;
```

**onEventMessage**
This remote method is invoked when the `publisher` sends a request to notify the `hub` about content update for a 
`topic`.
```ballerina
# Publishes content to the hub.
# 
# + msg - Details of the published content
# + return - `websubhub:Acknowledgement` if publish content is successful, `websubhub:UpdateMessageError`
#            if publish content failed or `error` if there is any unexpected error
remote function onUpdateMessage(websubhub:UpdateMessage msg)
    returns websubhub:Acknowledgement|websubhub:UpdateMessageError|error;
```

**onSubscription**  
This remote method is invoked when the `subscriber` sends a request to subscribe for a `topic` in the `hub`. (This is an
optional remote method.)
```ballerina
# Subscribes a `subscriber` to the hub.
# 
# + msg - Details of the subscription
# + return - `websubhub:SubscriptionAccepted` if subscription is accepted from the hub, `websubhub:BadSubscriptionError`
#            if subscription is denied from the hub, `websubhub:SubscriptionPermanentRedirect` or a `websubhub:SubscriptionTemporaryRedirect`
#            if the subscription request is redirected from the `hub`, `websubhub:InternalSubscriptionError` if there is an internal error 
#            while processing the subscription request or `error` if there is any unexpected error
remote function onSubscription(websubhub:Subscription msg)
    returns websubhub:SubscriptionAccepted|websubhub:SubscriptionPermanentRedirect|
        websubhub:SubscriptionTemporaryRedirect|websubhub:BadSubscriptionError|
        websubhub:InternalSubscriptionError|error;
```

**onSubscriptionValidation**  
This remote method is invoked when subscription request from the `subscriber` is accepted from the `hub`. `hub` could 
enforce additional validation for the subscription request when this method is invoked. If the validations are failed 
the `hub` could deny the subscription request by responding with `websubhub:SubscriptionDeniedError`. (This is an 
optional remote method.)
```ballerina
# Validates a incomming subscription request.
# 
# + msg - Details of the subscription
# + return - `websubhub:SubscriptionDeniedError` if the subscription is denied by the hub, `error` if there is any unexpected error or else `()`
remote function onSubscriptionValidation(websubhub:Subscription msg) 
    returns websubhub:SubscriptionDeniedError|error?;
```

**onSubscriptionIntentVerified**  
This remote method is invoked after the `hub` verifies the subscription request.
```ballerina
# Processes a verified subscription request.
# 
# + msg - Details of the subscription
# + return - `error` if there is any unexpected error or else `()`
remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg) returns error?;
```

**onUnsubscritpion**  
This remote method is invoked when the `subscriber` sends a request to unsubscribe from a `topic` in the `hub`. (This is 
an optional remote method.)
```ballerina
# Unsubscribes a `subscriber` from the hub.
# 
# + msg - Details of the unsubscription
# + return - `websubhub:UnsubscriptionAccepted` if unsubscription is accepted from the hub, `websubhub:BadUnsubscriptionError`
#            if unsubscription is denied from the hub, `websubhub:InternalUnsubscriptionError` if there is any internal error while processing the 
#             unsubscription request or `error` if there is any unexpected error
remote function onUnsubscription(websubhub:Unsubscription msg)
    returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|
        websubhub:InternalUnsubscriptionError|error;
```

**onUnsubscriptionValidation**  
This remote method is invoked when unsubscription request from the `subscriber` is accepted from the `hub`. `hub` could
enforce additional validation for the unsubscription request when this method is invoked. If the validations are failed
the `hub` could deny the unsubscription request by responding with `websubhub:UnsubscriptionDeniedError`. (This is an
optional remote method.)
```ballerina
# Validates a incomming unsubscription request.
# 
# + msg - Details of the unsubscription
# + return - `websubhub:UnsubscriptionDeniedError` if the unsubscription is denied by the hub or else `()`
remote function onUnsubscriptionValidation(websubhub:Unsubscription msg) 
    returns websubhub:UnsubscriptionDeniedError|error?;
```

**onUnsubscriptionIntenVerified**  
This remote method is invoked after the `hub` verifies the unsubscription request.
```ballerina
# Processes a verified unsubscription request.
# 
# + msg - Details of the unsubscription
remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg) returns error?;
```

While the below remote methods are strictly WebSub compliant,
- onSubscription 
- onSubscriptionValidation
- onSubscriptionIntentVerified 
- onUnsubscritpion 
- onUnsubscriptionValidation
- onUnsubscriptionIntenVerified

The below remote functions are not, 
- onEventMessage
- onRegisterTopic
- onUnregisterTopic

This is due to the limited information in the WebSub specification on the relationship between the `publisher` and the 
`hub`.

In the event of a bad request from the `publisher` or the `subscriber`, the WebSubHub dispatcher will automatically send 
back the appropriate response to the client.

#### 2.2.1. Service Annotation 

Apart from the listener level configurations a `hub` will require few additional configurations. Hence, we have 
introduced `websubhub:ServiceConfig` a service-level-annotation for `websubhub:Service` which contains 
`websubhub:ServiceConfiguration` record.
```ballerina
# Configuration for a WebSub Hub service.
#
# + leaseSeconds - The period for which the subscription is expected to be active in the `hub`
# + webHookConfig - HTTP client configurations for subscription/unsubscription intent verification
public type ServiceConfiguration record {|
    int leaseSeconds?;
    ClientConfiguration webHookConfig?;
|};
```

### 2.3. Hub Client

In accordance with the [WebSub specification](https://www.w3.org/TR/websub/#content-distribution), `WebSubHub` package 
has provided support for `websubhub:HubClient` which could be used to distribute content-updates to `subscribers`.

#### 2.3.1. Initialization

Since the relationship of the `subscriber` and the `topic` is unique in the `hub`, `websubhub:HubClient` is designed to 
be initialized per `subscription` basis.
```ballerina
# Record to represent the subscription request body.
# 
# + hub - URL of the `hub` to which the subscriber has subscribed
# + hubMode - Current `hub` action
# + hubCallback - Callback URL for subscriber to receive distributed content
# + hubTopic - Topic to which subscriber has subscribed
# + hubLeaseSeconds - Amount of time in seconds during when the subscription is valid
# + hubSecret - Secret Key to sign the distributed content
public type Subscription record {
    string hub;
    string hubMode;
    string hubCallback;
    string hubTopic;
    string? hubLeaseSeconds = ();
    string? hubSecret = ();
};

public isolated function init(Subscription subscription, *ClientConfiguration config) returns Error?
```

#### 2.3.2. Distribute Content

`websubhub:HubClient` should provide following API to be used to deliver content to the `subscriber`.
```ballerina
# Record to represent a WebSub content delivery.
#
# + headers - Additional Request headers to include when distributing content
# + contentType - The content-type of the payload
# + content - The payload to be sent
public type ContentDistributionMessage record {|
    map<string|string[]>? headers = ();
    string? contentType = ();
    json|xml|string|byte[]? content;
|};

type HubClient client object {
    # Distributes the published content to the subscribers.
    # ```ballerina
    # ContentDistributionSuccess publishUpdate = check websubHubClientEP->notifyContentDistribution({ content: "This is sample content" });
    # ```
    #
    # + msg - Content to be distributed to the topic subscriber 
    # + return - An `websubhub:Error` if an exception occurred, a `websubhub:SubscriptionDeletedError` if the subscriber responded with `HTTP 410`,
    #            or else a `websubhub:ContentDistributionSuccess` for successful content delivery
    remote function notifyContentDistribution(websubhub:ContentDistributionMessage msg) 
            returns websubhub:ContentDistributionSuccess|websubhub:SubscriptionDeletedError|websubhub:Error;
};
```

## 3. Publisher Client  

WebSub `publisher`, has two main responsibilities:  
- Advertise `topics` in a `hub`  
- Publish/Update content for the `topics` registered in a `hub`

`websubhub:PublisherClient` will provide the functionalities to support the roles of a WebSub publisher. Publisher client 
is also a wrapper around the `http:Client`.
```ballerina
websubhub:PublisherClient publisherClientEp = check new ("https://sample.hub.com", 
// configure underlying `http:Client` by passing `websubhub:ClientConfiguration`
secureSocket = {
    'key: {
        certFile: "./resources/server.crt",
        keyFile: "./resources/server.key"
    }
});
```

Following is a sample on how to register/deregister `topic` in a `hub` using `websubhub:PublisherClient`:
```ballerina
// register a topic in the `hub`
websubhub:TopicRegistrationSuccess topicRegistration = check publisherClientEp->registerTopic("https://topic1.com");

// deregister a topic from the `hub`
websubhub:TopicDeregistrationSuccess topicDeregistration = check publisherClientEp->deregisterTopic("https://topic2.com");
```

The content-update for a `topic` could be done with two ways:
- Update the content in the `topic` itself and notify the `hub`
- Send updated content directly to the `hub` 
```ballerina
// notify the `hub` that the content is updated in the `topic`
websubhub:Acknowledgement updateNotificationResponse = check publisherClientEp->notifyUpdate("https://topic1.com");

// send updated content directly to the `hub`
json payload = {
    "action": "publish",
    "mode": "remote-hub"
};
websubhub:Acknowledgement contetnPublishResponse = check publisherClientEp->publishUpdate("https://topic3.com", payload);
```
The developer could use one of `map<string>`/`string`/`xml`/`json`/`byte[]` as the payload for `publishUpdate` API. 
