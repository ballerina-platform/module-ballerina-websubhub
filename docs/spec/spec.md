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
   * 2.2. [Hub Service](#22-hub-service)
     * 2.2.1. [Service Annotation](#221-service-annotation)
3. [Hub Client](#3-hub-client)
4. [Publisher Client](#4-publisher-client)

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

#### 2.1.3. Attaching and Detaching `websubhub:Service` objects  

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

#### 2.1.4. Starting and Stopping  

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

In addition to that, following remote methods are optional,
- onSubscription
- onSubscriptionValidation
- onUnsubscritpion
- onUnsubscriptionValidation

In the event of a bad request from the `publisher` or the `subscriber`, the WebSubHub dispatcher will automatically send 
back the appropriate response to the client.

Following is a sample implementation of the `hub`:
```ballerina
service /hub on hubListener {
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        // implement logic here
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message)
                returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {
        // implement logic here
        return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
    }

    isolated remote function onUpdateMessage(websubhub:UpdateMessage message)
                returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        // implement logic here
        return websubhub:ACKNOWLEDGEMENT;
    }

    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription message) {
        // implement logic here
    }

    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription message) {
        // implement logic here
    }
}
```

Apart from the basic WebSub features, the developer could integrate other cross-cutting concerns to the `hub` with 
minimum effort. Following is a sample `hub` implementation secured with OAuth2:
```ballerina
service /hub on hubListener {
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message, http:Headers headers)
                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError|error {
        check authorize(headers, ["register_topic"]);

        // implement logic here
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }

    // implement other remote methods
}

final http:ListenerJwtAuthHandler handler = new ({
    issuer: "https://sample.isp.com/oauth2/token",
    audience: "sample",
    signatureConfig: {
        jwksConfig: {
            url: "https://sample.isp.com/oauth2/jwks",
            clientConfig: {
                secureSocket: {
                    'key: {
                        certFile: "./resources/server.crt",
                        keyFile: "./resources/server.key"
                    }
                }
            }
        }
    },
    scopeKey: "scope"
});

isolated function authorize(http:Headers headers, string[] authScopes) returns error? {
    string|http:HeaderNotFoundError authHeader = headers.getHeader(http:AUTH_HEADER);
    if (authHeader is string) {
        jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
        if (auth is jwt:Payload) {
            http:Forbidden? forbiddenError = handler.authorize(auth, authScopes);
            if (forbiddenError is http:Forbidden) {
                return error("Not authorized");
            }
        } else {
            return error("Not authorized");
        }
    } else {
        return error("Not authorized");
    }
}
```

### 2.2.1. Service Annotation 

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

Following is a sample `hub` with `websubhub:ServiceConfig` annotation:
```ballerina
@websubhub:ServiceConfig {
    leaseSeconds: 86400,
    webHookConfig: {
        secureSocket: {
            'key: {
                certFile: "./resources/webhook.crt",
                keyFile: "./resources/webhook.key"
            }
        }
    }
}
service /hub on hubListener {
    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        // implement logic here
        return websubhub:TOPIC_REGISTRATION_SUCCESS;
    }
    
    // implement other remote methods
}
```

## 3. Hub Client

In accordance with the [WebSub specification](https://www.w3.org/TR/websub/#content-distribution), `WebSubHub` package 
has provided support for `websubhub:HubClient` which could be used to distribute content-updates to `subscribers`. 
`websubhub:HubClient` is implemented by wrapping ballerina `http:Client` and it could be instantiated as 
follows.
```ballerina
websubhub:Subscription subscriptionDetails = {
    hub: "https://hub.com",
    hubMode: "subscribe",
    hubCallback: "http://subscriber.com/callback",
    hubTopic: "https://topic.com",
    hubSecret: "key"
};

websubhub:HubClient hubClientEP = check new (subscriptionDetails,
// configure underlying `http:Client` by passing `websubhub:ClientConfiguration`
secureSocket = {
    'key: {
        certFile: "./resources/server.crt",
        keyFile: "./resources/server.key"
    }
});
```

Since the relationship of the `subscriber` and the `topic` is unique in the `hub`, `websubhub:HubClient` is designed to 
be instantiated per `subscription` basis.

`websubhub:HubClient` provides following API to be used to deliver content to the `subscriber`.
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
    remote function notifyContentDistribution(websubhub:ContentDistributionMessage msg) 
            returns websubhub:ContentDistributionSuccess|websubhub:SubscriptionDeletedError|websubhub:Error;
};
```

If the content distribution is successful, Hub Client will return a `websubhub:ContentDistributionSuccess`. 
If the `subscriber` responded with `HTTP 410`, then it will return `websubhub:SubscriptionDeletedError` which is an 
indication to remove the subscription from the `hub`. And if there is an error while distributing the content, it will 
return an `webubhub:Error`.  
```ballerina
websubhub:ContentDistributionMessage msg = { content: "This is sample content delivery" };
websubhub:ContentDistributionSuccess|websubhub:Error response = hubClientEP->notifyContentDistribution(msg);
if response is websubhub:ContentDistributionSuccess {
    // implement logic for successful content-delivery
} else if response is websubhub:SubscriptionDeletedError {
    // implement logic to remove the subscription
} else {
    // implemnt logic to handle unexpected error
}
```

## 4. Publisher Client  

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
