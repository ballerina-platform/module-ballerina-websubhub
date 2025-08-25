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

import ballerina/os;
import ballerina/io;

readonly & json DEFAULT_PAYLOAD = {
    itemName: string `Panasonic 32" LED TV`,
    itemCode: "ITM30029",
    previousPrice: 32999.00,
    newPrice: 28999.00,
    currencyCode: "SEK"
};

type OAuth2Config record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
    string trustStore;
    string trustStorePassword;
|};

configurable OAuth2Config oauth2Config = ?;

final string hubUrl = os:getEnv("HUB_URL") == "" ? "https://lb:9090/hub" : os:getEnv("HUB_URL");
final string topicName = os:getEnv("TOPIC_NAME") == "" ? "priceUpdate" : os:getEnv("TOPIC_NAME");
final int numberOfRequests = os:getEnv("NUMBER_OF_REQUESTS") == "" ? 10 : check int:fromString(os:getEnv("NUMBER_OF_REQUESTS"));
final int parallelism = os:getEnv("PARALLELISM") == "" ? 1 : check int:fromString(os:getEnv("PARALLELISM"));
final string payloadSize = os:getEnv("PAYLOAD_SIZE") == "" ? "100B": os:getEnv("PAYLOAD_SIZE");
final readonly & json payload = check io:fileReadJson(string `./resources/payloads/payload_${payloadSize}.json`).cloneReadOnly();
