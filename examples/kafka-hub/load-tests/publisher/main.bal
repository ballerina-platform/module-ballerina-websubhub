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

import ballerina/http;
import ballerina/io;
import ballerina/mime;
import ballerina/time;

final http:Client clientEp = check new (hubUrl, httpVersion = http:HTTP_2_0, timeout = 120,
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

public function main() returns error? {
    http:Response topicReg = check sendTopicReg(topicName);
    io:println("Topic registration response status : ", topicReg.statusCode);
    if topicReg.statusCode < 200 && topicReg.statusCode >= 300 {
        if http:STATUS_CONFLICT !== topicReg.statusCode {
            return error(string `Invalid response received: ${topicReg.statusCode}`);
        }
    }

    io:println("Starting load tests...");

    time:Utc startedTime = time:utcNow();
    int successCount = 0;
    int failureCount = 0;

    int numberOfRounds = numberOfRequests / parallelism;

    foreach int i in 0 ..< numberOfRounds {
        future<http:Response|error>[] results = executeRound(parallelism);
        foreach var resultFuture in results {
            http:Response|error result = wait resultFuture;
            if result is error {
                io:println("Error occurred while sending the content publish request: ", result);
                failureCount += 1;
            } else {
                int statusCode = result.statusCode;
                if statusCode != http:STATUS_OK {
                    io:println("Received error response from the server, status: ", statusCode, " message: ", result.getTextPayload());
                    failureCount += 1;
                } else {
                    successCount += 1;
                }
            }
        }
    }

    decimal time = time:utcDiffSeconds(time:utcNow(), startedTime);
    float average = <float>time / <float>successCount;
    float errorRate = <float>failureCount / <float>successCount;
    float throughput = <float>successCount / <float>time;

    io:println("### ", "Total requests : ", numberOfRequests, " Parallelism : ", parallelism, " Payload Size : ", payloadSize, " ###");

    io:println("# of successful requests : ", successCount);
    io:println("# of failed requests     : ", failureCount);
    io:println("Average                  : ", average);
    io:println("Error rate               : ", errorRate);
    io:println("Throughput               : ", throughput);
}

isolated function sendTopicReg(string topicName) returns http:Response|error {
    http:Request request = new;
    request.setTextPayload(string `hub.mode=register&hub.topic=${topicName}`);
    request.setHeader("Content-Type", mime:APPLICATION_FORM_URLENCODED);
    return clientEp->post("", request);
}

isolated function sendContentUpdate(string topicName, json payload) returns http:Response|error {
    string query = string `?hub.mode=publish&hub.topic=${topicName}`;
    return clientEp->post(query, payload);
}

function executeRound(int parallelism) returns future<http:Response|error>[] {
    future<http:Response|error>[] results = [];
    foreach int i in 0 ..< parallelism {
        future<http:Response|error> result = start sendContentUpdate(topicName, payload);
        results.push(result);
    }
    return results;
}
