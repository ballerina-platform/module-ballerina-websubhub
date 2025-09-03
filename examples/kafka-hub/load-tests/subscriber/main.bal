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
import ballerina/lang.runtime;
import ballerina/time;
import ballerina/websub;
import ballerina/websubhub;

isolated time:Utc? startTime = ();
isolated time:Utc? endTime = ();
isolated int messageCount = 0;

isolated function incrementAndGet() returns int {
    lock {
        messageCount += 1;
        return messageCount;
    }
}

isolated function setStartTime(time:Utc time) {
    lock {
        startTime = time;
    }
}

isolated function getStartTime() returns time:Utc? {
    lock {
        return startTime;
    }
}

isolated function setEndTime(time:Utc time) {
    lock {
        endTime = time;
    }
}

isolated function getEndTime() returns time:Utc? {
    lock {
        return endTime;
    }
}

public function main() returns error? {
    // Init with creating the topic
    websubhub:PublisherClient websubHubClientEP = check new (hubUrl,
        // auth = {
        //     tokenUrl: oauth2Config.tokenUrl,
        //     clientId: oauth2Config.clientId,
        //     clientSecret: oauth2Config.clientSecret,
        //     scopes: ["register_topic"],
        //     clientConfig: {
        //         secureSocket: {
        //             cert: {
        //                 path: oauth2Config.trustStore,
        //                 password: oauth2Config.trustStorePassword
        //             }
        //         }
        //     }
        // },
        secureSocket = {
            cert: {
                path: "./resources/subscriber.truststore.jks",
                password: "password"
            }
        }
    );
    websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError response = websubHubClientEP->registerTopic(topicName);
    if response is websubhub:TopicRegistrationError {
        int statusCode = response.detail().statusCode;
        if http:STATUS_CONFLICT != statusCode {
            return response;
        }
    }

    // Register subscribers with the `hub`
    websub:Listener wbsbListener = check getListener();
    foreach int i in 0 ..< numberOfSubscribers {
        SubscriberService svc = new ();
        string svcPath = string `JuApTOXq19${i}`;
        check wbsbListener.attachWithConfig(svc, getSubscriberConfig(), svcPath);
    }
    check wbsbListener.'start();
    runtime:registerListener(wbsbListener);

    io:println("Started listening to ", topicName);

    while getStartTime() is () {
        runtime:sleep(5);
    }

    io:println("Starting load tests...");

    while getEndTime() is () {
        lock {
	        io:println("Messages received : ", messageCount);
        }
        runtime:sleep(5);
    }

    check wbsbListener.gracefulStop();

    decimal time = getMessageDeliveryDuration();
    int deliveredMsgCount;
    lock {
        deliveredMsgCount = messageCount;
    }
    float average = <float>time / <float>deliveredMsgCount;
    float throughput = <float>deliveredMsgCount / <float>time;

    io:println("### ", "Total requests : ", numberOfRequests, " Subscribers : ", numberOfSubscribers);

    io:println("# of delivered messages       : ", deliveredMsgCount);
    io:println("Time taken                    : ", time);
    io:println("Average                       : ", average);
    io:println("Throughput                    : ", throughput);
}

isolated function getSubscriberConfig() returns websub:SubscriberServiceConfiguration {
    return {
        target: [hubUrl, topicName],
        httpConfig: {
            secureSocket: {
                cert: {
                    path: "./resources/subscriber.truststore.jks",
                    password: "password"
                }
            }
        },
        unsubscribeOnShutdown: true,
        customParams: getCustomParams()
    };
}

isolated function getMessageDeliveryDuration() returns decimal {
    time:Utc? startTime = getStartTime();
    if startTime is () {
        return -1;
    }

    time:Utc? endTime = getEndTime();
    if endTime is () {
        return time:utcDiffSeconds(time:utcNow(), startTime);
    }

    return time:utcDiffSeconds(endTime, startTime);
}
