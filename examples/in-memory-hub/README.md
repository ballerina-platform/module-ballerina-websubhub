# A WebSub Hub based on in-memory state

## Overview

The purpose of this example is to demonstrate how to write a WebSub `hub` with minimum code using ballerina.  

This WebSub `hub` example has been implemented using APIs provided by ballerina WebSubHub package. The aforementioned APIs are flexible 
enough so that the `hub` implementation could be backed by different persistence layers such as in-memory, database, message broker etc. This 
particular implementation is based on in-memory persistence layer.

## Implementation

Implementation has been done using the APIs provided by ballerina WebSubHub package and as mentioned above it is backed 
by an in-memory persistence layer.

## Usage

This section discusses on;
- starting the `hub`
- registering `topics` to the `hub`
- subscribing to the `hub`
- publishing content to the `hub`

### Starting the Hub

Go into `hub` directory and execute following command to build the project.
```sh
bal build
```

Then execute following command to run the project.
```sh
bal run target/bin/in_memory_hub.jar
```

#### Running on Docker

Go into `hub` directory and execute follwing command to build the docker image for the project.
```sh
bal build --cloud=docker
```

Then execute following command to run the docker container.
```sh
docker run -p 9000:9000 -d ballerina/in_memory_hub:v1
```

## Registering Topics

After all prerequisites are finished the first interaction to the hub could be made by registering a topic. We have included a sample to understand the usage of `websubhub:PublisherClient` in the `publisher` directory inside the project. Execute the following command to build the `topic_registration_client.bal`.

```
bal build topic_registration_client.bal
```

Then execute the below command to run the program.

```
bal run topic_registration_client.jar
```

## Subscribing to the Hub

Now we have registered a `topic` in the hub. Next we could subscribe to the previously registered `topic` using `websub:SubscriberService`. Build `subscriber_service.bal` inside `subscriber` directory inside the project using the following command.

```
bal build subscriber_service.bal
```

Then execute the below command to run the program.

```
bal run subscriber_service.jar
```

## Publishing to the Hub

Content publishing could be considered as the final stage of interaction between a publisher, hub and subscriber. `websubhub:PublisherClient` has support to publish content to the hub. Find the `content_publish_client.bal` located in `publisher` directory and execute the following command to build the program.

```
bal build content_publish_client.bal
```

Then execute the below command to run the program.

```
bal run content_publish_client.jar
```
