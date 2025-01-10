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
import kafkaHub.config;
import ballerina/jwt;
import ballerina/os;

final http:ListenerJwtAuthHandler handler = new({
    issuer: getIdpConfig("IDP_TOKEN_ISSUER", config:OAUTH2_CONFIG.issuer),
    audience: getIdpConfig("IDP_TOKEN_AUDIENCE", config:OAUTH2_CONFIG.audience),
    signatureConfig: {
        jwksConfig: {
            url: getIdpConfig("IDP_JWKS_ENDPOINT", config:OAUTH2_CONFIG.jwksUrl),
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: getIdpConfig("IDP_CLIENT_TRUSTSTORE_FILEPATH", config:OAUTH2_CONFIG.trustStore),
                        password: getIdpConfig("IDP_CLIENT_TRUSTSTORE_PASSWORD", config:OAUTH2_CONFIG.trustStorePassword)
                    }
                }
            }
        }
    },
    scopeKey: getIdpConfig("IDP_TOKEN_SCOPE_KEY", "scope")
});

isolated function getIdpConfig(string envVariableName, string defaultValue) returns string {
    return os:getEnv(envVariableName) == "" ? defaultValue : os:getEnv(envVariableName);
}

# Checks for authorization for the current request.
# 
# + headers - `http:Headers` for the current request
# + authScopes - Requested auth-scopes to access the current resource
# + return - `error` if there is any authorization error or else `()`
public isolated function authorize(http:Headers headers, string[] authScopes) returns error? {
    string|http:HeaderNotFoundError authHeader = headers.getHeader(http:AUTH_HEADER);
    if (authHeader is string) {
        jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
        if (auth is jwt:Payload) {
            http:Forbidden? forbiddenError = handler.authorize(auth, authScopes);
            if (forbiddenError is http:Forbidden) {
                log:printError("Forbidden Error received - Authentication credentials invalid");
                return error("Not authorized");
            }
        } else {
            log:printError("Unauthorized Error received - Authentication credentials invalid");
            return error("Not authorized");
        }
    } else {
        log:printError("Authorization header not found");
        return error("Not authorized");
    }
}
