// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/http;
import ballerina/mime;
import ballerina/test;

http:ListenerConfiguration listenerConfiguration = {
    secureSocket: {
        key: {
            path: "tests/resources/ballerinaKeystore.pkcs12",
            password: "ballerina"
        }
    }
};

listener http:Listener serviceListener = new (9097, listenerConfiguration);

service /callback on serviceListener {
    resource function post success(http:Caller caller, http:Request req) {
        var result = caller->respond("Content Delivery Success");
    }

    resource function post deleted(http:Caller caller, http:Request req) {
        http:Response res = new ();
        res.statusCode = http:STATUS_GONE;
        var result = caller->respond(res);
    }
}

ClientConfiguration hubClientSslConfig = {
    secureSocket: {
        cert: {
            path: "tests/resources/ballerinaTruststore.pkcs12",
            password: "ballerina"
        }
    }
};

@test:Config {
}
function testTextContentDeliveryWithSsl() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9097/callback/success");

    ContentDistributionMessage msg = {content: "This is sample content delivery"};

    HubClient hubClientEP = checkpanic new(subscriptionMsg, hubClientSslConfig);
    var publishResponse = hubClientEP->notifyContentDistribution(msg);
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
        test:assertEquals(publishResponse.body, "ok");
    } else {
       test:assertFail("Content Publishing Failed.");
    }
}

@test:Config {
}
function testJsonContentDeliveryWithSsl() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9097/callback/success");
    
    json publishedContent = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    ContentDistributionMessage msg = {content: publishedContent};

    HubClient hubClientEP = checkpanic new(subscriptionMsg, hubClientSslConfig);
    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
        test:assertEquals(publishResponse.body, "ok");
    } else {
       test:assertFail("Content Publishing Failed.");
    }
}

@test:Config {
}
function testXmlContentDeliveryWithSsl() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9097/callback/success");
    
    xml publishedContent = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;
    ContentDistributionMessage msg = {content: publishedContent};

    HubClient hubClientEP = checkpanic new(subscriptionMsg, hubClientSslConfig);
    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
        test:assertEquals(publishResponse.body, "ok");
    } else {
       test:assertFail("Content Publishing Failed.");
    }
}

@test:Config {
}
function testMimeContentDeliveryWithSsl() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9097/callback/success");
    
    mime:Entity jsonBodyPart = new;
    jsonBodyPart.setContentDisposition(getContentDispositionForFormData("json part"));
    jsonBodyPart.setJson({"name": "wso2"});

    mime:Entity textBodyPart = new;
    textBodyPart.setContentDisposition(getContentDispositionForFormData("text part"));
    textBodyPart.setText("Sample text");

    mime:Entity[] publishedContent = [jsonBodyPart, textBodyPart];
    ContentDistributionMessage msg = {content: publishedContent};

    HubClient hubClientEP = checkpanic new(subscriptionMsg, hubClientSslConfig);
    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
    } else {
       test:assertFail("Content Publishing Failed.");
    }  
}

@test:Config {
}
function testByteArrayContentDeliveryWithSsl() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9097/callback/success");
    
    byte[] publishedContent = "This is sample content".toBytes();
    ContentDistributionMessage msg = {content: publishedContent};

    HubClient hubClientEP = checkpanic new(subscriptionMsg, hubClientSslConfig);
    var publishResponse = hubClientEP->notifyContentDistribution(msg);   
    if (publishResponse is ContentDistributionSuccess) {
        test:assertEquals(publishResponse.status.code, 200);
    } else {
       test:assertFail("Content Publishing Failed.");
    }    
}

@test:Config {
}
function testSubscriptionDeletedWithSsl() returns @tainted error? {
    Subscription subscriptionMsg = retrieveSubscriptionMsg("https://localhost:9097/callback/deleted");

    HubClient hubClientEP = checkpanic new(subscriptionMsg, hubClientSslConfig);
    var publishResponse = hubClientEP->notifyContentDistribution({content: "This is sample content delivery"});
    var expectedResponse = "Subscription to topic [https://topic.com] is terminated by the subscriber";
    if (publishResponse is SubscriptionDeletedError) {
        test:assertEquals(publishResponse.message(), expectedResponse);
    } else {
       test:assertFail("Content Publishing Failed.");
    }    
}
