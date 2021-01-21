// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/io;
import ballerina/http;
import ballerina/test;

service /callback on new http:Listener(9092) {
    resource function post success(http:Caller caller, http:Request req) {
        io:println("Hub Content Distribution message received : ", req.getTextPayload());
        printHeaders(req);
        var result = caller->respond("Content Delivery Success");
    }

    resource function post deleted(http:Caller caller, http:Request req) {
        io:println("Hub Content Distribution message received [SUB-TERMINATE] : ", req.getTextPayload());
        http:Response res = new ();
        res.statusCode = http:STATUS_GONE;
        var result = caller->respond(res);
    }
}

isolated function printHeaders(http:Request req) {
    string[] headerNames = req.getHeaderNames();
    string[] headers = [];
    foreach var header in headerNames {
        var headerValues = req.getHeaders(header);
        if (headerValues is string[]) {
            var concatenatedHeaderValues = " ,".'join(...<string[]>headerValues);
            headers.push(header + " : " + concatenatedHeaderValues);
        }
    }
    var headerString = ";".'join(...headers);
    io:println("Headers : ", headerString); 
}

isolated function retrieveSubscriptionMsg(string callbackUrl) returns Subscription {
    return {
        hub: "https://hub.com", 
        hubMode: "subscribe", 
        hubCallback: callbackUrl, 
        hubTopic: "https://topic.com", 
        hubSecret: "secretkey1",
        rawRequest: new http:Request()
    };
}

@test:Config {
}
function testTextContentDelivery() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9092/callback/success");

    HubClient hubClientEP = checkpanic new(subscriptionMsg);

    ContentDistributionMessage msg = {content: "This is sample content delivery"};

    var publishResponse = hubClientEP->notifyContentDistribution(msg);
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
        test:assertEquals(publishResponse.body, msg.content);
    } else {
       test:assertFail("Content Publishing Failed.");
    }
}

@test:Config {
}
function testJsonContentDelivery() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9092/callback/success");

    HubClient hubClientEP = checkpanic new(subscriptionMsg);
    
    json publishedContent = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };

    ContentDistributionMessage msg = {content: publishedContent};

    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
        test:assertEquals(publishResponse.body, msg.content);
    } else {
       test:assertFail("Content Publishing Failed.");
    }
}

@test:Config {
}
function testXmlContentDelivery() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9092/callback/success");

    HubClient hubClientEP = checkpanic new(subscriptionMsg);
    
    xml publishedContent = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;

    ContentDistributionMessage msg = {content: publishedContent};

    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
        test:assertEquals(publishResponse.body, msg.content);
    } else {
       test:assertFail("Content Publishing Failed.");
    }
}

@test:Config {
}
function testByteArrayContentDelivery() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9092/callback/success");

    HubClient hubClientEP = checkpanic new(subscriptionMsg);
    
    byte[] publishedContent = "This is sample content".toBytes();

    ContentDistributionMessage msg = {content: publishedContent};

    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
    } else {
       test:assertFail("Content Publishing Failed.");
    }    
}

@test:Config {
}
function testSubscriptionDeleted() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9092/callback/deleted");

    HubClient hubClientEP = checkpanic new(subscriptionMsg);

    var publishResponse = hubClientEP->notifyContentDistribution({content: "This is sample content delivery"});
    var expectedResponse = "Subscription to topic [https://topic.com] is terminated by the subscriber";
    if (publishResponse is SubscriptionDeletedError) {
        test:assertEquals(publishResponse.message(), expectedResponse);
    } else {
       test:assertFail("Content Publishing Failed.");
    }    
}