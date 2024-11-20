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
import kafkaHub.config;
import ballerina/crypto;
import ballerina/os;
import ballerina/log;

final kafka:SecureSocket & readonly secureSocketConfig = {
    cert: getCertConfig().cloneReadOnly(),
    protocol: {
        name: kafka:SSL
    },
    'key: check getKeystoreConfig().cloneReadOnly()
};

isolated function getCertConfig() returns crypto:TrustStore|string {
    crypto:TrustStore|string cert = config:KAFKA_MTLS_CONFIG.cert;
    if cert is string {
        return cert;
    }
    string trustStorePassword = os:getEnv("TRUSTSTORE_PASSWORD") == "" ? cert.password : os:getEnv("TRUSTSTORE_PASSWORD");
    string trustStorePath = getFilePath(cert.path, "TRUSTSTORE_FILE_NAME");
    log:printDebug("Kafka client SSL truststore configuration: ", path = trustStorePath);
    return {
        path: trustStorePath,
        password: trustStorePassword
    };
}

isolated function getKeystoreConfig() returns record {|crypto:KeyStore keyStore; string keyPassword?;|}|kafka:CertKey|error? {
    if config:KAFKA_MTLS_CONFIG.key is () {
        return;
    }
    if config:KAFKA_MTLS_CONFIG.key is kafka:CertKey {
        return config:KAFKA_MTLS_CONFIG.key;
    }
    record {|crypto:KeyStore keyStore; string keyPassword?;|} 'key = check config:KAFKA_MTLS_CONFIG.key.ensureType();
    string keyStorePassword = os:getEnv("KEYSTORE_PASSWORD") == "" ? 'key.keyStore.password : os:getEnv("KEYSTORE_PASSWORD");
    string keyStorePath = getFilePath('key.keyStore.path, "KEYSTORE_FILE_NAME");
    log:printDebug("Kafka client SSL keystore configuration: ", path = keyStorePath);
    return {
        keyStore: {
            path: keyStorePath, 
            password: keyStorePassword
        },
        keyPassword: 'key.keyPassword
    };
}

isolated function getFilePath(string defaultFilePath, string envVariableName) returns string {
    string trustStoreFileName = os:getEnv(envVariableName);
    if trustStoreFileName == "" {
        return defaultFilePath;
    }
    return string `/home/ballerina/resources/brokercerts/${trustStoreFileName}`;
}

// Producer which persist the current in-memory state of the Hub 
kafka:ProducerConfiguration statePersistConfig = {
    clientId: "state-persist",
    acks: "1",
    retryCount: 3,
    secureSocket: secureSocketConfig,
    securityProtocol: kafka:PROTOCOL_SSL
};
public final kafka:Producer statePersistProducer = check new (config:KAFKA_URL, statePersistConfig);

// Consumer which reads the persisted subscriber details
kafka:ConsumerConfiguration websubEventsConsumerConfig = {
    groupId: config:WEBSUB_EVENTS_CONSUMER_GROUP,
    offsetReset: "earliest",
    topics: [ config:WEBSUB_EVENTS_TOPIC ],
    secureSocket: secureSocketConfig,
    securityProtocol: kafka:PROTOCOL_SSL
};
public final kafka:Consumer websubEventsConsumer = check new (config:KAFKA_URL, websubEventsConsumerConfig);

# Creates a `kafka:Consumer` for a subscriber.
# 
# + topicName - The kafka-topic to which the consumer should subscribe
# + groupName - The consumer group name
# + return - `kafka:Consumer` if succcessful or else `error`
public isolated function createMessageConsumer(string topicName, string groupName) returns kafka:Consumer|error {
    kafka:ConsumerConfiguration consumerConfiguration = {
        groupId: groupName,
        topics: [topicName],
        autoCommit: false,
        secureSocket: secureSocketConfig,
        securityProtocol: kafka:PROTOCOL_SSL,
        maxPollRecords: config:CONSUMER_MAX_POLL_RECORDS
    };
    return check new (config:KAFKA_URL, consumerConfiguration);  
}
