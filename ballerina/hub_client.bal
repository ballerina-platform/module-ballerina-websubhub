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
    private string hubLinks;
    private string? secret;
    private http:Client httpClient;

    # Initializes the `websubhub:HubClient`.
    # ```ballerina
    # websubhub:HubClient hubClientEP = check new({
    #   hub: "https://hub.com",
    #   hubMode: "subscribe", 
    #   hubCallback: "http://subscriber.com/callback", 
    #   hubTopic: "https://topic.com", 
    #   hubSecret: "key"
    # });
    # ```
    #
    # + subscription - Original `websubhub:Subscription` record, which contains the details of the `subscriber`
    # + config - The `websubhub:ClientConfiguration` for the underlying client
    # + return - The `websubhub:HubClient` or an `websubhub:Error` if the initialization failed
    public isolated function init(Subscription subscription, *ClientConfiguration config) returns Error? {
        self.callback = subscription.hubCallback;
        self.hub = subscription.hub;
        self.topic = subscription.hubTopic;
        self.hubLinks = generateLinkUrl(self.hub,  self.topic);
        self.secret = subscription?.hubSecret;
        self.httpClient = check retrieveHttpClient(subscription.hubCallback, retrieveHttpClientConfig(config));
    }

    # Distributes the published content to the subscribers.
    # ```ballerina
    # ContentDistributionSuccess publishUpdate = check websubHubClientEP->notifyContentDistribution({ content: "This is sample content" });
    # ```
    #
    # + message - Content to be distributed to the topic subscriber 
    # + return - An `websubhub:Error` if an exception occurred, a `websubhub:SubscriptionDeletedError` if the subscriber responded with `HTTP 410`,
    #            or else a `websubhub:ContentDistributionSuccess` for successful content delivery
    isolated remote function notifyContentDistribution(ContentDistributionMessage message) 
                                returns ContentDistributionSuccess|SubscriptionDeletedError|Error {
        http:Request request = new;
        map<string|string[]>? headers = message?.headers;
        if headers is map<string|string[]> {
            foreach var [header, values] in headers.entries() {
                if values is string {
                    request.addHeader(header, values);
                } else {
                    foreach string value in values {
                        request.addHeader(header, value);
                    }
                }
            }
        }
        string contentType = retrieveContentType(message.contentType, message.content);
        json|xml|byte[] payload = retrieveRequestPayload(contentType, message.content);
        request.setPayload(payload);
        error? result = request.setContentType(contentType);
        if (result is error) {
            return error Error("Error occurred while setting content type", result);
        }
        request.setHeader(LINK, self.hubLinks);
        string? secret = self.secret;
        if secret is string {
            byte[]|error hash = generateSignature(secret, payload);
            if hash is byte[] {
                request.setHeader(X_HUB_SIGNATURE, string `${SHA256_HMAC}=${hash.toBase16()}`);
            } else {
                return error Error("Error retrieving content signature", hash);
            }
        }
        http:Response|error response = self.httpClient->post("/", request);
        if response is http:Response {
            return processSubscriberResponse(response, self.topic);
        } else {
            string errorMsg = string `Content distribution failed for topic [${self.topic}]`;
            return error ContentDeliveryError(errorMsg);
        }
    }
}

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

isolated function retrieveRequestPayload(string contentType, json|xml|byte[] payload) returns json|xml|byte[] {
    match contentType {
        mime:APPLICATION_FORM_URLENCODED => {
            map<string> messageBody = <map<string>>payload;
            return retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
        }
        _ => {
            return payload;
        }
    }
}

isolated function generateSignature(string 'key, json|xml|byte[] payload) returns byte[]|error {
    byte[] keyArr = 'key.toBytes();
    if payload is byte[] {
        return check crypto:hmacSha256(payload, keyArr);
    } else if payload is string {
        byte[] inputArr = payload.toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    } else if payload is xml {
        byte[] inputArr = payload.toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);   
    } else if payload is map<string> {
        byte[] inputArr = payload.toString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr); 
    } else {
        byte[] inputArr = payload.toJsonString().toBytes();
        return check crypto:hmacSha256(inputArr, keyArr);
    }
}

isolated function processSubscriberResponse(http:Response response, string topic) returns ContentDistributionSuccess|SubscriptionDeletedError|ContentDeliveryError {
    int status = response.statusCode;
    if isSuccessStatusCode(status) {
        string & readonly responseContentType = response.getContentType();
        map<string|string[]> responseHeaders = retrieveResponseHeaders(response);
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
        string errorMsg = string `Subscription to topic [${topic}] is terminated by the subscriber`;
        return error SubscriptionDeletedError(errorMsg);
    } else {
        var result = response.getTextPayload();
        string textPayload = result is string ? result : "";
        string errorMsg = string `Error occurred distributing updated content: ${textPayload}`;
        return error ContentDeliveryError(errorMsg);
    }
}

isolated function retrieveResponseHeaders(http:Response subscriberResponse) returns map<string|string[]> {
    map<string|string[]> responseHeaders = {};
    foreach var headerName in subscriberResponse.getHeaderNames() {
        string[]|error retrievedValue = subscriberResponse.getHeaders(headerName);
        if retrievedValue is string[] {
            if retrievedValue.length() == 1 {
                responseHeaders[headerName] = retrievedValue[0];
            } else {
                responseHeaders[headerName] = retrievedValue;
            }
        }
    }
    return responseHeaders;
}

isolated function retrieveResponseBody(http:Response subscriberResponse, string contentType) returns string|byte[]|json|xml|map<string>? {
    match contentType {
        mime:APPLICATION_JSON => {
            var content = subscriberResponse.getJsonPayload();
            if (content is json) {
                return content;
            }
        }
        mime:APPLICATION_XML => {
            var content = subscriberResponse.getXmlPayload();
            if (content is xml) {
                return content;
            }
        }
        mime:TEXT_PLAIN => {   
            var content = subscriberResponse.getTextPayload();
            if (content is string) {
                return content;
            }         
        }
        mime:APPLICATION_OCTET_STREAM => {
            var content = subscriberResponse.getBinaryPayload();
            if (content is byte[]) {
                return content;
            }  
        }
        mime:APPLICATION_FORM_URLENCODED => {
            var content = subscriberResponse.getTextPayload();
            if (content is string) {
                return retrieveResponseBodyForFormUrlEncodedMessage(content);
            } 
        }
        _ => {}
    }
}
