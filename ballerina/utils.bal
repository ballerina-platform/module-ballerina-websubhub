// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/lang.'string as strings;
import ballerina/url;
import ballerina/http;
import ballerina/regex;

isolated function retrieveParameter(map<string> params, string 'key) returns string|error {
    string? retrievedValue = params.removeIfHasKey('key);
    if retrievedValue is string {
        string|error decodedValue = url:decode(retrievedValue, "UTF-8");
        if decodedValue is error {
            return error("Invalid value found for parameter '" + 'key + "' : " + decodedValue.message());
        } else if decodedValue != "" {
            return decodedValue;
        }
    }
    return error("Empty value found for parameter '" + 'key + "'");
}

isolated function sendNotification(string callbackUrl, [string, string?][] params, ClientConfiguration config) returns http:Response|error {
    string queryParams = generateQueryString(callbackUrl, params);
    http:Client httpClient = check  new(callbackUrl, retrieveHttpClientConfig(config));
    return httpClient->get(queryParams);
}

isolated function generateQueryString(string callbackUrl, [string, string?][] params) returns string {
    string[] keyValPairs = [];
    foreach var ['key, value] in params {
        if value is string {
            keyValPairs.push(string `${'key}=${value}`);
        }
    }
    return (strings:includes(callbackUrl, ("?")) ? "&" : "?") + strings:'join("&", ...keyValPairs);
}

# Processes the `topic` registration request.
# 
# + caller - The `http:Caller` reference of the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
isolated function processRegisterRequest(http:Caller caller, http:Response response,
                                         http:Headers headers, map<string> params, 
                                         HttpToWebsubhubAdaptor adaptor) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicRegistration msg = {
            topic: topic,
            hubMode: MODE_REGISTER
        };
        TopicRegistrationSuccess|TopicRegistrationError|error result = adaptor.callRegisterMethod(msg, headers);
        if (result is TopicRegistrationSuccess) {
            updateSuccessResponse(response, result["body"], result["headers"]);
        } else {
            var errorDetails = result is TopicRegistrationError ? result.detail(): TOPIC_REGISTRATION_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        }
    }
}

# Processes the `topic` deregistration request.
# 
# + caller - The `http:Caller` reference of the current request
# + response - The `http:Response`, which should be returned 
# + headers - The `http:Headers` received from the original `http:Request`
# + params - Query parameters retrieved from the `http:Request`
# + adaptor - Current `websubhub:HttpToWebsubhubAdaptor` instance
isolated function processDeregisterRequest(http:Caller caller, http:Response response,
                                           http:Headers headers, map<string> params, 
                                           HttpToWebsubhubAdaptor adaptor) {
    string? topic = getEncodedValueOrUpdatedErrorResponse(params, HUB_TOPIC, response);
    if (topic is string) {
        TopicDeregistration msg = {
            topic: topic,
            hubMode: MODE_DEREGISTER
        };
        TopicDeregistrationSuccess|TopicDeregistrationError|error result = adaptor.callDeregisterMethod(msg, headers);
        if (result is TopicDeregistrationSuccess) {
            updateSuccessResponse(response, result["body"], result["headers"]);
        } else {
            var errorDetails = result is TopicDeregistrationError ? result.detail() : TOPIC_DEREGISTRATION_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], result.message());
        }
    }
}

# Retrieves an URL-encoded parameter.
# 
# + params - Available query parameters
# + 'key - Required parameter name/key
# + response - The `http:Response`, which should be returned 
# + return - Requested parameter value if present or else `()`
isolated function getEncodedValueOrUpdatedErrorResponse(map<string> params, string 'key, 
                                                        http:Response response) returns string? {
    string|error? requestedValue = ();
    var retrievedValue = params.removeIfHasKey('key);
    if retrievedValue is string {
        requestedValue = url:decode(retrievedValue, "UTF-8");
    }
    if (requestedValue is string && requestedValue != "") {
       return <string> requestedValue;
    } else {
        updateBadRequestErrorResponse(response, 'key, requestedValue);
        return ();
    }
}

# Updates the error response for a bad request.
# 
# + response - The `http:Response`, which should be returned 
# + paramName - Errorneous parameter name
# + topicParameter - Received value or `error`
isolated function updateBadRequestErrorResponse(http:Response response, string paramName, 
                                                string|error? topicParameter) {
    string errorMessage = "";
    if (topicParameter is error) {
        errorMessage = "Invalid value found for parameter '" + paramName + "' : " + topicParameter.message();
    } else {
        errorMessage = "Empty value found for parameter '" + paramName + "'"; 
    }
    response.statusCode = http:STATUS_BAD_REQUEST;
    response.setTextPayload(errorMessage);
}

# Updates the generic error response.
# 
# + response - The `http:Response`, which should be returned 
# + messageBody - Optional response payload
# + headers - Optional additional response headers
# + reason - Optional reason for rejecting the request
isolated function updateErrorResponse(http:Response response, anydata? messageBody, 
                                      map<string|string[]>? headers, string reason) {
    updateHubResponse(response, "denied", messageBody, headers, reason);
}

# Updates the generic success response.
# 
# + response - The `http:Response`, which should be returned 
# + messageBody - Optional response payload
# + headers - Optional additional response headers
isolated function updateSuccessResponse(http:Response response, anydata? messageBody, 
                                        map<string|string[]>? headers) {
    updateHubResponse(response, "accepted", messageBody, headers);
}

# Updates the `hub` response.
# 
# + response - The `http:Response`, which should be returned 
# + hubMode - Current Hub mode
# + messageBody - Optional response payload
# + headers - Optional additional response headers
# + reason - Optional reason for rejecting the request
isolated function updateHubResponse(http:Response response, string hubMode, 
                                    anydata? messageBody, map<string|string[]>? headers, 
                                    string? reason = ()) {
    response.setHeader("Content-type","application/x-www-form-urlencoded");

    string payload = generateResponsePayload(hubMode, messageBody, reason);

    response.setTextPayload(payload);

    if (headers is map<string|string[]>) {
        foreach var [header, value] in headers.entries() {
            if (value is string) {
                response.setHeader(header, value);
            } else {
                foreach var valueElement in value {
                    response.addHeader(header, valueElement);
                }
            }
        }
    }
}

# Generates the payload to be added to the `hub` Response.
# 
# + hubMode - Current Hub mode
# + messageBody - Optional response payload
# + reason - Optional reason for rejecting the request
# + return - Response payload as a `string`
isolated function generateResponsePayload(string hubMode, anydata? messageBody, string? reason) returns string {
    string payload = "hub.mode=" + hubMode;
    payload += reason is string ? "&hub.reason=" + reason : "";
    if (messageBody is map<string> && messageBody.length() > 0) {
        payload += "&" + retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
    }
    return payload;
}

# Generates the form-URL-encoded response payload.
#
# + messageBody - Provided response payload
# + return - The formed URL-encoded response body
isolated function retrieveTextPayloadForFormUrlEncodedMessage(map<string> messageBody) returns string {
    string payload = "";
    string[] messageParams = [];
    foreach var ['key, value] in messageBody.entries() {
        messageParams.push('key + "=" + value);
    }
    payload += strings:'join("&", ...messageParams);
    return payload;
}

# Converts a text payload to `map<string>`.
# 
# + payload - Received text payload
# + return - Response payload as `map<string>`
isolated function retrieveResponseBodyForFormUrlEncodedMessage(string payload) returns map<string> {
    map<string> responsePayload = {};
    string[] queryParams = regex:split(payload, "&");
    foreach var query in queryParams {
        string[] keyValueEntry = regex:split(query, "=");
        if (keyValueEntry.length() == 2) {
            responsePayload[keyValueEntry[0]] = keyValueEntry[1];
        }
    }
    return responsePayload;
}

isolated function retrieveHttpClient(string url, http:ClientConfiguration config) returns http:Client|Error {
    http:Client|error clientEp = new (url, config);
    if (clientEp is http:Client) {
        return clientEp;
    } else {
        return error Error("Client initialization failed", clientEp);
    }
}

# Responds to the received `http:Request`.
# 
# + caller - The `http:Caller` reference of the current request
# + response - Updated `http:Response`
isolated function respondToRequest(http:Caller caller, http:Response response) {
    http:ListenerError? responseError = caller->respond(response);
}
