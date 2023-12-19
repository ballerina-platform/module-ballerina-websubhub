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

import ballerina/websub;
import ballerina/log;
import ballerina/http;
import ballerina/websubhub;
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

listener websub:Listener securedSubscriber = new(9100,
    host = "localhost",
    secureSocket = {
        key: {
            certFile: "./resources/server.crt",
            keyFile: "./resources/server.key"
        }
    }
);

function init() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new("https://localhost:9090/hub",
        auth = {
            tokenUrl: oauth2Config.tokenUrl,
            clientId: oauth2Config.clientId,
            clientSecret: oauth2Config.clientSecret,
            scopes: ["register_topic"],
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
    websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError response = websubHubClientEP->registerTopic(topicName);
    if response is websubhub:TopicRegistrationError {
        int statusCode = response.detail().statusCode;
        if http:STATUS_CONFLICT != statusCode {
            return response;
        }
    }
}

@websub:SubscriberServiceConfig { 
    target: ["https://localhost:9090/hub", topicName],
    httpConfig: {
        auth : {
            tokenUrl: oauth2Config.tokenUrl,
            clientId: oauth2Config.clientId,
            clientSecret: oauth2Config.clientSecret,
            scopes: ["subscribe"],
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: oauth2Config.trustStore,
                        password: oauth2Config.trustStorePassword
                    }
                }
            }
        },
        secureSocket : {
            cert: "./resources/server.crt"
        }
    },
    unsubscribeOnShutdown: true
} 
service /JuApTOXq19 on securedSubscriber {
    
    remote function onSubscriptionVerification(websub:SubscriptionVerification msg) 
        returns websub:SubscriptionVerificationSuccess {
        log:printInfo(string `Successfully subscribed for notifications on topic [${topicName}]`);
        return websub:SUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) returns error? {
        json notification = check event.content.ensureType();
        log:printInfo("Received notification", content = notification);
    }
}
