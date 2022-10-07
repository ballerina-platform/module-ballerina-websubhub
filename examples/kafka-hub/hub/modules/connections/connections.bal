// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerinax/kafka;
import kafkaHub.types;
import kafkaHub.config;

// Producer which persist the current in-memory state of the Hub 
kafka:ProducerConfiguration statePersistConfig = {
    clientId: "state-persist",
    acks: "1",
    retryCount: 3,
    securityProtocol: kafka:PROTOCOL_SASL_SSL,
    auth: {
        username: "$ConnectionString",
        password: config:EVENT_HUB_CONNECTION_STRING
    }
};
public final kafka:Producer statePersistProducer = check new (config:KAFKA_BOOTSTRAP_NODE, statePersistConfig);

// Consumer which reads the persisted subscriber details
kafka:ConsumerConfiguration subscribersConsumerConfig = {
    groupId: string `consolidated-websub-subscribers-group-${config:SERVER_ID}`,
    offsetReset: "earliest",
    securityProtocol: kafka:PROTOCOL_SASL_SSL,
    auth: {
        username: "$ConnectionString",
        password: config:EVENT_HUB_CONNECTION_STRING
    }
};
public final kafka:Consumer subscribersConsumer = check new (config:KAFKA_BOOTSTRAP_NODE, subscribersConsumerConfig);

// Consumer which reads the persisted subscriber details
kafka:ConsumerConfiguration registeredTopicsConsumerConfig = {
    groupId: string `consolidated--websub-topics-group-${config:SERVER_ID}`,
    offsetReset: "earliest",
    securityProtocol: kafka:PROTOCOL_SASL_SSL,
    auth: {
        username: "$ConnectionString",
        password: config:EVENT_HUB_CONNECTION_STRING
    }
};
public final kafka:Consumer registeredTopicsConsumer = check new (config:KAFKA_BOOTSTRAP_NODE, registeredTopicsConsumerConfig);

# Creates a `kafka:Consumer` for a subscriber.
# 
# + namespaceId - Event Hub namespace Id
# + groupName - The consumer group name
# + return - `kafka:Consumer` if succcessful or else `error`
public isolated function createMessageConsumer(string namespaceId, string groupName) returns kafka:Consumer|error {
    types:NameSpaceConfiguration configurations = config:NAMESPACES.filter(ns => ns.namespaceId == namespaceId)[0];
    kafka:ConsumerConfiguration consumerConfiguration = {
        groupId: groupName,
        autoCommit: false,
        securityProtocol: kafka:PROTOCOL_SASL_SSL,
        auth: {
            username: "$ConnectionString",
            password: configurations.connectionString
        }
    };
    return new (configurations.namespace, consumerConfiguration);  
}

isolated final map<kafka:Producer> kafkaProducers = check initProducer();

isolated function initProducer() returns map<kafka:Producer>|error {
    map<kafka:Producer> producers = {};
    foreach types:NameSpaceConfiguration namespaceConfig in config:NAMESPACES {
        kafka:ProducerConfiguration producerConfig = {
            clientId: string `${namespaceConfig.namespaceId}-client`,
            acks: "1",
            retryCount: 3,
            securityProtocol: kafka:PROTOCOL_SASL_SSL,
            auth: {
                username: "$ConnectionString",
                password: namespaceConfig.connectionString
            }
        };
        kafka:Producer producer = check new (config:KAFKA_BOOTSTRAP_NODE, producerConfig);
        producers[namespaceConfig.namespaceId] = producer;
    }
    return producers;
}

public isolated function getKafkaProducer(string namespaceId) returns kafka:Producer {
    lock {
        return kafkaProducers.get(namespaceId);
    }
}
