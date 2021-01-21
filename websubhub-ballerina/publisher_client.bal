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

# The HTTP based client for WebSub topic registration and unregistration, and notifying the hub of new updates.
public client class PublisherClient {

    private string url;
    private http:Client httpClient;

    # Initializes the `websub:PublisherClient`.
    # ```ballerina
    # websub:PublisherClient websubHubClientEP = new("http://localhost:9191/websub/publish");
    # ```
    #
    # + url    - The URL to publish/notify updates
    # + config - The `http:ClientConfiguration` for the underlying client or else `()`
    public function init(string url, http:ClientConfiguration? config = ()) returns error? {
        self.url = url;
        self.httpClient = check new (self.url, config);
    }

    # Registers a topic in a Ballerina WebSub Hub against which subscribers can subscribe and the publisher will
    # publish updates.
    # ```ballerina
    # error? registerTopic = websubHubClientEP->registerTopic("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic to register
    # + return - An `error` if an error occurred registering the topic or else `()`
    remote function registerTopic(string topic) returns @tainted TopicRegistrationSuccess|TopicRegistrationError {
        http:Client httpClient = self.httpClient;
        http:Request request = buildTopicRegistrationChangeRequest(MODE_REGISTER, topic);
        var registrationResponse = httpClient->post("", request);
        if (registrationResponse is http:Response) {
            var result = registrationResponse.getTextPayload();
            string payload = result is string ? result : "";
            if (registrationResponse.statusCode != http:STATUS_OK) {
                return error TopicRegistrationError("Error occurred during topic registration, Status code : "
                               +  registrationResponse.statusCode.toString() + ", payload: " + payload);
            } else {
                map<string>? params = getFormData(payload);
                if (params[HUB_MODE] == "accepted") {
                    TopicRegistrationSuccess successResult = {
                        headers: getHeaders(registrationResponse),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params["hub.reason"];
                    return error TopicRegistrationError(failureReason is () ? "" : <string> failureReason);
                }
            }
        } else {
            return error TopicRegistrationError("Error sending topic registration request: " + (<error>registrationResponse).message());
        }
    }

    # Unregisters a topic in a Ballerina WebSub Hub.
    # ```ballerina
    # error? unregisterTopic = websubHubClientEP->unregisterTopic("http://websubpubtopic.com");
    #  ```
    #
    # + topic - The topic to unregister
    # + return -  An `error`if an error occurred un registering the topic or else `()`
    remote function unregisterTopic(string topic) returns @tainted TopicUnregistrationSuccess|TopicUnregistrationError {
        http:Client httpClient = self.httpClient;
        http:Request request = buildTopicRegistrationChangeRequest(MODE_UNREGISTER, topic);
        var unregistrationResponse = httpClient->post("", request);
        if (unregistrationResponse is http:Response) {
            var result = unregistrationResponse.getTextPayload();
            string payload = result is string ? result : "";
            if (unregistrationResponse.statusCode != http:STATUS_OK) {
                return error TopicUnregistrationError("Error occurred during topic registration, Status code : "
                        +  unregistrationResponse.statusCode.toString() + ", payload: " + payload);
            } else {
                map<string>? params = getFormData(payload);
                if (params[HUB_MODE] == "accepted") {
                    TopicUnregistrationSuccess successResult = {
                        headers: getHeaders(unregistrationResponse),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params["hub.reason"];
                    return error TopicUnregistrationError(failureReason is () ? "" : <string> failureReason);
                }
            }
        } else {
            return error TopicUnregistrationError("Error sending topic unregistration request: "
                                    + (<error>unregistrationResponse).message());
        }
    }

    # Publishes an update to a remote Ballerina WebSub Hub.
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
    remote function publishUpdate(string topic, map<string>|string|xml|json|byte[] payload,
                                  string? contentType = ()) returns @tainted Acknowledgement|UpdateMessageError {
        http:Client httpClient = self.httpClient;
        http:Request request = new;
        string queryParams = HUB_MODE + "=" + MODE_PUBLISH + "&" + HUB_TOPIC + "=" + topic;

        if (payload is map<string>) {
            string reqPayload = "";
            foreach var ['key, value] in payload.entries() {
                reqPayload = reqPayload + 'key + "=" + value + "&";
            }
            if (reqPayload != "") {
                reqPayload = reqPayload.substring(0, reqPayload.length() - 2);
            }
            request.setTextPayload(reqPayload, mime:APPLICATION_FORM_URLENCODED);
            request.setHeader(BALLERINA_PUBLISH_HEADER, "publish");
        } else {
            request.setPayload(payload);
        }

        if (contentType is string) {
            var setContent = request.setContentType(contentType);
            if (setContent is error) {
                return error UpdateMessageError("Invalid content type is set, found " + contentType);
             }
        }

        var response = httpClient->post(<@untainted string> ("?" + queryParams), request);
        if (response is http:Response) {
            var result = response.getTextPayload();
            string responsePayload = result is string ? result : "";
            if (response.statusCode != http:STATUS_OK) {
                return error UpdateMessageError("Error occurred during event publish update, Status code : "
                +  response.statusCode.toString() + ", payload: " + responsePayload);
            } else {
                map<string>? params = getFormData(responsePayload);
                if (params[HUB_MODE] == "accepted") {
                    Acknowledgement successResult = {
                        headers: getHeaders(response),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params["hub.reason"];
                    return error UpdateMessageError(failureReason is () ? "" : <string> failureReason);
                }
            }
        } else {
            return error UpdateMessageError("Publish failed for topic [" + topic + "]");
        }
    }

    # Notifies a remote WebSub Hub from which an update is available to fetch for hubs that require publishing to
    # happen as such.
    # ```ballerina
    #  error? notifyUpdate = websubHubClientEP->notifyUpdate("http://websubpubtopic.com");
    #   ```
    #
    # + topic - The topic for which the update occurred
    # + headers - The headers that need to be set (if any)
    # + return -  An `error`if an error occurred with the notification or else `()`
    remote function notifyUpdate(string topic) returns @tainted Acknowledgement|UpdateMessageError {
        http:Client httpClient = self.httpClient;
        http:Request request = new;
        string reqPayload = HUB_MODE + "=" + MODE_PUBLISH + "&" + HUB_TOPIC + "=" + topic;
        request.setTextPayload(reqPayload, mime:APPLICATION_FORM_URLENCODED);

        request.setHeader(BALLERINA_PUBLISH_HEADER, "event");

        var response = httpClient->post("/", request);
        if (response is http:Response) {
            var result = response.getTextPayload();
            string payload = result is string ? result : "";
            if (response.statusCode != http:STATUS_OK) {
                return error UpdateMessageError("Error occurred during notify update, Status code : "
                +  response.statusCode.toString() + ", payload: " + payload);
            } else {
                map<string>? params = getFormData(payload);
                if (params[HUB_MODE] == "accepted") {
                    Acknowledgement successResult = {
                        headers: getHeaders(response),
                        body: params
                    };
                    return successResult;
                } else {
                    string? failureReason = params["hub.reason"];
                    return error UpdateMessageError(failureReason is () ? "" : <string> failureReason);
                }
            }
        } else {
            return error UpdateMessageError("Update availability notification failed for topic [" + topic + "]");
        }
    }
}

# Builds the topic registration change request to register or unregister a topic at the hub.
#
# + mode - Whether the request is for registration or unregistration
# + topic - The topic to register/unregister
# + return - An `http:Request` to be sent to the hub to register/unregister
isolated function buildTopicRegistrationChangeRequest(@untainted string mode, @untainted string topic) returns (http:Request) {
    http:Request request = new;
    request.setTextPayload(HUB_MODE + "=" + mode + "&" + HUB_TOPIC + "=" + topic);
    request.setHeader(CONTENT_TYPE, mime:APPLICATION_FORM_URLENCODED);
    return request;
}

isolated function getFormData(string payload) returns map<string> {
    map<string> parameters = {};

    if (payload == "") {
        return parameters;
    }

    string[] entries = regex:split(payload, "&");
    int entryIndex = 0;
    while (entryIndex < entries.length()) {
        int? index = entries[entryIndex].indexOf("=");
        if (index is int && index != -1) {
            string name = entries[entryIndex].substring(0, index);
            name = name.trim();
            int size = entries[entryIndex].length();
            string value = entries[entryIndex].substring(index + 1, size);
            value = value.trim();
            if (value != "") {
                parameters[name] = value;
            }
        }
        entryIndex = entryIndex + 1;
    }
    return parameters;
}

isolated function getHeaders(http:Response response) returns @tainted map<string|string[]> {
    string[] headerNames = response.getHeaderNames();

    map<string|string[]> headers = {};
    foreach var header in headerNames {
        var responseHeaders = response.getHeaders(header);
        if (responseHeaders is string[]) {
            headers[header] = responseHeaders.length() == 1 ? responseHeaders[0] : responseHeaders;
        }
        // Not possible to throw header not found
    }
    return headers;
}
