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
import ballerina/mime;

isolated function retrieveQueryParameter(map<string|string[]> params, string 'key) returns string|error {
    string|string[]? retrievedValue = params.removeIfHasKey('key);
    if retrievedValue is string {
        string? decodedValue = check decodeQueryParam(retrievedValue, 'key);
        if decodedValue is string {
            return decodedValue;
        }
    } else if retrievedValue is string[] && retrievedValue.length() >= 1 {
        string? decodedValue = check decodeQueryParam(retrievedValue[0], 'key);
        if decodedValue is string {
            return decodedValue;
        }
    }
    return error("Empty value found for parameter '" + 'key + "'");
}

isolated function decodeQueryParam(string value, string 'key) returns string|error? {
    string|error decodedValue = url:decode(value, "UTF-8");
    if decodedValue is error {
        return error("Invalid value found for parameter '" + 'key + "' : " + decodedValue.message());
    } else if decodedValue != "" {
        return decodedValue;
    }
    return ();
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

isolated function updateErrorResponse(http:Response httpResponse, CommonResponse originalResponse, string reason) {
    httpResponse.statusCode = originalResponse.statusCode;
    updateHubResponse(httpResponse, MODE_DENIED, originalResponse?.body, originalResponse?.headers, reason);
}

isolated function updateSuccessResponse(http:Response httpResponse, int statusCode, anydata? messageBody, 
                                        map<string|string[]>? headers) {
    httpResponse.statusCode = statusCode;
    updateHubResponse(httpResponse, MODE_ACCEPTED, messageBody, headers);
}

isolated function updateHubResponse(http:Response response, string hubMode, 
                                    anydata? messageBody, map<string|string[]>? headers, 
                                    string? reason = ()) {
    string payload = generateResponsePayload(hubMode, messageBody, reason);
    response.setTextPayload(payload, mime:APPLICATION_FORM_URLENCODED);
    if headers is map<string|string[]> {
        foreach var [header, value] in headers.entries() {
            if value is string {
                response.setHeader(header, value);
            } else {
                foreach var valueElement in value {
                    response.addHeader(header, valueElement);
                }
            }
        }
    }
}

isolated function generateResponsePayload(string hubMode, anydata? messageBody, string? reason) returns string {
    string payload = string `${HUB_MODE}=${hubMode}`;
    payload += reason is string ? string `&${HUB_REASON}=${reason}` : "";
    if messageBody is map<string> && messageBody.length() > 0 {
        payload += "&" + retrieveTextPayloadForFormUrlEncodedMessage(messageBody);
    }
    return payload;
}

isolated function retrieveTextPayloadForFormUrlEncodedMessage(map<string> messageBody) returns string {
    string payload = "";
    string[] messageParams = [];
    foreach var ['key, value] in messageBody.entries() {
        messageParams.push('key + "=" + value);
    }
    payload += strings:'join("&", ...messageParams);
    return payload;
}

isolated function getHeaders(http:Response response) returns map<string|string[]> {
    map<string|string[]> responseHeaders = {};
    foreach string header in response.getHeaderNames() {
        string[]|error headers = response.getHeaders(header);
        if headers is string[] {
            responseHeaders[header] = headers.length() == 1 ? headers[0] : headers;
        }
        // Not possible to throw header not found
    }
    return responseHeaders;
}

isolated function getFormData(string payload) returns map<string> {
    map<string> parameters = {};
    if payload == "" {
        return parameters;
    }
    string[] queryParams = re `&`.split(payload);
    foreach string query in queryParams {
        int? index = query.indexOf("=");
        if index is int && index != -1 {
            string name = query.substring(0, index);
            name = name.trim();
            int size = query.length();
            string value = query.substring(index + 1, size);
            value = value.trim();
            if value != "" {
                parameters[name] = value;
            }
        }
    }
    return parameters;
}

isolated function retrieveHttpClient(string url, http:ClientConfiguration config) returns http:Client|Error {
    http:Client|error clientEp = new (url, config);
    if (clientEp is http:Client) {
        return clientEp;
    } else {
        return error Error("Client initialization failed", clientEp, statusCode = CLIENT_INIT_ERROR);
    }
}
