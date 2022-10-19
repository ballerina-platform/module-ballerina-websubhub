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

import ballerina/http;
import ballerina/websubhub;
import ballerinax/kafka;
import kafkaHub.connections as conn;
import kafkaHub.persistence as persist;
import kafkaHub.config;

public function main() returns error? {    
    // Dispatch `hub` restart event to topics/subscriptions
    _ = check persist:persistRestartEvent();
    // Assign EventHub partitions to system-consumers
    _ = check assignPartitionsToSystemConsumers();
    
    // Initialize the Hub
    _ = @strand { thread: "any" } start syncRegsisteredTopicsCache();
    _ = @strand { thread: "any" } start syncSubscribersCache();
    
    // Start the HealthCheck Service
    http:Listener httpsListener = check new (config:HUB_PORT,
        host = config:HOST, 
        secureSocket = {
            key: {
                certFile: config:SSL_CERT_PATH,
                keyFile: config:SSL_KEY_PATH
            }
        }
    );
    check httpsListener.attach(healthCheckService, "/health");
    // Start the Hub
    websubhub:Listener hubListener = check new (httpsListener);
    check hubListener.attach(hubService, "hub");
    check hubListener.'start();

    check initClearTextHubListener();

    lock {
        startupCompleted = true;
    }
}

function assignPartitionsToSystemConsumers() returns error? {
    // assign relevant partitions to consolidated-topics consumer
    kafka:TopicPartition consolidatedTopicsPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_TOPICS_PARTITION
    };
    check conn:registeredTopicsConsumer->assign([consolidatedTopicsPartition]);

    // assign relevant partitions to consolidated-subscribers consumer
    kafka:TopicPartition consolidatedSubscribersPartition = {
        topic: config:SYSTEM_INFO_HUB,
        partition: config:CONSOLIDATED_WEBSUB_SUBSCRIBERS_PARTITION
    };
    check conn:subscribersConsumer->assign([consolidatedSubscribersPartition]);
}

function initClearTextHubListener() returns error? {
    http:Listener httpListener = check new (config:HUB_PORT_CLEAR_TEXT,
        host = config:HOST
    );

    check httpListener.attach(healthCheckService, "/health");

    websubhub:Listener clearTextHubListener = check new (httpListener);
    check clearTextHubListener.attach(hubService, "hub");
    check clearTextHubListener.'start();
}
