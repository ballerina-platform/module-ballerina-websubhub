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
import ballerina/lang.runtime;
import ballerina/time;
import ballerinax/kafka;

public function main() returns error? {
    io:println("Starting Kafka subscribers...");
    time:Utc startTime = time:utcNow();
    int messageCount = 0;

    future<int|error?>[] results = [];
    foreach int i in 0 ..< numberOfSubscribers {
        future<int|error?> result = start receiveMessagesFromKafka(i);
        results.push(result);
    }

    foreach var resultFuture in results {
        int|error? result = check wait resultFuture;
        if result is int {
            messageCount += result;
        } else if result is error {
            io:println("Error occurred while receiving messages: ", result.toString());
        }
        break;
    }

    time:Utc endTime = time:utcNow();

    decimal time = time:utcDiffSeconds(endTime, startTime);
    float average = <float>time / <float>messageCount;
    float throughput = <float>messageCount / <float>time;

    io:println("### ", "Total requests : ", numberOfRequests, " Subscribers : ", numberOfSubscribers, " ###");

    io:println("# of delivered messages       : ", messageCount);
    io:println("Time taken                    : ", time);
    io:println("Average                       : ", average);
    io:println("Throughput                    : ", throughput);
}

isolated function receiveMessagesFromKafka(int consumerIdx) returns int|error? {
    boolean scheduledForShutdown = false;
    int counter = 0;

    kafka:ConsumerConfiguration kafkaConsumerConfig = {
        groupId: consumerGroup,
        secureSocket: secureSocketConfig,
        securityProtocol: kafka:PROTOCOL_SSL,
        maxPollRecords: 50,
        topics: topicName
    };
    kafka:Consumer kafkaConsumer = check new (kafkaUrl, kafkaConsumerConfig);
    while true {
        readonly & kafka:BytesConsumerRecord[] records = check kafkaConsumer->poll(5);
        counter += records.length();
        if scheduledForShutdown {
            break;
        }
        if records.length() == 0 {
            runtime:sleep(1);
            scheduledForShutdown = true;
        }
    }

    io:println("Completed receiving messages for consumer: ", consumerIdx, " received message count: ", counter);

    return counter;
}
