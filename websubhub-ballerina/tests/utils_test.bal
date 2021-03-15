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

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
function testContentTypeRetrievalForString() returns @tainted error? {
    string contentType = retrieveContentType((), "This is sample content delivery");
    test:assertEquals(contentType, mime:TEXT_PLAIN);
}

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
function testContentTypeRetrievalForXml() returns @tainted error? {
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
function testContentTypeRetrievalForJson() returns @tainted error? {
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
function testContentTypeRetrievalForFormUrlEncoded() returns @tainted error? {
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
function testContentTypeRetrievalForMime() returns @tainted error? {
    mime:Entity jsonBodyPart = new;
    jsonBodyPart.setContentDisposition(getContentDispositionForFormData("json part"));
    jsonBodyPart.setJson({"name": "wso2"});

    mime:Entity textBodyPart = new;
    textBodyPart.setContentDisposition(getContentDispositionForFormData("text part"));
    textBodyPart.setText("Sample text");

    mime:Entity[] content = [jsonBodyPart, textBodyPart];
    string contentType = retrieveContentType((), content);
    test:assertEquals(contentType, mime:MULTIPART_FORM_DATA);
}

@test:Config { 
    groups: ["contentTypeRetrieval"]
}
function testContentTypeRetrievalForByteArray() returns @tainted error? {
    byte[] content = "This is sample content delivery".toBytes();
    string contentType = retrieveContentType((), content);
    test:assertEquals(contentType, mime:APPLICATION_OCTET_STREAM);
}

const string HASH_KEY = "secret";

@test:Config { 
    groups: ["contentSignature"]
}
function testStringContentSignature() returns @tainted error? {
    string content = "This is sample content delivery";
    byte[] hashedContent = check retrievePayloadSignature(HASH_KEY, content);
    test:assertEquals("d66181d67f963fff2dde0b0a4ca50ac1a6bc5828dd32eabaf0d5049f6fe8b5ff", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
function testXmlContentSignature() returns @tainted error? {
    xml content = xml `<content>
        <contentUrl>The Lost World</contentUrl>
        <contentMsg>Enjoy free offers this season</contentMsg>
    </content>`;
    byte[] hashedContent = check retrievePayloadSignature(HASH_KEY, content);
    test:assertEquals("526af3b9e1d8f5f618b06f88c9c142ef4baee4c66c16d4026d2307689643de58", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
function testJsonContentSignature() returns @tainted error? {
    json content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    byte[] hashedContent = check retrievePayloadSignature(HASH_KEY, content);
    test:assertEquals("a67cf8d3245fb03dd7914097bb731cc7532ff7c8bb738c2a587506b0bc4c0dda", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
function testFormUrlEncodedContentSignature() returns @tainted error? {
    map<string> content = {
        contentUrl: "https://sample.content.com",
        contentMsg: "Enjoy free offers this season"
    };
    byte[] hashedContent = check retrievePayloadSignature(HASH_KEY, content);
    test:assertEquals("a67cf8d3245fb03dd7914097bb731cc7532ff7c8bb738c2a587506b0bc4c0dda", hashedContent.toBase16());
}

@test:Config { 
    groups: ["contentSignature"]
}
function testByteArrayContentSignature() returns @tainted error? {
    byte[] content = "This is sample content delivery".toBytes();
    byte[] hashedContent = check retrievePayloadSignature(HASH_KEY, content);
    test:assertEquals("d66181d67f963fff2dde0b0a4ca50ac1a6bc5828dd32eabaf0d5049f6fe8b5ff", hashedContent.toBase16());
}
