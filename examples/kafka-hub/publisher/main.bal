// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/io;
import ballerina/os;
import ballerina/websubhub;
import ballerina/lang.runtime;

readonly & json[] messages = [
    {
        itemName: string `Panasonic 32" LED TV`,
        itemCode: "ITM30029",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    },
    {
        itemName: string `LUMIX-camera DC-BS1H`,
        itemCode: "ITM30030",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    },
    {
        itemName: string `Panasonic Steam Iron NI-S530`,
        itemCode: "ITM30031",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    },
    {
        itemName: string `Panasonic 32" LED TV`,
        itemCode: "ITM30029",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    },
    {
        itemName: string `Panasonic 32" LED TV`,
        itemCode: "ITM30029",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    }
];

readonly &json DEFAULT_PAYLOAD = {
    itemName: string `Panasonic 32" LED TV`,
    itemCode: "ITM30029",
    previousPrice: 32999.00,
    newPrice: 28999.00,
    currencyCode: "SEK"
};

final string topicName = os:getEnv("TOPIC_NAME") == "" ? "priceUpdate" : os:getEnv("TOPIC_NAME");
final json payload = os:getEnv("PAYLOAD") == "" ? DEFAULT_PAYLOAD : check os:getEnv("PAYLOAD").fromJsonString();
final string hubUrl = os:getEnv("HUB_URL") == "https://lb:9090/hub" ? "priceUpdate" : os:getEnv("HUB_URL");
final boolean bulkMode = os:getEnv("BULK_MODE_ENABLED") == "true";

type OAuth2Config record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
    string trustStore;
    string trustStorePassword;
|};

configurable OAuth2Config oauth2Config = ?;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new (hubUrl,
        auth = {
            tokenUrl: oauth2Config.tokenUrl,
            clientId: oauth2Config.clientId,
            clientSecret: oauth2Config.clientSecret,
            scopes: ["register_topic", "update_content"],
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: oauth2Config.trustStore,
                        password: oauth2Config.trustStorePassword
                    }
                }
            }
        },
        secureSocket = {
            cert: {
                path: "./resources/publisher.truststore.jks",
                password: "password"
            }
        }
    );
    if !bulkMode {
        websubhub:Acknowledgement response = check websubHubClientEP->publishUpdate(topicName, payload);
        io:println("Receieved content-publish result: ", response);
        return;
    }
    int counter = 1;
    int idx = 0;
    while true {
        json message = messages[idx];
        websubhub:Acknowledgement response = check websubHubClientEP->publishUpdate(topicName, message);
        io:println("Receieved content-publish result: ", response.statusCode);
        idx = counter / messages.length();
        counter += 1;
        runtime:sleep(1);
    }
}
