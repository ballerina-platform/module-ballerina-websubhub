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
import ballerina/lang.'string as strings;

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
    public isolated function init(Subscription subscription, *ClientConfiguration config) returns error? {
        self.callback = subscription.hubCallback;
        self.hub = subscription.hub;
        self.topic = subscription.hubTopic;
        self.linkHeaderValue = generateLinkUrl(self.hub,  self.topic);
        self.secret = subscription?.hubSecret is string ? <string>subscription?.hubSecret : "";
        self.httpClient = check new(subscription.hubCallback, retrieveHttpClientConfig(config));
    }

    # Distributes the published content to subscribers.
    # ```ballerina
    # ContentDistributionSuccess | SubscriptionDeletedError | error? publishUpdate = websubHubClientEP->notifyContentDistribution(
    #   { 
    #       content: "This is sample content" 
    #   }
    # );
    # ```
    #
    # + msg - content to be distributed to the topic-subscriber 
    # + return - an `error` if an error occurred or `SubscriptionDeletedError` if the subscriber responded with `HTTP 410` 
    # or else `ContentDistributionSuccess` for successful content delivery
    isolated remote function notifyContentDistribution(ContentDistributionMessage msg) 
                                returns @tainted ContentDistributionSuccess|SubscriptionDeletedError|error? {
        string contentType = retrieveContentType(msg.contentType, msg.content);
        http:Request request = new;
        string queryString = "";
        match contentType {
            mime:APPLICATION_FORM_URLENCODED => {
                map<string> messageBody = <map<string>> msg.content;
                queryString += retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
            }
            _ => {
                request.setPayload(msg.content);
            }
        }

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
        check request.setContentType(contentType);
        request.setHeader(LINK, self.linkHeaderValue);
        if (self.secret.length() > 0) {
            byte[] hash = [];
            if (contentType == mime:APPLICATION_FORM_URLENCODED) {
                hash = check retrievePayloadSignature(self.secret, queryString);
            } else {
                hash = check retrievePayloadSignature(self.secret, msg.content);
            }
            request.setHeader(X_HUB_SIGNATURE, string`${SHA256_HMAC}=${hash.toBase16()}`);
        }

        string servicePath = getServicePath(self.callback, contentType, queryString);
        var response = self.httpClient->post(servicePath, request);
        if (response is http:Response) {
            var status = response.statusCode;
            if (isSuccessStatusCode(status)) {
                string & readonly responseContentType = response.getContentType();
                map<string|string[]> responseHeaders = check retrieveResponseHeaders(response);
                if (responseContentType.trim().length() > 1) {
                    return {
                        headers: responseHeaders,
                        mediaType: responseContentType,
                        body: check retrieveResponseBody(response, responseContentType)
                    };
                } else {
                    return {
                        headers: responseHeaders
                    };
                }
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

# Retrieve content-type for the content-distribution request.
# 
# + contentType - provided content type (optional)
# + payload - content-distribution payload
# + return - {@code string} containing the content-type for the content-distribution request
isolated function retrieveContentType(string? contentType, string|xml|json|byte[] payload) returns string {
    if (contentType is string) {
        return contentType;
    } else {
        if (payload is string) {
            return mime:TEXT_PLAIN;
        } else if (payload is xml) {
            return mime:APPLICATION_XML;
        } else if (payload is map<string>) {
            return mime:APPLICATION_FORM_URLENCODED;
        } else if (payload is map<json>) {
            return mime:APPLICATION_JSON;
        } else {
            return mime:APPLICATION_OCTET_STREAM;
        }
    }
}

# Retrieve signature for the content-distribution request payload.
# 
# + 'key - hashing key to be used (this is provided by the subscriber)
# + payload - content-distribution request body
# + return - {@code byte[]} containing the content signature or {@code error} if there is any error in 
# function execution
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
        byte[] inputArr = (<json>payload).toJsonString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    }
}

# Retrieve service path to which the content should be delivered.
# 
# + originalServiceUrl - subscriber callback URL
# + contentType - content-type of the content-distribution request
# + queryString - generated query-parameters for the request
# + return - service-path which should be called for content-delivery
isolated function getServicePath(string originalServiceUrl, string contentType, string queryString) returns string {
    match contentType {
        mime:APPLICATION_FORM_URLENCODED => {
            string servicePath = strings:includes(originalServiceUrl, ("?")) ? "&" : "?";
            return servicePath + queryString;
        }
        _ => {
            return "";
        }
    }
}

# Retrieve response headers from subscriber-response.
# 
# + subscriberResponse - {@code http:Response} received for content-delivery
# + return - {@code map<string|string[]>} containing header values or {@code error} if there is an error in the
# function execution
isolated function retrieveResponseHeaders(http:Response subscriberResponse) returns map<string|string[]>|error {
    map<string|string[]> responseHeaders = {};
    foreach var headerName in subscriberResponse.getHeaderNames() {
        string[] retrievedValue = check subscriberResponse.getHeaders(headerName);
        if (retrievedValue.length() == 1) {
            responseHeaders[headerName] = retrievedValue[0];
        } else {
            responseHeaders[headerName] = retrievedValue;
        }
    }
    return responseHeaders;
}

# Retrieve response body from subscriber-response.
# 
# + subscriberResponse - {@code http:Response} received for content-delivery
# + contentType - content-type for the received response
# + return - response body of the {@code http:Response} or {@code error} if there is an error in the execution
isolated function retrieveResponseBody(http:Response subscriberResponse, string contentType) returns string|byte[]|json|xml|map<string>|error {
    match contentType {
        mime:APPLICATION_JSON => {
            return check subscriberResponse.getJsonPayload();
        }
        mime:APPLICATION_XML => {
            return check subscriberResponse.getXmlPayload(); 
        }
        mime:TEXT_PLAIN => {
            return check subscriberResponse.getTextPayload();             
        }
        mime:APPLICATION_OCTET_STREAM => {
            return check subscriberResponse.getBinaryPayload();
        }
        mime:APPLICATION_FORM_URLENCODED => {
            string payload = check subscriberResponse.getTextPayload();
            return retrieveResponseBodyForFormUrlEncodedMessage(payload);
        }
        _ => {
            return error ContentDeliveryError(string`Unrecognized content-type [${contentType}] found`);
        }
    }
}
