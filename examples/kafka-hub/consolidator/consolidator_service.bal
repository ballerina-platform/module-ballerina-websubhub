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

import ballerina/log;
import consolidatorService.config;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;
import consolidatorService.types;


isolated function startConsolidator() returns error? {
    do {
        while true {
            types:EventConsumerRecord[] records = check conn:websubEventConsumer->poll(config:POLLING_INTERVAL);
            foreach types:EventConsumerRecord currentRecord in records {
                error? result = processPersistedData(currentRecord.value);
                if result is error {
                    log:printError("Error occurred while processing received event ", 'error = result);
                }
            }
        }
    } on fail var e {
        log:printError("Error occurred while consuming records", 'error = e);
        _ = check conn:websubEventConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        return e;
    }
}

isolated function processPersistedData(json event) returns error? {
    string hubMode = check event.hubMode;
    match event.hubMode {
        "register" => {
            check processTopicRegistration(event);
        }
        "deregister" => {
            check processTopicDeregistration(event);
        }
        "subscribe" => {
            check processSubscription(event);
        }
        "unsubscribe" => {
            check processUnsubscription(event);
        }
        "restart" => {
            check processRestartEvent();
        }
        _ => {
            return error(string `Error occurred while deserializing subscriber events with invalid hubMode [${hubMode}]`);
        }
    }
}

isolated function processRestartEvent() returns error? {
    lock {
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
    lock {
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}
