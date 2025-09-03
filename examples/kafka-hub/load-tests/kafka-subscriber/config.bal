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
import ballerina/os;
import ballerinax/kafka;

type OAuth2Config record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
    string trustStore;
    string trustStorePassword;
|};

configurable OAuth2Config oauth2Config = ?;

public type KafkaMtlsConfig record {|
    crypto:TrustStore|string cert;
    record {|
        crypto:KeyStore keyStore;
        string keyPassword?;
    |}|kafka:CertKey key?;
|};

configurable KafkaMtlsConfig kafkaMtlsConfig = ?;

final string topicName = os:getEnv("TOPIC_NAME") == "" ? "priceUpdate" : os:getEnv("TOPIC_NAME");
final int numberOfRequests = os:getEnv("NUMBER_OF_REQUESTS") == "" ? 10 : check int:fromString(os:getEnv("NUMBER_OF_REQUESTS"));
final int numberOfSubscribers = os:getEnv("NUMBER_OF_SUBSCRIBERS") == "" ? 1 : check int:fromString(os:getEnv("NUMBER_OF_SUBSCRIBERS"));
final string? consumerGroup = os:getEnv("CONSUMER_GROUP") == "" ? "consumer-group" : os:getEnv("CONSUMER_GROUP");
final string? topicPartitions = os:getEnv("TOPIC_PARTITIONS") == "" ? () : os:getEnv("TOPIC_PARTITIONS");
final string kafkaUrl = os:getEnv("KAFKA_URL") == "" ? kafka:DEFAULT_URL : os:getEnv("KAFKA_URL");
