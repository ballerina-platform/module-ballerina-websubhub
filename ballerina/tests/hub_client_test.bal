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

const string CONTENT_DELIVERY_SUCCESS = "Content Delivery Success";

isolated int retrySuccessCount = 0;

isolated function incrementSuccessCount() {
    lock {
        retrySuccessCount += 1;
    }
}

isolated function retrieveSuccessCount() returns int {
    lock {
        return retrySuccessCount;
    }
}

service /callback on new http:Listener(9094) {
    isolated resource function post success(http:Caller caller, http:Request req) returns error? {
        io:println("Hub Content Distribution message received : ", req.getTextPayload());
        return caller->respond("Content Delivery Success");
    }

    isolated resource function post deleted(http:Caller caller, http:Request req) returns error? {
        io:println("Hub Content Distribution message received [SUB-TERMINATE] : ", req.getTextPayload());
        http:Response res = new ();
        res.statusCode = http:STATUS_GONE;
        return caller->respond(res);
    }

    resource function post retrySuccess(http:Caller caller, http:Request req) returns error? {
        io:println("Hub Content Distribution message received [RETRY_SUCCESS] : ", req.getTextPayload());
        incrementSuccessCount();
        if (retrieveSuccessCount() == 3) {
            return caller->respond("Content Delivery Success");
        } else {
            http:Response res = new ();
            res.statusCode = http:STATUS_BAD_REQUEST;
            return caller->respond(res);
        }
    }

    isolated resource function post retryFailed(http:Caller caller, http:Request req) returns error? {
        io:println("Hub Content Distribution message received [RETRY_FAILED] : ", req.getTextPayload());
        http:Response res = new ();
        res.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
        return caller->respond(res);
    }

    isolated resource function post noContent(http:Caller caller, http:Request req) returns error? {
        io:println("Hub Content Distribution message received [NO_RESPONSE] : ", req.getTextPayload());
        return caller->respond();
    }
}

isolated function retrieveSubscriptionMsg(string callbackUrl) returns Subscription {
    return {
        hub: "https://hub.com", 
        hubMode: "subscribe", 
        hubCallback: callbackUrl, 
        hubTopic: "https://topic.com", 
        hubSecret: "secretkey1"
    };
}

Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9094/callback/success");
HubClient contentDeliveryClient = check new(subscriptionMsg);

@test:Config {
}
function testTextContentDelivery() returns error? {
    ContentDistributionMessage msg = {content: "This is sample content delivery"};
    ContentDistributionSuccess publishResponse = check contentDeliveryClient->notifyContentDistribution(msg);
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, CONTENT_DELIVERY_SUCCESS);
}

@test:Config {
}
function testJsonContentDelivery() returns error? {
    json publishedContent = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    ContentDistributionMessage msg = {content: publishedContent};
    ContentDistributionSuccess publishResponse = check contentDeliveryClient->notifyContentDistribution(msg);   
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, CONTENT_DELIVERY_SUCCESS);
}

@test:Config {
}
function testXmlContentDelivery() returns error? {
    xml publishedContent = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;
    ContentDistributionMessage msg = {content: publishedContent};
    ContentDistributionSuccess publishResponse = check contentDeliveryClient->notifyContentDistribution(msg);   
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, CONTENT_DELIVERY_SUCCESS);
}

@test:Config {
}
function testByteArrayContentDelivery() returns error? {
    byte[] publishedContent = "This is sample content".toBytes();
    ContentDistributionMessage msg = {content: publishedContent};
    ContentDistributionSuccess publishResponse = check contentDeliveryClient->notifyContentDistribution(msg);   
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, CONTENT_DELIVERY_SUCCESS);   
}

@test:Config {
}
function testUrlEncodedContentDelivery() returns error? {
    map<string> publishedContent = {
        "query1": "value1",
        "query2": "value2"
    };
    ContentDistributionMessage msg = {
        contentType: "application/x-www-form-urlencoded",
        content: publishedContent
    };
    ContentDistributionSuccess publishResponse = check contentDeliveryClient->notifyContentDistribution(msg);   
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, CONTENT_DELIVERY_SUCCESS);
}

@test:Config {
}
isolated function testContentDeliveryWithNoResponse() returns error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9094/callback/noContent");
    HubClient hubClientEP = check new(subscriptionMsg);
    byte[] publishedContent = "This is sample content".toBytes();
    ContentDistributionMessage msg = {content: publishedContent};
    ContentDistributionSuccess publishResponse = check hubClientEP->notifyContentDistribution(msg);   
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, ());   
}

@test:Config {
}
isolated function testSubscriptionDeleted() returns error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9094/callback/deleted");
    HubClient hubClientEP = check new(subscriptionMsg);
    var publishResponse = hubClientEP->notifyContentDistribution({content: "This is sample content delivery"});
    string  expectedResponse = "Subscription to topic [https://topic.com] is terminated by the subscriber";
    if (publishResponse is SubscriptionDeletedError) {
        test:assertEquals(publishResponse.message(), expectedResponse);
    } else {
       test:assertFail("Subscription deleted verification failed.");
    }    
}

@test:Config {
}
isolated function testContentDeliveryRetrySuccess() returns error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9094/callback/retrySuccess");
    ClientConfiguration config = {
	        retryConfig: {
		        interval: 3,
                count: 3,
                backOffFactor: 2.0,
                maxWaitInterval: 20,
                statusCodes: [400]
            },
            timeout: 2
    };
    HubClient hubClientEP = check new(subscriptionMsg, config);
    ContentDistributionMessage msg = {content: "This is sample content delivery"};
    ContentDistributionSuccess publishResponse = check hubClientEP->notifyContentDistribution(msg);
    test:assertEquals(publishResponse.status.code, 200);
    test:assertEquals(publishResponse.body, CONTENT_DELIVERY_SUCCESS);
}

@test:Config {
}
isolated function testContentDeliveryRetryFailed() returns error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("http://localhost:9094/callback/retryFailed");
    ClientConfiguration config = {
	        retryConfig: {
		        interval: 3,
                count: 3,
                backOffFactor: 2.0,
                maxWaitInterval: 20,
                statusCodes: [500]
            },
            timeout: 2
    };
    HubClient hubClientEP = check new(subscriptionMsg, config);
    ContentDistributionMessage msg = {content: "This is sample content delivery"};
    var publishResponse = hubClientEP->notifyContentDistribution(msg);
    test:assertTrue(publishResponse is error);
}
