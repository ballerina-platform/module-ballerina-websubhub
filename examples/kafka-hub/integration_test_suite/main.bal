// Copyright (c) 2022, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/file;
import ballerina/io;
import ballerina/websub;
import ballerina/websubhub;

configurable string HUB = ?;
configurable string TOPIC = ?;
configurable string RESULTS_FILE_PATH = ?;

final string SECRET = "test123$";
final websub:Listener websubListener = check new (9090);
final readonly & json[] messages = [ADD_NEW_USER_MESSAGE, LOGIN_SUCCESS_MESSAGE];
final string[] & readonly documentationCsvHeaders = ["Label", "# Test Scenarios", "Success %", "Status"];

enum STATUS {
    SUCCESSFUL,
    FAILED,
    PARTIAL
}

type TEST_RESULT [string, int, int, STATUS];
const int TOTAL_SCENARIOS = 3;

public function main() returns error? {
    _ = check initializeTests();
    int failedScenarios = 0;
    
    websubhub:PublisherClient publisherClientEp = check new(HUB);
    websubhub:TopicRegistrationSuccess|error registrationResponse = registerTopic(publisherClientEp);
    if registrationResponse is error {
        failedScenarios += 1;
    }

    error? publishResponse = publishContent(publisherClientEp);
    if publishResponse is error {
        failedScenarios += 1;
    }

    websubhub:TopicDeregistrationSuccess|error deRegistrationResponse = deregisterTopic(publisherClientEp);
    if deRegistrationResponse is error {
        failedScenarios += 1;
    }
    
    _ = check websubListener.gracefulStop();
    STATUS testStatus = failedScenarios == 0 ? SUCCESSFUL : TOTAL_SCENARIOS == failedScenarios ? FAILED : PARTIAL;
    any[] results = ["Azure WebSubHub", TOTAL_SCENARIOS, <float>(TOTAL_SCENARIOS - failedScenarios)/<float>TOTAL_SCENARIOS, testStatus];
    return writeResultsToCsv(RESULTS_FILE_PATH, results);
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

isolated function publishContent(websubhub:PublisherClient publisherClientEp) returns error? {
    foreach json message in messages {
        _ = check publisherClientEp->publishUpdate(TOPIC, message);
    }
}

isolated function deregisterTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicDeregistrationSuccess|error {
    return publisherClientEp->deregisterTopic(TOPIC);
}

function writeResultsToCsv(string output_path, any[] results) returns error? {
    string[][] summary_data = check io:fileReadCsv(output_path);
    string[] final_results = [];
    foreach var result in results {
        final_results.push(result.toString());
    }
    summary_data.push(final_results);
    check io:fileWriteCsv(output_path, summary_data);
}
