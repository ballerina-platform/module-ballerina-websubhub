// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

import ballerina/crypto;
import ballerina/log;
import ballerina/os;
import ballerinax/kafka;

final kafka:SecureSocket & readonly secureSocketConfig = {
    cert: getCertConfig().cloneReadOnly(),
    protocol: {
        name: kafka:SSL
    },
    'key: check getKeystoreConfig().cloneReadOnly()
};

isolated function getCertConfig() returns crypto:TrustStore|string {
    crypto:TrustStore|string cert = kafkaMtlsConfig.cert;
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
    if kafkaMtlsConfig.key is () {
        return;
    }
    if kafkaMtlsConfig.key is kafka:CertKey {
        return kafkaMtlsConfig.key;
    }
    record {|crypto:KeyStore keyStore; string keyPassword?;|} 'key = check kafkaMtlsConfig.key.ensureType();
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

kafka:ProducerConfiguration statePersistConfig = {
    clientId: "state-persist",
    acks: "1",
    retryCount: 3,
    secureSocket: secureSocketConfig,
    securityProtocol: kafka:PROTOCOL_SSL
};
final kafka:Producer statePersistProducer = check new (kafkaUrl, statePersistConfig);

// Consumer which reads the persisted subscriber details
readonly & kafka:ConsumerConfiguration kafkaConsumerConfig = {
    groupId: consumerGroup,
    secureSocket: secureSocketConfig,
    securityProtocol: kafka:PROTOCOL_SSL,
    maxPollRecords: 50
};
public final kafka:Consumer kafkaConsumer = check new (kafkaUrl, kafkaConsumerConfig);
