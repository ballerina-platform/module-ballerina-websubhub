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

import ballerina/test;
import ballerina/mime;
import ballerina/http;

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
isolated function testContentTypeRetrievalForString() returns @tainted error? {
    string contentType = retrieveContentType((), "This is sample content delivery");
    test:assertEquals(contentType, mime:TEXT_PLAIN);
}

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
isolated function testContentTypeRetrievalForXml() returns @tainted error? {
    xml content = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;
    string contentType = retrieveContentType((), content);
    test:assertEquals(contentType, mime:APPLICATION_XML);
}

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
isolated function testContentTypeRetrievalForJson() returns @tainted error? {
    json content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    string contentType = retrieveContentType((), content);
    test:assertEquals(contentType, mime:APPLICATION_JSON);
}

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
isolated function testContentTypeRetrievalForFormUrlEncoded() returns @tainted error? {
    map<string> content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    string contentType = retrieveContentType((), content);
    test:assertEquals(contentType, mime:APPLICATION_FORM_URLENCODED);
}

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
isolated function testContentTypeRetrievalForByteArray() returns @tainted error? {
    byte[] content = "This is sample content delivery".toBytes();
    string contentType = retrieveContentType((), content);
    test:assertEquals(contentType, mime:APPLICATION_OCTET_STREAM);
}

const string HASH_KEY = "secret";

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testStringContentSignature() returns @tainted error? {
    string content = "This is sample content delivery";
    byte[] hashedContent = check generateSignature(HASH_KEY, content);
    test:assertEquals("d66181d67f963fff2dde0b0a4ca50ac1a6bc5828dd32eabaf0d5049f6fe8b5ff", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testXmlContentSignature() returns @tainted error? {
    xml content = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;
    byte[] hashedContent = check generateSignature(HASH_KEY, content);
    test:assertEquals("526af3b9e1d8f5f618b06f88c9c142ef4baee4c66c16d4026d2307689643de58", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testJsonContentSignature() returns @tainted error? {
    json content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    byte[] hashedContent = check generateSignature(HASH_KEY, content);
    test:assertEquals("3253fa36df638332580b551edad634e81990736179263a8d8966bd5c04a12198", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testFormUrlEncodedContentSignature() returns @tainted error? {
    map<string> content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    byte[] hashedContent = check generateSignature(HASH_KEY, content);
    test:assertEquals("a67cf8d3245fb03dd7914097bb731cc7532ff7c8bb738c2a587506b0bc4c0dda", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testByteArrayContentSignature() returns @tainted error? {
    byte[] content = "This is sample content delivery".toBytes();
    byte[] hashedContent = check generateSignature(HASH_KEY, content);
    test:assertEquals("d66181d67f963fff2dde0b0a4ca50ac1a6bc5828dd32eabaf0d5049f6fe8b5ff", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testJsonContentSignatureRetrieval() returns @tainted error? {
    json content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    byte[] hashedContent = check retrievePayloadSignature(mime:APPLICATION_JSON, HASH_KEY, "", content);
    test:assertEquals("3253fa36df638332580b551edad634e81990736179263a8d8966bd5c04a12198", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
isolated function testUrlEncodedContentSignatureRetrieval() returns @tainted error? {
    byte[] hashedContent = check retrievePayloadSignature(mime:APPLICATION_FORM_URLENCODED, HASH_KEY, "key1=val1&key2=val2", "");
    test:assertEquals("2d936793407340f43e3d6427534f536a08ba52899bedd94fc7b14ebc2d5c44c2", hashedContent.toBase16());
}


http:Client headerRetrievalTestingClient = check new ("http://localhost:9191/subscriber");

@test:Config { 
    groups: ["clientResponseHeaderRetrieval"]
}
function testResponseHeaderRetrievalWithManuallyCreatingHeaders() returns @tainted error? {
    http:Response response = new;
    foreach var [header, value] in CUSTOM_HEADERS.entries() {
        if (value is string) {
            response.setHeader(header, value);
        } else {
            foreach var val in value {
                response.addHeader(header, val);
            }
        }
    }

    map<string|string[]> retrievedResponseHeaders = retrieveResponseHeaders(response);
    test:assertTrue(retrievedResponseHeaders.length() > 0);
    boolean isSuccess = check hasAllHeaders(retrievedResponseHeaders);
    test:assertTrue(isSuccess);
}

@test:Config { 
    groups: ["clientResponseHeaderRetrieval"]
}
function testResponseHeaderRetrievalWithApiCall() returns @tainted error? {
    http:Request request = new;
    http:Response retrievedResponse = check headerRetrievalTestingClient->post("/addHeaders", request);
    map<string|string[]> retrievedResponseHeaders = retrieveResponseHeaders(retrievedResponse);
    test:assertTrue(retrievedResponseHeaders.length() > 0);
    boolean isSuccess = check hasAllHeaders(retrievedResponseHeaders);
    test:assertTrue(isSuccess);
}

@test:Config { 
    groups: ["clientResponseBodyRetrieval"]
}
function testResponsePayloadRetrievalForText() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("text");
    http:Response retrievedResponse = check headerRetrievalTestingClient->post("/addPayload", request);
    string|byte[]|json|xml|map<string>? responseBody = retrieveResponseBody(retrievedResponse, retrievedResponse.getContentType());
    test:assertTrue(responseBody is string);
    test:assertEquals(responseBody, "This is a test message");
}

@test:Config { 
    groups: ["clientResponseBodyRetrieval"]
}
function testResponsePayloadRetrievalForJson() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("json");
    json expectedPayload = {
                    "message": "This is a test message"
    };
    http:Response retrievedResponse = check headerRetrievalTestingClient->post("/addPayload", request);
    string|byte[]|json|xml|map<string>? responseBody = retrieveResponseBody(retrievedResponse, retrievedResponse.getContentType());
    test:assertTrue(responseBody is json);
    test:assertEquals(responseBody, expectedPayload);
}

@test:Config { 
    groups: ["clientResponseBodyRetrieval"]
}
function testResponsePayloadRetrievalForXml() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("xml");
    xml expectedPayload = xml `<content><message>This is a test message</message></content>`;
    http:Response retrievedResponse = check headerRetrievalTestingClient->post("/addPayload", request);
    string|byte[]|json|xml|map<string>? responseBody = retrieveResponseBody(retrievedResponse, retrievedResponse.getContentType());
    test:assertTrue(responseBody is xml);
    test:assertEquals(responseBody, expectedPayload);
}

@test:Config { 
    groups: ["clientResponseBodyRetrieval"]
}
function testResponsePayloadRetrievalForByteArray() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("byte");
    byte[] expectedPayload = "This is a test message".toBytes();
    http:Response retrievedResponse = check headerRetrievalTestingClient->post("/addPayload", request);
    string|byte[]|json|xml|map<string>? responseBody = retrieveResponseBody(retrievedResponse, retrievedResponse.getContentType());
    test:assertTrue(responseBody is byte[]);
    test:assertEquals(responseBody, expectedPayload);
}

@test:Config { 
    groups: ["clientResponseBodyRetrieval"]
}
function testResponsePayloadRetrievalForNoContent() returns @tainted error? {
    http:Request request = new;
    request.setTextPayload("other");
    http:Response retrievedResponse = check headerRetrievalTestingClient->post("/addPayload", request);
    test:assertFalse(retrievedResponse.getContentType().trim().length() > 1);
}

@test:Config { 
    groups: ["formUrlEncodedContent"]
}
isolated function testResponsePayloadGenerationWithReason() returns @tainted error? {
    map<string> message = {
        "query1": "value1",
        "query2": "value2"
    };
    string generatedQuery = generateResponsePayload("denied", message, "reason1");
    test:assertEquals("hub.mode=denied&hub.reason=reason1&query1=value1&query2=value2", generatedQuery);
}

@test:Config { 
    groups: ["formUrlEncodedContent"]
}
isolated function testResponsePayloadGenerationWithOutReason() returns @tainted error? {
    map<string> message = {
        "query1": "value1",
        "query2": "value2"
    };
    string generatedQuery = generateResponsePayload("denied", message, ());
    test:assertEquals(generatedQuery, "hub.mode=denied&query1=value1&query2=value2");
}

@test:Config { 
    groups: ["formUrlEncodedContent"]
}
isolated function testFormUrlEncodedTextPayloadRetrieval() returns @tainted error? {
    map<string> message = {
        "query1": "value1",
        "query2": "value2"
    };
    string generatedQuery = retrieveTextPayloadForFormUrlEncodedMessage(message);
    test:assertEquals(generatedQuery, "query1=value1&query2=value2");
}

@test:Config { 
    groups: ["formUrlEncodedContent"]
}
isolated function testFormUrlEncodedResponseBodyRetrievalFromQuery() returns @tainted error? {
    map<string> message = {
        "query1": "value1",
        "query2": "value2",
        "query3": "value3"
    };
    map<string> generatedResponseBody = retrieveResponseBodyForFormUrlEncodedMessage("query1=value1&query2=value2&query3=value3");
    test:assertEquals(generatedResponseBody.length(), message.length());
    foreach string 'key in message.keys() {
        string value = generatedResponseBody.remove('key);
    }
    test:assertTrue(generatedResponseBody.length() == 0);
}

@test:Config { 
    groups: ["servicePathRetrieval"]
}
isolated function testServicePathRetrievalForUrlEncodedContent() returns error? {
    string servicePath = getServicePath("https://subscriber.com/callback", mime:APPLICATION_FORM_URLENCODED, "query1=value1&query2=value2");
    test:assertEquals(servicePath, "?query1=value1&query2=value2");
}

@test:Config { 
    groups: ["servicePathRetrieval"]
}
isolated function testServicePathRetrievalForUrlEncodedContentWithCallbackParameters() returns error? {
    string servicePath = getServicePath("https://subscriber.com/callback?this1=that1", mime:APPLICATION_FORM_URLENCODED, "query1=value1&query2=value2");
    test:assertEquals(servicePath, "&query1=value1&query2=value2");
}

@test:Config { 
    groups: ["servicePathRetrieval"]
}
isolated function testServicePathRetrievalForOtherContentTypes() returns error? {
    string servicePath = getServicePath("https://subscriber.com/callback?this1=that1", mime:TEXT_PLAIN, "query1=value1&query2=value2");
    test:assertEquals(servicePath, "");
}

function hasAllHeaders(map<string|string[]> retrievedHeaders) returns boolean|error {
    foreach var [header, value] in CUSTOM_HEADERS.entries() {
        if (retrievedHeaders.hasKey(header)) {
            string|string[] retrievedValue = retrievedHeaders.get(header);
            if (retrievedValue is string) {
                if (value is string && retrievedValue != value) {
                    return false;
                }
                if (value is string[] && retrievedValue != value[0]) {
                    return false;
                }
            } else {
                if (value is string) {
                    return false;
                } else {
                    foreach string item in value {
                        if (retrievedValue.indexOf(item) is ()) {
                            return false;
                        }
                    }
                }
            }
        } else {
            return false;
        }
    }
    return true;
}

service / on new http:Listener(9102) {
    isolated resource function get util (string name) returns string {
        return string `Hello, ${name}!`;
    }
}

@test:Config { 
    groups: ["subscriptionNotification"]
}
isolated function testSubscriptionNotificationSuccess() returns error? {
    http:Response resp = check sendSubscriptionNotification("http://localhost:9102/util", "?name=Ayesh", {});
    string responsePayload = check resp.getTextPayload();
    test:assertEquals(responsePayload, "Hello, Ayesh!");
}

@test:Config { 
    groups: ["httpClientRetrieval"]
}
isolated function testRetrieveHttpClientWithConfig() returns @tainted error? {
    http:ClientConfiguration httpsConfig = {
        secureSocket: {
            cert: {
                path: "tests/resources/ballerinaTruststore.pkcs12",
                password: "ballerina"
            }
        }
    };
    var clientEp = retrieveHttpClient("https://test.com/sample", httpsConfig);
    test:assertTrue(clientEp is http:Client);
}
