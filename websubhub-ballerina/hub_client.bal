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
import ballerina/io;
import ballerina/mime;
import ballerina/crypto;

# HTTP Based client for WebSub content publishing to subscribers
public client class HubClient {
    private string callBack;
    private string hubUrl;
    private string topic;
    private string linkHeaderValue;
    private string? secret = ();
    private http:Client httpClient;

    # Initializes the `websubhub:HubClient`.
    # ```ballerina
    # websubhub:HubClient hubClientEP = new({
    #   hubUrl: "https://hub.com"
    #   hubMode: "subscribe", 
    #   hubCallback = "http://subscriber.com/callback", 
    #   hubTopic: "https://topic.com", 
    #   hubSecret: "key"
    # });
    # ```
    #
    # + url    - The URL to publish/notify updates
    # + config - The `http:ClientConfiguration` for the underlying client or else `()`
    public function init(Subscription subscription, http:ClientConfiguration? config = ()) returns error? {
        self.callBack = subscription.hubCallback;
        self.hubUrl = subscription.hubUrl;
        self.topic = subscription.hubTopic;
        self.linkHeaderValue = check generateLinkUrl();
        self.secret = subscription.hubSecret;
        self.httpClient = check new(subscription.hubCallback, config);
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
    remote function notifyContentDistribution(ContentDistributionMessage msg) returns ContentDistributionSuccess | SubscriptionDeletedError | @tainted error? {
        http:Request request = new;
        
        string contentType = retrieveContentType(msg.contentType, msg.content);

        check request.setContentType(contentType);
        
        foreach var [header, values] is msg?.headers {
            if (values is string) {
                req.addHeader(header, values);
            } else {
                string headerValue = ";".'join(...<string[]>values) + ";"
                req.addHeader(header, headerValue);
            }
        }

        request.setHeader("Link", linkHeaderValue);

        if (secret is string && secret?.length() >= 0) {
            check string hash = retrievePayloadSignature(secret, msg.content);
            request.setHeader(X_HUB_SIGNATURE, "sha256="+hash);
        }

        var response = self.httpClient->post(request);

        if (response is http:Response) {
            var status = response.statusCode;
            if (isSuccess(status)) {
                return new ContentDistributionSuccess(self.callBack, self.topic);
            } else if (isWithInRangeOrEquals(status, 410)) {
                // HTTP 410 is used to communicate that subscriber no longer need to continue the subscription
                return error SubscriptionDeletedError("Subscription to topic ["+self.topic+"] is terminated by the subscriber");
            } else {
                var result = response.getTextPayload();
                string textPayload = result is string ? result : "";
                return error WebSubError("Error occurred distributing updated content: " + textPayload);
            }
        } else {
            return error WebSubError("Content distribution failed for topic [" + topic + "]");
        }
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

    isolated function retrievePayloadSignature(string key, string|xml|json|byte[] payload) returns string | error {
        byte[] keyArr = key.toBytes();
        byte[] hashedContent = [];
        if (payload is byte[]) {
            hashedContent = crypto:hmacSha256(payload, keyArr);
        } else {
            byte[] inputArr = payload.toBytes();
            hashedContent = crypto:hmacSha256(inputArr, keyArr);
        }
        return hashedContent.toBase64();
    }

    isolated function generateLinkUrl() returns string {
        return self.hubUrl + "; rel=\"hub\", " + self.topic + "; rel=\"self\"";
    }
}
