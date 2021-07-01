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
import ballerina/regex;

# The HTTP based client for WebSub topic registration and deregistration, and notifying the hub of new updates.
public client class PublisherClient {

    private string url;
    private http:Client httpClient;

    # Initializes the `websub:PublisherClient`.
    # ```ballerina
    # websub:PublisherClient websubHubClientEP = new("http://localhost:9191/websub/publish");
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
    # websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError registerTopic = websubHubClientEP->registerTopic("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic to register
    # + return - A `websubhub:TopicRegistrationError` if an error occurred registering the topic or else `websubhub:TopicRegistrationSuccess`
    isolated remote function registerTopic(string topic) returns TopicRegistrationSuccess|TopicRegistrationError {
        http:Request request = buildTopicRegistrationChangeRequest(MODE_REGISTER, topic);
        http:Response|error registrationResponse = self.httpClient->post("", request);
        if registrationResponse is http:Response {
            var result = registrationResponse.getTextPayload();
            string payload = result is string ? result : "";
            if registrationResponse.statusCode != http:STATUS_OK {
                string errorMsg = string `"Error occurred during registering topic [${topic}], Status code : ${registrationResponse.statusCode}, payload: ${payload}`;
                return error TopicRegistrationError(errorMsg);
            } else {
                map<string>? params = getFormData(payload);
                if params[HUB_MODE] == MODE_ACCEPTED {
                    TopicRegistrationSuccess successResult = {
                        headers: getHeaders(registrationResponse),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params[HUB_REASON];
                    string errorMsg = failureReason is string ? failureReason : string `${TOPIC_REGISTRATION_COMMON_ERROR} [${topic}]`;
                    return error TopicRegistrationError(errorMsg);
                }
            }
        } else {
            return error TopicRegistrationError(string `"Error sending topic registration request for topic [${topic}]`, registrationResponse);
        }
    }

    // todo remove all taint checks

    # Deregisters a topic in a Ballerina WebSub Hub.
    # ```ballerina
    # websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError deregisterTopic = websubHubClientEP->deregisterTopic("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic to deregister
    # + return -  A `websubhub:TopicDeregistrationError` if an error occurred un registering the topic or else `websubhub:TopicDeregistrationSuccess`
    isolated remote function deregisterTopic(string topic) returns TopicDeregistrationSuccess|TopicDeregistrationError {
        http:Request request = buildTopicRegistrationChangeRequest(MODE_DEREGISTER, topic);
        http:Response|error deregistrationResponse = self.httpClient->post("", request);
        if deregistrationResponse is http:Response {
            string|http:ClientError result = deregistrationResponse.getTextPayload();
            string payload = result is string ? result : result.message();
            if deregistrationResponse.statusCode != http:STATUS_OK {
                string errorMsg = string `Error occurred during deregistering topic [${topic}], Status code : ${deregistrationResponse.statusCode}, payload: ${payload}`;
                return error TopicDeregistrationError(errorMsg);
            } else {
                map<string>? params = getFormData(payload);
                if params[HUB_MODE] == MODE_ACCEPTED {
                    TopicDeregistrationSuccess successResult = {
                        headers: getHeaders(deregistrationResponse),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params[HUB_REASON];
                    string errorMsg = failureReason is string ? failureReason : string `${TOPIC_DEREGISTRATION_COMMON_ERROR} [${topic}]`;
                    return error TopicDeregistrationError(errorMsg);
                }
            }
        } else {
            return error TopicDeregistrationError(string `Error sending topic deregistration request for topic [${topic}]`, deregistrationResponse);
        }
    }

    # Publishes an update to a remote Ballerina WebSub Hub.
    # ```ballerina
    # websubhub:Acknowledgement|websubhub:UpdateMessageError publishUpdate = websubHubClientEP->publishUpdate("http://websubpubtopic.com",{"action": "publish",
    # "mode": "remote-hub"});
    # ```
    #
    # + topic - The topic for which the update occurred
    # + payload - The update payload
    # + contentType - The type of the update content to set as the `ContentType` header
    # + return -  A `websubhub:UpdateMessageError`if an error occurred with the update or else `websubhub:Acknowledgement`
    isolated remote function publishUpdate(string topic, map<string>|xml|json|byte[] payload,
                                  string? contentType = ()) returns Acknowledgement|UpdateMessageError {
        http:Request contentUpdateRequest = new;
        if payload is map<string> {
            string[] payloadValues = [];
            foreach var ['key, value] in payload.entries() {
                payloadValues.push(string `${'key}=${value}`);
            }
            string reqPayload = string:'join("&", ...payloadValues);
            contentUpdateRequest.setTextPayload(reqPayload, mime:APPLICATION_FORM_URLENCODED);
            contentUpdateRequest.setHeader(BALLERINA_PUBLISH_HEADER, CONTENT_PUBLISH);
        } else {
            contentUpdateRequest.setPayload(payload);
        }
        if contentType is string {
            var setContent = contentUpdateRequest.setContentType(contentType);
            if setContent is error {
                string errorMsg = string `Invalid content type is set, found ${contentType}`;
                return error UpdateMessageError(errorMsg, setContent);
             }
        }
        string queryParams = string `${HUB_MODE}=${MODE_PUBLISH}&${HUB_TOPIC}=${topic}`;
        http:Response|error response = self.httpClient->post(string `"${queryParams}`, contentUpdateRequest);
        if response is http:Response {
            string|http:ClientError result = response.getTextPayload();
            string responsePayload = result is string ? result : result.message();
            if response.statusCode != http:STATUS_OK {
                string errorMsg = string `Error occurred during event publish update for topic [${topic}], Status code : ${response.statusCode}, payload: ${responsePayload}`;
                return error UpdateMessageError(errorMsg);
            } else {
                map<string>? params = getFormData(responsePayload);
                if params[HUB_MODE] == MODE_ACCEPTED {
                    Acknowledgement successResult = {
                        headers: getHeaders(response),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params[HUB_REASON];
                    string errorMsg = failureReason is string ? failureReason : string `${CONTENT_UPDATE_COMMON_ERROR} [${topic}]`;
                    return error UpdateMessageError(errorMsg);
                }
            }
        } else {
            return error UpdateMessageError(string `Publish failed for topic [${topic}]`, response);
        }
    }

    # Notifies a remote WebSubHub from which an update is available to fetch for hubs that require publishing.
    # ```ballerina
    # websubhub:Acknowledgement|websubhub:UpdateMessageError notifyUpdate = websubHubClientEP->notifyUpdate("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic for which the update occurred
    # + return -  A `websubhub:UpdateMessageError` if an error occurred with the notification or else `websubhub:Acknowledgement`
    isolated remote function notifyUpdate(string topic) returns Acknowledgement|UpdateMessageError {
        http:Request notifyUpdateRequest = new;
        string reqPayload = string `${HUB_MODE}=${MODE_PUBLISH}&${HUB_TOPIC}=${topic}`;
        notifyUpdateRequest.setTextPayload(reqPayload, mime:APPLICATION_FORM_URLENCODED);
        notifyUpdateRequest.setHeader(BALLERINA_PUBLISH_HEADER, EVENT_NOTIFY);
        http:Response|error response = self.httpClient->post("", notifyUpdateRequest);
        if response is http:Response {
            string|http:ClientError result = response.getTextPayload();
            string responsePayload = result is string ? result : result.message();
            if response.statusCode != http:STATUS_OK {
                string errorMsg = string `Error occurred during notify update for topic [${topic}], Status code : ${response.statusCode}, payload : ${responsePayload}`;
                return error UpdateMessageError(errorMsg);
            } else {
                map<string>? params = getFormData(responsePayload);
                if params[HUB_MODE] == MODE_ACCEPTED {
                    Acknowledgement successResult = {
                        headers: getHeaders(response),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params[HUB_REASON];
                    string errorMsg = failureReason is string ? failureReason : string `${EVENT_NOTIFY_COMMON_ERROR} [${topic}]`;
                    return error UpdateMessageError(errorMsg);
                }
            }
        } else {
            return error UpdateMessageError(string `Update availability notification failed for topic [${topic}]`, response);
        }
    }
}

isolated function buildTopicRegistrationChangeRequest(string mode, string topic) returns http:Request {
    http:Request request = new;
    request.setTextPayload(HUB_MODE + "=" + mode + "&" + HUB_TOPIC + "=" + topic);
    request.setHeader(CONTENT_TYPE, mime:APPLICATION_FORM_URLENCODED);
    return request;
}

isolated function getFormData(string payload) returns map<string> {
    map<string> parameters = {};
    if payload == "" {
        return parameters;
    }
    string[] entries = regex:split(payload, "&");
    int entryIndex = 0;
    while (entryIndex < entries.length()) {
        int? index = entries[entryIndex].indexOf("=");
        if index is int && index != -1 {
            string name = entries[entryIndex].substring(0, index);
            name = name.trim();
            int size = entries[entryIndex].length();
            string value = entries[entryIndex].substring(index + 1, size);
            value = value.trim();
            if value != "" {
                parameters[name] = value;
            }
        }
        entryIndex = entryIndex + 1;
    }
    return parameters;
}

isolated function getHeaders(http:Response response) returns map<string|string[]> {
    string[] headerNames = response.getHeaderNames();
    map<string|string[]> headers = {};
    foreach var header in headerNames {
        var responseHeaders = response.getHeaders(header);
        if responseHeaders is string[] {
            headers[header] = responseHeaders.length() == 1 ? responseHeaders[0] : responseHeaders;
        }
        // Not possible to throw header not found
    }
    return headers;
}
