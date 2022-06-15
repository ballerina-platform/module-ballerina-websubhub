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
import ballerina/mime;

# The HTTP based client for WebSub topic registration and deregistration, and notifying the hub of new updates.
public client class PublisherClient {
    private string url;
    private http:Client httpClient;

    # Initializes the `websub:PublisherClient`.
    # ```ballerina
    # websub:PublisherClient publisherClient = check new("https://sample.hub.com");
    # ```
    #
    # + url    - The URL to publish/notify updates
    # + config - The `websubhub:ClientConfiguration` for the underlying client or else `()`
    # + return - The `websubhub:PublisherClient` or an `websubhub:Error` if the initialization failed
    public isolated function init(string url, *ClientConfiguration config) returns Error? {
        self.url = url;
        self.httpClient = check retrieveHttpClient(self.url, retrieveHttpClientConfig(config));
    }

    # Registers a topic in a Ballerina WebSub Hub to which the subscribers can subscribe and the publisher will publish updates.
    # ```ballerina
    # websubhub:TopicRegistrationSuccess response = check publisherClient->registerTopic("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic to register
    # + return - A `websubhub:TopicRegistrationError` if an error occurred registering the topic or else `websubhub:TopicRegistrationSuccess`
    isolated remote function registerTopic(string topic) returns TopicRegistrationSuccess|TopicRegistrationError {
        http:Request request = buildTopicRegistrationChangeRequest(MODE_REGISTER, topic);
        http:Response|error registrationResponse = self.httpClient->post("", request);
        if registrationResponse is http:Response {
            TopicRegistrationSuccess|Error clientResponse = handleResponse(registrationResponse, topic, REGISTER_TOPIC_ACTION);
            if clientResponse is Error {
                CommonResponse errorDetails = clientResponse.detail();
                return error TopicRegistrationError(clientResponse.message(), clientResponse, 
                    statusCode = errorDetails.statusCode, mediaType = errorDetails?.mediaType, body = errorDetails?.body, headers = errorDetails?.headers);
            } else {
                return clientResponse;
            }
        } else {
            return error TopicRegistrationError(string `"Error sending topic registration request for topic [${topic}]`, 
                registrationResponse, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
    }

    # Deregisters a topic in a Ballerina WebSub Hub.
    # ```ballerina
    # websubhub:TopicDeregistrationSuccess response = check publisherClient->deregisterTopic("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic to deregister
    # + return - A `websubhub:TopicDeregistrationError` if an error occurred un registering the topic or else `websubhub:TopicDeregistrationSuccess`
    isolated remote function deregisterTopic(string topic) returns TopicDeregistrationSuccess|TopicDeregistrationError {
        http:Request request = buildTopicRegistrationChangeRequest(MODE_DEREGISTER, topic);
        http:Response|error deregistrationResponse = self.httpClient->post("", request);
        if deregistrationResponse is http:Response {
            TopicDeregistrationSuccess|Error clientResponse = handleResponse(deregistrationResponse, topic, DEREGISTER_TOPIC_ACTION);
            if clientResponse is Error {
                CommonResponse errorDetails = clientResponse.detail();
                return error TopicDeregistrationError(clientResponse.message(), clientResponse, 
                    statusCode = errorDetails.statusCode, mediaType = errorDetails?.mediaType, body = errorDetails?.body, headers = errorDetails?.headers);
            } else {
                return clientResponse;
            }
        } else {
            return error TopicDeregistrationError(string `Error sending topic deregistration request for topic [${topic}]`, 
                deregistrationResponse, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
    }

    # Publishes an update to a remote Ballerina WebSub Hub.
    # ```ballerina
    # websubhub:Acknowledgement response = check publisherClient->publishUpdate("http://websubpubtopic.com",{"action": "publish",
    # "mode": "remote-hub"});
    # ```
    #
    # + topic - The topic for which the update occurred
    # + payload - The update payload
    # + contentType - The type of the update content to set as the `ContentType` header
    # + return - A `websubhub:UpdateMessageError`if an error occurred with the update or else `websubhub:Acknowledgement`
    isolated remote function publishUpdate(string topic, map<string>|string|xml|json|byte[] payload,
                                  string? contentType = ()) returns Acknowledgement|UpdateMessageError {
        http:Request contentUpdateRequest = new;
        if payload is map<string> {
            string reqPayload = retrieveTextPayloadForFormUrlEncodedMessage(payload);
            contentUpdateRequest.setTextPayload(reqPayload, mime:APPLICATION_FORM_URLENCODED);
            contentUpdateRequest.setHeader(BALLERINA_PUBLISH_HEADER, CONTENT_PUBLISH);
        } else {
            contentUpdateRequest.setPayload(payload);
        }
        if contentType is string {
            error? setContent = contentUpdateRequest.setContentType(contentType);
            if setContent is error {
                string errorMsg = string `Invalid content type is set, found ${contentType}`;
                return error UpdateMessageError(errorMsg, setContent, statusCode = http:STATUS_BAD_REQUEST);
             }
        }
        string queryParams = string `${HUB_MODE}=${MODE_PUBLISH}&${HUB_TOPIC}=${topic}`;
        http:Response|error contentPublishResponse = self.httpClient->post(string `?${queryParams}`, contentUpdateRequest);
        if contentPublishResponse is http:Response {
            Acknowledgement|Error clientResponse = handleResponse(contentPublishResponse, topic, CONTENT_PUBLISH_ACTION);
            if clientResponse is Error {
                CommonResponse errorDetails = clientResponse.detail();
                return error UpdateMessageError(clientResponse.message(), clientResponse, 
                    statusCode = errorDetails.statusCode, mediaType = errorDetails?.mediaType, body = errorDetails?.body, headers = errorDetails?.headers);
            } else {
                return clientResponse;
            }
        } else {
            return error UpdateMessageError(string `Publish failed for topic [${topic}]`, 
                contentPublishResponse, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
    }

    # Notifies a remote WebSubHub from which an update is available to fetch for hubs that require publishing.
    # ```ballerina
    #  websubhub:Acknowledgement|websubhub:UpdateMessageError response = check publisherClient->notifyUpdate("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic for which the update occurred
    # + return - A `websubhub:UpdateMessageError` if an error occurred with the notification or else `websubhub:Acknowledgement`
    isolated remote function notifyUpdate(string topic) returns Acknowledgement|UpdateMessageError {
        http:Request notifyUpdateRequest = new;
        string reqPayload = string `${HUB_MODE}=${MODE_PUBLISH}&${HUB_TOPIC}=${topic}`;
        notifyUpdateRequest.setTextPayload(reqPayload, mime:APPLICATION_FORM_URLENCODED);
        notifyUpdateRequest.setHeader(BALLERINA_PUBLISH_HEADER, EVENT_NOTIFY);
        http:Response|error notifyResponse = self.httpClient->post("", notifyUpdateRequest);
        if notifyResponse is http:Response {
            Acknowledgement|Error clientResponse = handleResponse(notifyResponse, topic, NOTIFY_UPDATE_ACTION);
            if clientResponse is Error {
                CommonResponse errorDetails = clientResponse.detail();
                return error UpdateMessageError(clientResponse.message(), clientResponse, 
                    statusCode = errorDetails.statusCode, mediaType = errorDetails?.mediaType, body = errorDetails?.body, headers = errorDetails?.headers);
            } else {
                return clientResponse;
            }
        } else {
            return error UpdateMessageError(string `Update availability notification failed for topic [${topic}]`, 
                notifyResponse, statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
    }
}

isolated function handleResponse(http:Response response, string topic, string action) returns CommonResponse|Error {
    string responsePayloadType = response.getContentType();
    string|http:ClientError result = response.getTextPayload();
    string responsePayload = result is string ? result : result.message();
    map<string> responseBody = getFormData(responsePayload);
    map<string|string[]> responseHeaders = getHeaders(response);
    int statusCode = response.statusCode;
    if statusCode != http:STATUS_OK {
        string errorMsg = string `Error occurred while executing ${action} action for topic [${topic}]`;
        return error Error(errorMsg, statusCode = statusCode, mediaType = responsePayloadType, body = responseBody, headers = responseHeaders);
    } else {
        if responseBody[HUB_MODE] == MODE_ACCEPTED {
            return {
                statusCode: statusCode,
                mediaType: responsePayloadType,
                body: responseBody,
                headers: responseHeaders
            };
        } else {
            string? failureReason = responseBody[HUB_REASON];
            string constructedErrorMsg = string `Unknown error occurred while executing ${action} action for topic [${topic}]`;
            string errorMsg = failureReason is string ? failureReason : constructedErrorMsg;
            return error Error(errorMsg, statusCode = statusCode, mediaType = responsePayloadType, body = responseBody, headers = responseHeaders);
        }
    }
}

isolated function buildTopicRegistrationChangeRequest(string mode, string topic) returns http:Request {
    http:Request request = new;
    request.setTextPayload(HUB_MODE + "=" + mode + "&" + HUB_TOPIC + "=" + topic);
    request.setHeader(CONTENT_TYPE, mime:APPLICATION_FORM_URLENCODED);
    return request;
}

isolated function getHeaders(http:Response response) returns map<string|string[]> {
    string[] headerNames = response.getHeaderNames();
    map<string|string[]> headers = {};
    foreach string header in headerNames {
        string[]|error responseHeaders = response.getHeaders(header);
        if responseHeaders is string[] {
            headers[header] = responseHeaders.length() == 1 ? responseHeaders[0] : responseHeaders;
        }
        // Not possible to throw header not found
    }
    return headers;
}
