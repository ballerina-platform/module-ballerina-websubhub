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

import ballerina/file;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/websub;
import ballerina/websubhub;

configurable string HUB = ?;
configurable string TOPIC = ?;
configurable string CALLBACK_URL = ?;
configurable string RESULTS_FILE_PATH = ?;
final string SECRET = "test123$";

final websub:Listener websubListener = check new (9090);
final readonly & json[] messages = [ADD_NEW_USER_MESSAGE, LOGIN_SUCCESS_MESSAGE];

type STATUS "successful" | "failed" | "partial";
final string[] & readonly documentationCsvHeaders = ["Label", "Sent Count", "Received Count", "Status"];

public function main() returns error? {
    _ = check initializeTests();
    any[][] testResults = [];

    websubhub:PublisherClient publisherClientEp = check new(HUB);
    websubhub:TopicRegistrationSuccess|error registrationResponse = registerTopic(publisherClientEp);
    any[] topicRegResult = ["TOPIC_REGISTRATION", 1, 1, registrationResponse is error ? "failed" : "successful"];
    testResults.push(topicRegResult);

    error? subscriptionStatus = subscribe(websubListener, subscriberService);
    STATUS subStatus = "successful";
    if subscriptionStatus is error {
        subStatus = "failed";
    } else {
        runtime:sleep(60);
        subStatus = isSubscriptionSuccessful() ? "successful" : "failed";
    }
    any[] subscriptionResult = ["SUBSCRIPTION", 1, 1, subStatus];
    testResults.push(subscriptionResult);

    int successfulContentPublishCount = publishContent(publisherClientEp);
    STATUS contentPublishStatus = getReceivedNotificationCount() == successfulContentPublishCount ? "successful" : "failed";
    any[] contentPublishResults = ["CONTENT_PUBLISH", messages.length(), getReceivedNotificationCount(), contentPublishStatus];
    testResults.push(contentPublishResults);

    error? unsubscriptionStatus = subscribe(websubListener, subscriberService);
    STATUS unubStatus = "successful";
    if unsubscriptionStatus is error {
        unubStatus = "failed";
    } else {
        runtime:sleep(60);
        unubStatus = isUnsubscriptionSuccessful() ? "successful" : "failed";
    }
    any[] unsubscriptionResult = ["UNSUBSCRIPTION", 1, 1, unubStatus];
    testResults.push(unsubscriptionResult);

    websubhub:TopicDeregistrationSuccess|error deRegistrationResponse = deregisterTopic(publisherClientEp);
    any[] topicDeRegResult = ["TOPIC_DEREGISTRATION", 1, 1, deRegistrationResponse is error ? "failed" : "successful"];
    testResults.push(topicDeRegResult);

    return writeResultsToCsv(testResults, RESULTS_FILE_PATH);
}

function initializeTests() returns error? {
    boolean fileExists = check file:test(RESULTS_FILE_PATH, file:EXISTS);
    if !fileExists {
        check io:fileWriteCsv(RESULTS_FILE_PATH, [documentationCsvHeaders]);
    }
}

isolated function registerTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicRegistrationSuccess|error {
    return publisherClientEp->registerTopic(TOPIC);
}

isolated function subscribe(websub:Listener websubListener, websub:SubscriberService subscriberService) returns error? {
    websub:SubscriberServiceConfiguration config = {
        target: [HUB, TOPIC],
        callback: CALLBACK_URL,
        secret: SECRET,
        unsubscribeOnShutdown: true
    };
    check websubListener.attachWithConfig(subscriberService, config);
    return websubListener.'start();
}

isolated function publishContent(websubhub:PublisherClient publisherClientEp) returns int {
    int sentCount = 0;
    foreach json message in messages {
        sentCount += 1;
        var publishResponse = publisherClientEp->publishUpdate(TOPIC, message);
        if publishResponse is websubhub:UpdateMessageError {
            log:printWarn("Error occurred while publishing content");
        }
    }
    return sentCount;
}

isolated function unsubscribe(websub:Listener websubListener) returns error? {
    return websubListener.gracefulStop();
}

isolated function deregisterTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicDeregistrationSuccess|error {
    return publisherClientEp->deregisterTopic(TOPIC);
}

isolated function writeResultsToCsv(any[][] results, string output_path) returns error? {
    string[][] final_results = [];
    foreach any[] resultLine in results {
        string[] constructedResultLine = [];
        foreach var result in resultLine {
            constructedResultLine.push(result.toString());
        }
        final_results.push(constructedResultLine);
    }
    check io:fileWriteCsv(output_path, final_results, io:APPEND);
}
