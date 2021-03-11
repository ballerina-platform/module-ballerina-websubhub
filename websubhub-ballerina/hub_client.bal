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
import ballerina/crypto;

# HTTP Based client for WebSub content publishing to subscribers
public client class HubClient {
    private string callback;
    private string hub;
    private string topic;
    private string linkHeaderValue;
    private string secret = "";
    private http:Client httpClient;

    # Initializes the `websubhub:HubClient`.
    # ```ballerina
    # websubhub:HubClient hubClientEP = new({
    #   hub: "https://hub.com",
    #   hubMode: "subscribe", 
    #   hubCallback: "http://subscriber.com/callback", 
    #   hubTopic: "https://topic.com", 
    #   hubSecret: "key"
    # });
    # ```
    #
    # + url    - The URL to publish/notify updates
    # + config - The `websubhub:ClientConfiguration` for the underlying client or else `()`
    public function init(Subscription subscription, ClientConfiguration? config = ()) returns error? {
        self.callback = subscription.hubCallback;
        self.hub = subscription.hub;
        self.topic = subscription.hubTopic;
        self.linkHeaderValue = generateLinkUrl(self.hub,  self.topic);
        self.secret = subscription?.hubSecret is string ? <string>subscription?.hubSecret : "";
        self.httpClient = check new(subscription.hubCallback, <http:ClientConfiguration?>config);
    }

    # Distributes the published content to subscribers.
    # ```ballerina
    # ContentDistributionSuccess | SubscriptionDeletedError | error? publishUpdate = websubHubClientEP->notifyContentDistribution(
    #   { 
    #       content: "This is sample content" 
    #   }
    # );
    #  ```
    #
    # + msg - content to be distributed to the topic-subscriber 
    # + return - an `error` if an error occurred or `SubscriptionDeletedError` if the subscriber responded with `HTTP 410` 
    # or else `ContentDistributionSuccess` for successful content delivery
    remote function notifyContentDistribution(ContentDistributionMessage msg) returns @tainted ContentDistributionSuccess | SubscriptionDeletedError | error? {
        http:Client httpClient = self.httpClient;

        http:Request request = new;
        
        string contentType = retrieveContentType(msg.contentType, msg.content);

        check request.setContentType(contentType);
        
        if (msg?.headers is map<string|string[]>) {
            var headers = <map<string|string[]>>msg?.headers;
            foreach var [header, values] in headers.entries() {
                if (values is string) {
                    request.addHeader(header, values);
                } else {
                    foreach var value in <string[]>values {
                        request.addHeader(header, value);
                    }
                }
            }
        }

        request.setHeader(LINK, self.linkHeaderValue);

        if (self.secret.length() > 0) {
            var hash = check retrievePayloadSignature(self.secret, msg.content);
            request.setHeader(X_HUB_SIGNATURE, SHA256_HMAC + "=" +hash.toBase16());
        }

        request.setPayload(msg.content);

        var response = httpClient->post("", request);

        if (response is http:Response) {
            var status = response.statusCode;
            if (isSuccessStatusCode(status)) {
                return {
                    headers: msg?.headers,
                    mediaType: msg?.contentType,
                    body: msg.content
                };
            } else if (status == http:STATUS_GONE) {
                // HTTP 410 is used to communicate that subscriber no longer need to continue the subscription
                return error SubscriptionDeletedError("Subscription to topic ["+self.topic+"] is terminated by the subscriber");
            } else {
                var result = response.getTextPayload();
                string textPayload = result is string ? result : "";
                return error ContentDeliveryError("Error occurred distributing updated content: " + textPayload);
            }
        } else {
            return error ContentDeliveryError("Content distribution failed for topic [" + self.topic + "]");
        }
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

isolated function retrievePayloadSignature(string 'key, string|xml|json|byte[] payload) returns byte[]|error {
    byte[] keyArr = 'key.toBytes();
    if (payload is byte[]) {
        return check crypto:hmacSha256(payload, keyArr);
    } else if (payload is string) {
        byte[] inputArr = (<string>payload).toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    } else if (payload is xml) {
        byte[] inputArr = (<xml>payload).toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);   
    } else if (payload is map<string>) {
        byte[] inputArr = (<map<string>>payload).toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr); 
    } else {
        byte[] inputArr = (<json>payload).toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    }
}
