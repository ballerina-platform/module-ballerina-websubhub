// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
// import ballerina/io;
// import ballerina/mime;
// import ballerina/crypto;


public client class HubClient {
    private string hubUrl;
    private string topic;
    private string linkHeaderValue;
    private http:Client httpClient;

    # Initializes the `websubhub:HubClient`.
    # ```ballerina
    # websubhub:HubClient hubClientEP = new({
    #   hubMode: "subscribe", 
    #   hubCallback = "http://subscriber.com/callback", 
    #   hubTopic: "https://topic.com", 
    #   hubSecret: "key"
    # });
    # ```
    #
    # + url    - The URL to publish/notify updates
    # + config - The `http:ClientConfiguration` for the underlying client or else `()`
    public function init(SubscriptionMessage subscription, http:ClientConfiguration? config = ()) returns error? {
        self.hubUrl = "";
        self.topic = check subscription?.hubTopic;
        self.linkHeaderValue = "";
        self.httpClient = check new(subscription?.hubCallback ?: "", config);
    }

    # Distributes the published content to subscribers.
    # ```ballerina
    # error? publishUpdate = websubHubClientEP->notifyContentDistribution({
    #   content: "This is sample content"
    # });
    #  ```
    #
    # + msg - content to be distributed to the topic-subscriber 
    # + return -  An `error`if an error occurred with the update or else `()`
    remote function notifyContentDistribution(ContentDistributionMessage msg) returns @tainted error? {
        http:Request request = new;
        
        string contentType = retrieveContentType(msg.contentType, msg.content);

        check request.setContentType(contentType);
    }

    isolated function retrieveContentType(string? contentType, string|xml|json|byte[] payload) returns string {
        if (contentType is string) {
            return contentType;
        } else {
            if (payload is string) {
                return mime:TEXT_PLAIN;
            } else if (payload is xml) {
                return mime:APPLICATION_XML;
            } else if (payload is map<string>) {
                return mime: APPLICATION_FORM_URLENCODED;
            } else if (payload is map<json>) {
                return mime:APPLICATION_JSON;
            } else {
                return mime:APPLICATION_OCTET_STREAM;
            }
        }
    }
}
