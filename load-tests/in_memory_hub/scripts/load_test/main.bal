// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/websubhub;
import ballerina/log;
import ballerina/io;
import ballerina/time;
import ballerina/lang.runtime;
import ballerina/websub;

isolated int receivedCount = 0;

isolated function incrementReceivedCount() {
    lock {
        receivedCount += 1;
    }
}

isolated function retrieveReceivedCount() returns int {
    lock {
        return receivedCount;
    }
}

websub:SubscriberService subscriberService = @websub:SubscriberServiceConfig {
    target: ["http://bal.perf.test/hub", "test"],
    callback: "http://bal.perf.test.sub/sub",
    unsubscribeOnShutdown: true,
    leaseSeconds: 36000
} service object {
    remote function onEventNotification(readonly & websub:ContentDistributionMessage msg) returns websub:Acknowledgement {
        incrementReceivedCount();
        return websub:ACKNOWLEDGEMENT;
    }
};

public function main(string label, string output_csv_path) returns error? {
    websubhub:PublisherClient publisherClient = check new("http://bal.perf.test/hub");
    
    // register the topic
    _ = check publisherClient->registerTopic("test");

    // start the subscriber
    websub:Listener subListener = check new(9100);
    check subListener.attach(subscriberService, "sub");
    check subListener.'start();
    // wait until the listener starts
    runtime:sleep(1);

    int sentCount = 0;
    int errorCount = 0;
    time:Utc startedTime = time:utcNow();
    time:Utc expiaryTime = time:utcAddSeconds(startedTime, 1 * 60);
    while time:utcDiffSeconds(expiaryTime, time:utcNow()) > 0D {
        json params = {event: "event"};
        websubhub:Acknowledgement|websubhub:UpdateMessageError response = publisherClient->publishUpdate("test", params);
        sentCount += 1;
        if response is websubhub:UpdateMessageError {
            errorCount += 1;
        }
    }

    // wait until the content-delivery finishes
    runtime:sleep(60);

    // process test-results
    decimal time = time:utcDiffSeconds(time:utcNow(), startedTime);
    int receivedCount = retrieveReceivedCount();
    log:printInfo("Test summary: ", sent = sentCount, received = receivedCount, errors = errorCount, duration = time);
    any[] results = [label, sentCount, <float>time/<float>receivedCount, 0, 0, 0, 0, 0, 0, <float>errorCount/<float>sentCount, 
        <float>receivedCount/<float>time, 0, 0, time:utcNow()[0], 0, 1];
    check writeResultsToCsv(results, output_csv_path);

    // gracefully shutdown subscriber
    check subListener.gracefulStop();
    
    // unregister the `topic`
    _ = check publisherClient->deregisterTopic("test");
}

function writeResultsToCsv(any[] results, string output_path) returns error? {
    string[][] summary_data = check io:fileReadCsv(output_path);
    string[] final_results = [];
    foreach var result in results {
        final_results.push(result.toString());
    }
    summary_data.push(final_results);
    check io:fileWriteCsv(output_path, summary_data);
}
