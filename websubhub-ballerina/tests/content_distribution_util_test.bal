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

import ballerina/http;
import ballerina/mime;
import ballerina/test;

@test:Config { 
    groups: ["contentDistributionUtil"]
}
isolated function testContentDistributionRetrieveText() returns error? {
    http:Request req = new;
    string payload = "Hello World..!";
    req.setTextPayload(payload);
    var retrievedPayload = check retrieveRequestBody(mime:TEXT_PLAIN, req);
    test:assertTrue(retrievedPayload is string);
    test:assertEquals(retrievedPayload, payload);
}

@test:Config { 
    groups: ["contentDistributionUtil"]
}
isolated function testContentDistributionRetrieveJson() returns error? {
    http:Request req = new;
    json payload = {
        "key1": "val1"
    };
    req.setJsonPayload(payload);
    var retrievedPayload = check retrieveRequestBody(mime:APPLICATION_JSON, req);
    test:assertTrue(retrievedPayload is json);
    test:assertEquals(retrievedPayload, payload);
}

@test:Config { 
    groups: ["contentDistributionUtil"]
}
isolated function testContentDistributionRetrieveXml() returns error? {
    http:Request req = new;
    xml payload = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;
    req.setXmlPayload(payload);
    var retrievedPayload = check retrieveRequestBody(mime:APPLICATION_XML, req);
    test:assertTrue(retrievedPayload is xml);
    test:assertEquals(retrievedPayload, payload);
}

@test:Config { 
    groups: ["contentDistributionUtil"]
}
isolated function testContentDistributionRetrieveByteArr() returns error? {
    http:Request req = new;
    byte[] payload = "Hello World..!".toBytes();
    req.setBinaryPayload(payload);
    var retrievedPayload = check retrieveRequestBody(mime:APPLICATION_OCTET_STREAM, req);
    test:assertTrue(retrievedPayload is byte[]);
    test:assertEquals(retrievedPayload, payload);
}

@test:Config { 
    groups: ["contentDistributionUtil"]
}
isolated function testContentDistributionRetrieveUrlEncoded() returns error? {
    http:Request req = new;
    string payload = "key1=val1&key2=val2";
    req.setTextPayload(payload, mime:APPLICATION_FORM_URLENCODED);
    var retrievedPayload = check retrieveRequestBody(mime:APPLICATION_FORM_URLENCODED, req);
    test:assertTrue(retrievedPayload is map<string>);
}

@test:Config { 
    groups: ["contentDistributionUtil"]
}
isolated function testContentDistributionRetrieveForUnknownContentType() {
    http:Request req = new;
    string payload = "Hello World..!";
    req.setTextPayload(payload);
    var retrievedPayload = retrieveRequestBody("application/xyz", req);
    test:assertTrue(retrievedPayload is error);
    if (retrievedPayload is error) {
        test:assertEquals(retrievedPayload.message(), "Requested content type is not supported");
    }
}
