// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
import ballerina/io;
import ballerina/mime;

public class HubClient {
    private string url;
    private string hubUrl;
    private string topic;
    private string linkHeaderValue;
    private http:Client httpClient;

    # Initializes the `websub:HubClient`.
    # ```ballerina
    # websub:HubClient hubClientEp = new("http://localhost:10001/client/callback", "http://hub.sample.com/hub", "http://topic.sample.com/topic1");
    # ```
    #
    # + url    - The URL to notify when a topic gets a content-update request
    # + config - The `http:ClientConfiguration` for the underlying client or else `()`
    public function init(string url, string hubUrl, string topic, http:ClientConfiguration? config = ()) {
        self.url = url;
        self.hubUrl = hubUrl;
        self.topic = topic;
        self.linkHeaderValue = retrieveLinkHeader(hubUrl, topic);
        self.httpClient = new (self.url, config);
    }

    # Distributes the published content to subscribers.
    # ```ballerina
    # error? publishUpdate = websubHubClientEP->publishUpdate("http://websubpubtopic.com",{"action": "publish",
    # "mode": "remote-hub"});
    #  ```
    #
    # + topic - The topic for which the update occurred
    # + payload - The update payload
    # + contentType - The type of the update content to set as the `ContentType` header
    # + headers - The headers that need to be set (if any)
    # + return -  An `error`if an error occurred with the update or else `()`
    remote function notifyContentDistribution(ContentDistributionMessage msg) @tainted returns error? {
        http:Request request = new;
        
        request.setPayload(payload);

        string contentType = retrieveContentType(msg.contentType, msg.content);

        check request.setContentType(contentType);

        msg?.headers.entries().forEach(function ([string, string[]] pair) {
            string headerValue = pairt[1].reduce(function (string acc, string cur) returns string {
                return acc + cur + ";";
            }, "");
            req.addHeader(pair[0], pair[1]);
        });

        request.setHeader("Link", linkHeaderValue);

        var response = self.httpClient->post(request);
        if (response is http:Response) {
            if (!isSuccessStatusCode(response.statusCode)) {
                var result = response.getTextPayload();
                string textPayload = result is string ? result : "";
                return error WebSubError("Error occurred distributing updated content: " + textPayload);
            }
        } else {
            return error WebSubError("Content distribution failed for topic [" + topic + "]");
        }
    }

    private function retrieveContentType(string? contentType, string|xml|json|byte[]|io:ReadableByteChannel payload) returns string {
        if (contentType is string) {
            return contentType;
        } else {
            if (payload is string) {
                return mime:TEXT_PLAIN;
            } else if (payload is xml) {
                return mime:APPLICATION_XML;
            } else if (payload is json) {
                return mime:APPLICATION_JSON;
            } else {
                return mime:APPLICATION_OCTET_STREAM;
            }
        }
    }

    private function retrieveLinkHeader(string hubUrl, string topic) returns string {
        return hubUrl + "; rel=\"hub\"," + topic + "; rel=\"self\"";
    }
}