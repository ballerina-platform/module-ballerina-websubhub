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

import ballerina/log;
import ballerina/http;
import ballerina/jwt;
import kafkaHub.config;
import ballerina/regex;

const SCOPE_KEY = "organization";
const HANDLE = "handle";

final http:ListenerJwtAuthHandler handler = new({
    signatureConfig: {
        certFile: config:JWT_SIGNATURE_VALIDATOR_CERT
    }
});

# Checks for authorization for the current request.
# 
# + headers - `http:Headers` for the current request
# + hubTopic - WebSub `topic` related to the request
# + return - `error` if there is any authorization error or else `()`
public isolated function authorize(http:Headers headers, string hubTopic) returns error? {
    string|http:HeaderNotFoundError authHeader = headers.getHeader(http:AUTH_HEADER);
    if authHeader is http:HeaderNotFoundError {
        log:printError("Authorization header not found");
        return error("Not authorized");
    }
    jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
    if auth is jwt:Payload {
        string authScope = regex:split(hubTopic, "-")[0];
        record {
            string 'handle;
            string uuid;
        }|error organizationInfo = retrieveOrgInfo(auth);
        if organizationInfo is error {
            log:printError("Auth scopes not found for key 'organization'", 'error = organizationInfo);
            return error("Could not find the required scopes, hence not authorized", organizationInfo.cause());
        }
        string orgName = organizationInfo.'handle;
        if orgName != authScope {
            return error("Authentication credentials invalid, hence not authorized");
        }
    } else {
        log:printError("Unauthorized Error received - Authentication credentials invalid", details = auth.toBalString());
        return error("Not authorized");
    }
}

isolated function retrieveOrgInfo(jwt:Payload payload) returns record {string 'handle; string uuid;}|error {
    json|error scopeDetails = payload[SCOPE_KEY].ensureType();
    if scopeDetails is error {
        return error ("Could not find the required scopes, hence not authorized", scopeDetails.cause());
    }
    return scopeDetails.fromJsonWithType();
}
