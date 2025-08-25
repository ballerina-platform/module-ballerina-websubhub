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
import ballerina/time;
import ballerina/websubhub;

final websubhub:PublisherClient websubHubClientEP = check new (hubUrl, httpVersion = http:HTTP_2_0, timeout = 120,
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
    websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError topicReg = websubHubClientEP->registerTopic(topicName);
    if topicReg is websubhub:TopicRegistrationError {
        int statusCode = topicReg.detail().statusCode;
        if http:STATUS_CONFLICT != statusCode {
            return topicReg;
        }
    }

    io:println("Starting load tests...");

    time:Utc startedTime = time:utcNow();
    int successCount = 0;
    int failureCount = 0;

    int numberOfRounds = numberOfRequests / parallelism;

    foreach int i in 0 ..< numberOfRounds {
        future<websubhub:Acknowledgement|websubhub:UpdateMessageError>[] results = executeRound(parallelism);
        foreach var resultFuture in results {
            websubhub:Acknowledgement|websubhub:UpdateMessageError result = wait resultFuture;
            if result is websubhub:Acknowledgement {
                successCount += 1;
            } else {
                failureCount += 1;
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

function executeRound(int parallelism) returns future<websubhub:Acknowledgement|websubhub:UpdateMessageError>[] {
    future<websubhub:Acknowledgement|websubhub:UpdateMessageError>[] results = [];
    foreach int i in 0 ..< parallelism {
        future<websubhub:Acknowledgement|websubhub:UpdateMessageError> result = start websubHubClientEP->publishUpdate(topicName, payload);
        results.push(result);
    }
    return results;
}
