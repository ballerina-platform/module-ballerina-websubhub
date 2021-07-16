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

import ballerina/http;
import ballerina/regex;
import kafkaHub.config;

const string SUFFIX_GENERAL = "_GENERAL";
const string SUFFIX_ALL_INDIVIDUAL = "_ALL_INDIVIDUAL";
const string SUFFIX_INDIVIDUAL = "_INDIVIDUAL";

final http:Client clientEP = check new(config:MOSIP_AUTH_BASE_URL);

# Authorize the subscriber.
#
# + headers - `http:Headers` of request
# + topic - Topic of the message
# + return - `error` if there is any authorization error or else `()`
public isolated function authorizeSubscriber(http:Headers headers, string topic) returns error? {
    string token = check getToken(headers);
    json response = check getValidatedTokenResponse(token);
    string roles = (check response?.roles).toString();
    string[] rolesArr = regex:split(roles, ",");
    string userId = (check response?.userId).toString();
    string? partnerID = buildPartnerId(topic);
    string rolePrefix = buildRolePrefix(topic, "SUBSCRIBE_");
    boolean authorized = isSubscriberAuthorized(partnerID, rolePrefix, rolesArr, userId);
    if (!authorized) {
        return error("Subscriber is not authorized");
    }
}

# Authorize the publisher.
#
# + headers - `http:Headers` of request
# + topic - Topic of the message
# + return - `error` if there is any authorization error or else `()`
public isolated function authorizePublisher(http:Headers headers, string topic) returns error? {
    string token = check getToken(headers);
    json response = check getValidatedTokenResponse(token);
    string roles = (check response?.roles).toString();
    string[] rolesArr = regex:split(roles, ",");
    string? partnerID = buildPartnerId(topic);
    string rolePrefix = buildRolePrefix(topic, "PUBLISH_");
    boolean authorized = isPublisherAuthorized(partnerID, rolePrefix, rolesArr);
    if (!authorized) {
        return error("Publisher is not authorized");
    }
}

// Token is extracted from the cookies header which has the key `Authorization`
isolated function getToken(http:Headers headers) returns string|error {
    string cookieHeader = check headers.getHeader("Cookie");
    string[] values = regex:split(cookieHeader, "; ");
    foreach string value in values {
        if value.startsWith("Authorization=") {
            return regex:split(value, "=")[1];
        }
    }
    return error("Authorization token cannot be found");
}

isolated function buildRolePrefix(string topic, string prefix) returns string {
    int? index = topic.indexOf("/");
    if index is int {
        return prefix + topic.substring(index + 1, topic.length());
    } else {
        return prefix + topic;
    }
}

isolated function buildPartnerId(string topic) returns string? {
    int? index = topic.indexOf("/");
    if index is int {
        return topic.substring(0, index);
    }
}

isolated function getValidatedTokenResponse(string token) returns json|error {
    map<string> headerMap = {
        "Cookie": "Authorization=".concat(token)
    };
    json response = check clientEP->get(config:MOSIP_AUTH_VALIDATE_TOKEN_URL, headers = headerMap);
    return response;
}

isolated function isPublisherAuthorized(string? partnerID, string rolePrefix, string[] rolesArr) returns boolean {
    if partnerID is string {
        foreach string role in rolesArr {
            if role == rolePrefix.concat(SUFFIX_ALL_INDIVIDUAL) {
                return true;
            }
        }
    } else {
        foreach string role in rolesArr {
            if role == rolePrefix.concat(SUFFIX_GENERAL) {
                return true;
            }
        }
    }
    return false;
}

isolated function isSubscriberAuthorized(string? partnerID, string rolePrefix, string[] rolesArr, string userId)
                                         returns boolean {
    if partnerID is string {
        foreach string role in rolesArr {
            if role == rolePrefix.concat(SUFFIX_INDIVIDUAL) && partnerID == userId {
                return true;
            }
        }
    } else {
        foreach string role in rolesArr {
            if role == rolePrefix.concat(SUFFIX_GENERAL) {
                return true;
            }
        }
    }
    return false;
}
