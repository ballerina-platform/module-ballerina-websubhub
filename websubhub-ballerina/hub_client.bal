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
    # + subscription - Original subscription details for the `subscriber`
    # + config - The `websubhub:ClientConfiguration` for the underlying client
    # + return - The `websubhub:HubClient` or an `error` if the initialization failed
    public isolated function init(Subscription subscription, *ClientConfiguration config) returns error? {
        self.callback = subscription.hubCallback;
        self.hub = subscription.hub;
        self.topic = subscription.hubTopic;
        self.linkHeaderValue = generateLinkUrl(self.hub,  self.topic);
        self.secret = subscription?.hubSecret is string ? <string>subscription?.hubSecret : "";
        self.httpClient = check new(subscription.hubCallback, retrieveHttpClientConfig(config));
    }

    # Distributes the published content to the subscribers.
    # ```ballerina
    # ContentDistributionSuccess|SubscriptionDeletedError|error? publishUpdate = websubHubClientEP->notifyContentDistribution(
    #   { 
    #       content: "This is sample content" 
    #   }
    # );
    # ```
    #
    # + msg - Content to be distributed to the topic subscriber 
    # + return - An `error` if an exception occurred, a `websubhub:SubscriptionDeletedError` if the subscriber responded with `HTTP 410`,
    #            or else a `websubhub:ContentDistributionSuccess` for successful content delivery
    isolated remote function notifyContentDistribution(ContentDistributionMessage msg) 
                                returns @tainted ContentDistributionSuccess|SubscriptionDeletedError|error {
        string contentType = retrieveContentType(msg.contentType, msg.content);
        http:Request request = new;
        string queryString = "";
        match contentType {
            mime:APPLICATION_FORM_URLENCODED => {
                map<string> messageBody = <map<string>> msg.content;
                queryString += retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
                request.setTextPayload(queryString, mime:APPLICATION_FORM_URLENCODED);
            }
            _ => {
                request.setPayload(msg.content);
            }
        }

        if msg?.headers is map<string|string[]> {
            var headers = <map<string|string[]>>msg?.headers;
            foreach var [header, values] in headers.entries() {
                if values is string {
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
        if self.secret.length() > 0 {
            byte[] hash = [];
            if contentType == mime:APPLICATION_FORM_URLENCODED {
                hash = check retrievePayloadSignature(self.secret, queryString);
            } else {
                hash = check retrievePayloadSignature(self.secret, msg.content);
            }
            request.setHeader(X_HUB_SIGNATURE, string `${SHA256_HMAC}=${hash.toBase16()}`);
        }

        http:Response|error response = self.httpClient->post("/", request);
        if response is http:Response {
            int status = response.statusCode;
            if isSuccessStatusCode(status) {
                string & readonly responseContentType = response.getContentType();
                map<string|string[]> responseHeaders = check retrieveResponseHeaders(response);
                if responseContentType.trim().length() > 1 {
                    return {
                        headers: responseHeaders,
                        mediaType: responseContentType,
                        body: retrieveResponseBody(response, responseContentType)
                    };
                } else {
                    return {
                        headers: responseHeaders
                    };
                }
            } else if status == http:STATUS_GONE {
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

# Retrieve the content type for the content distribution request.
# 
# + contentType - Provided content type (optional)
# + payload - Content-distribution payload
# + return - Content type of the content-distribution request
isolated function retrieveContentType(string? contentType, string|xml|json|byte[] payload) returns string {
    if contentType is string {
        return contentType;
    } else {
        if payload is string {
            return mime:TEXT_PLAIN;
        } else if payload is xml {
            return mime:APPLICATION_XML;
        } else if payload is map<string> {
            return mime:APPLICATION_FORM_URLENCODED;
        } else if payload is map<json> {
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
# + return - `byte[]` containing the content signature or an `error` if there is any exception in the 
#            function execution
isolated function retrievePayloadSignature(string 'key, string|xml|json|byte[] payload) returns byte[]|error {
    byte[] keyArr = 'key.toBytes();
    if payload is byte[] {
        return check crypto:hmacSha256(payload, keyArr);
    } else if payload is string {
        byte[] inputArr = (<string>payload).toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    } else if payload is xml {
        byte[] inputArr = (<xml>payload).toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);   
    } else if payload is map<string> {
        byte[] inputArr = (<map<string>>payload).toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr); 
    } else {
        byte[] inputArr = (<json>payload).toJsonString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    }
}

# Retrieve the service path to which the content should be delivered.
# 
# + originalServiceUrl - Subscriber callback URL
# + contentType - Content type of the content-distribution request
# + queryString - Generated query parameters for the request
# + return - Service path, which should be called for content delivery
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

# Retrieve the response headers from the subscriber response.
# 
# + subscriberResponse - The `http:Response` received for content delivery
# + return - A `map<string|string[]>` containing header values or an `error` if there is any exception in the
#            function execution
isolated function retrieveResponseHeaders(http:Response subscriberResponse) returns map<string|string[]>|error {
    map<string|string[]> responseHeaders = {};
    foreach var headerName in subscriberResponse.getHeaderNames() {
        string[] retrievedValue = check subscriberResponse.getHeaders(headerName);
        if retrievedValue.length() == 1 {
            responseHeaders[headerName] = retrievedValue[0];
        } else {
            responseHeaders[headerName] = retrievedValue;
        }
    }
    return responseHeaders;
}

# Retrieve response body from subscriber-response.
# 
# + subscriberResponse - The `http:Response` received for content delivery
# + contentType - Content type for the received response
# + return - Response body of the `http:Response` or an `error` if there is any exception in the execution
isolated function retrieveResponseBody(http:Response subscriberResponse, string contentType) returns string|byte[]|json|xml|map<string>? {
    string|byte[]|json|xml|map<string>? responseBody = ();
    match contentType {
        mime:APPLICATION_JSON => {
            var content = subscriberResponse.getJsonPayload();
            if (content is json) {
                responseBody = content;
            }
        }
        mime:APPLICATION_XML => {
            var content = subscriberResponse.getXmlPayload();
            if (content is xml) {
                responseBody = content;
            }
        }
        mime:TEXT_PLAIN => {   
            var content = subscriberResponse.getTextPayload();
            if (content is string) {
                responseBody = content;
            }         
        }
        mime:APPLICATION_OCTET_STREAM => {
            var content = subscriberResponse.getBinaryPayload();
            if (content is byte[]) {
                responseBody = content;
            }  
        }
        mime:APPLICATION_FORM_URLENCODED => {
            var content = subscriberResponse.getTextPayload();
            if (content is string) {
                responseBody = retrieveResponseBodyForFormUrlEncodedMessage(content);
            } 
        }
        _ => {}
    }
    return responseBody;
}
