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
    public function init(string url, http:ClientConfiguration? config = ()) {
        self.url = url;
        self.httpClient = checkpanic new (self.url, config);
    }

    # Registers a topic in a Ballerina WebSub Hub against which subscribers can subscribe and the publisher will
    # publish updates.
    # ```ballerina
    # error? registerTopic = websubHubClientEP->registerTopic("http://websubpubtopic.com");
    # ```
    #
    # + topic - The topic to register
    # + return - An `error` if an error occurred registering the topic or esle `()`
    remote function registerTopic(string topic) returns @tainted error? {
        http:Client httpClient = self.httpClient;
        http:Request request = buildTopicRegistrationChangeRequest(MODE_REGISTER, topic);
        var registrationResponse = httpClient->post("", request);
        if (registrationResponse is http:Response) {
            if (registrationResponse.statusCode != http:STATUS_ACCEPTED) {
                var result = registrationResponse.getTextPayload();
                string payload = result is string ? result : "";
                return error WebSubError("Error occurred during topic registration: " + payload);
            }
        } else {
            return error WebSubError("Error sending topic registration request: " + (<error>registrationResponse).message());
        }
    }

    # Unregisters a topic in a Ballerina WebSub Hub.
    # ```ballerina
    # error? unregisterTopic = websubHubClientEP->unregisterTopic("http://websubpubtopic.com");
    #  ```
    #
    # + topic - The topic to unregister
    # + return -  An `error`if an error occurred unregistering the topic or else `()`
    remote function unregisterTopic(string topic) returns @tainted error? {
        http:Client httpClient = self.httpClient;
        http:Request request = buildTopicRegistrationChangeRequest(MODE_UNREGISTER, topic);
        var unregistrationResponse = httpClient->post("", request);
        if (unregistrationResponse is http:Response) {
            if (unregistrationResponse.statusCode != http:STATUS_ACCEPTED) {
                var result = unregistrationResponse.getTextPayload();
                string payload = result is string ? result : "";
                return error WebSubError("Error occurred during topic unregistration: " + payload);
            }
        } else {
            return error WebSubError("Error sending topic unregistration request: "
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
    remote function publishUpdate(string topic, string|xml|json|byte[]|io:ReadableByteChannel payload,
                                         string? contentType = (), map<string>? headers = ()) returns @tainted error? {
        http:Client httpClient = self.httpClient;
        http:Request request = new;
        string queryParams = HUB_MODE + "=" + MODE_PUBLISH + "&" + HUB_TOPIC + "=" + topic;
        request.setPayload(payload);

        if (contentType is string) {
            check request.setContentType(contentType);
        }

        if (headers is map<string>) {
            foreach var [key, value] in headers.entries() {
                request.setHeader(key, value);
            }
        }

        var response = httpClient->post(<@untainted string> ("?" + queryParams), request);
        if (response is http:Response) {
            if (!isSuccessStatusCode(response.statusCode)) {
                var result = response.getTextPayload();
                string textPayload = result is string ? result : "";
                return error WebSubError("Error occurred publishing update: " + textPayload);
            }
        } else {
            return error WebSubError("Publish failed for topic [" + topic + "]");
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
    remote function notifyUpdate(string topic, map<string>? headers = ()) returns @tainted error? {
        http:Client httpClient = self.httpClient;
        http:Request request = new;
        string queryParams = HUB_MODE + "=" + MODE_PUBLISH + "&" + HUB_TOPIC + "=" + topic;

        if (headers is map<string>) {
            foreach var [key, value] in headers.entries() {
                request.setHeader(key, value);
            }
        }

        var response = httpClient->post(<@untainted string> ("?" + queryParams), request);
        if (response is http:Response) {
            if (!isSuccessStatusCode(response.statusCode)) {
                var result = response.getTextPayload();
                string textPayload = result is string ? result : "";
                return error WebSubError("Error occurred notifying update availability: " + textPayload);
            }
        } else {
            return error WebSubError("Update availability notification failed for topic [" + topic + "]");
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
