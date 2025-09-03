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

import ballerina/io;
import ballerina/time;
import ballerinax/kafka;

public function main() returns error? {
    io:println("Starting load tests...");

    time:Utc startedTime = time:utcNow();
    int successCount = 0;
    int failureCount = 0;

    int numberOfRounds = numberOfRequests / parallelism;

    foreach int i in 0 ..< numberOfRounds {
        future<kafka:Error?>[] results = executeRound(parallelism);
        foreach var resultFuture in results {
            kafka:Error? result = wait resultFuture;
            if result is kafka:Error {
                io:println("Error occurred while sending the content publish request: ", result);
                failureCount += 1;
            } else {
                successCount += 1;
            }
        }
        io:println("Completed ", parallelism * (i + 1), " requests");
    }

    decimal time = time:utcDiffSeconds(time:utcNow(), startedTime);
    float average = <float>time / <float>successCount;
    float errorRate = <float>failureCount / <float>successCount;
    float throughput = <float>successCount / <float>time;

    io:println("### ", "Total requests : ", numberOfRequests, " Parallelism : ", parallelism, " Payload Size : ", payloadSize, " ###");

    io:println("# of successful requests : ", successCount);
    io:println("# of failed requests     : ", failureCount);
    io:println("Total time taken (s)    : ", time);
    io:println("Average                  : ", average);
    io:println("Error rate               : ", errorRate);
    io:println("Throughput (req/s)       : ", throughput);
}

isolated function sendContentUpdate(string topicName, json payload) returns kafka:Error? {
    return statePersistProducer->send({topic: topicName, value: payload});
}

function executeRound(int parallelism) returns future<kafka:Error?>[] {
    future<kafka:Error?>[] results = [];
    foreach int i in 0 ..< parallelism {
        future<kafka:Error?> result = start sendContentUpdate(topicName, payload);
        results.push(result);
    }
    return results;
}
