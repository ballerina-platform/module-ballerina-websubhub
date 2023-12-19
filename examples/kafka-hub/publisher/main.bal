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

import ballerina/websubhub;
import ballerina/io;
import ballerina/os;

string topicName = os:getEnv("TOPIC_NAME") == "" ? "priceUpdate" : os:getEnv("TOPIC_NAME");

type OAuth2Config record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
    string trustStore;
    string trustStorePassword;
|};
configurable OAuth2Config oauth2Config = ?;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new("https://localhost:9090/hub",
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
            cert: "./resources/server.crt"
        }
    );
    json params = {
        itemName: string `Panasonic 32" LED TV`,
        itemCode: "ITM30029",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    };
    websubhub:Acknowledgement response = check websubHubClientEP->publishUpdate(topicName, params);
    io:println("Receieved content-publish result: ", response);
}
