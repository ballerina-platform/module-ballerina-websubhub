// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

final readonly & json ADD_NEW_USER_MESSAGE = {
    "iss": "Asgardeo",
    "jti": "84d449d92b7f",
    "iat": 1664254276282,
    "aud": "https://websubhub/topics/test/REGISTRATIONS",
    "event": {
        "urn:ietf:params:registrations:event:addUser": {
            "ref": "https://dev.api.asgardeo.io/t/test/scim2/Users/user123",
            "organizationId": 365,
            "organizationName": "test",
            "userId": "user123",
            "userName": "test123@mailinator.com",
            "userStoreName": "DEFAULT",
            "userOnboardMethod": "ADMIN_INITIATED",
            "roleList": [],
            "claims": {
                "http://wso2.org/claims/created": "2022-09-27T04:51:16.2393770Z",
                "http://wso2.org/claims/emailaddress": "test123@mailinator.com",
                "http://wso2.org/claims/location": "https://dev.api.asgardeo.io/t/test/scim2/Users/user123",
                "http://wso2.org/claims/lastname": "John",
                "http://wso2.org/claims/givenname": "Doe"
            }
        }
    }
};

final readonly & json LOGIN_SUCCESS_MESSAGE = {
    "iss": "Asgardeo",
    "jti": "9965a050e94d",
    "iat": 1664197085083,
    "aud": "https://websubhub/topics/test/LOGINS",
    "event": {
        "urn:ietf:params:logins:event:loginSuccess": {
            "ref": "https://dev.api.asgardeo.io/scim2/Users/user123",
            "organizationId": 1610,
            "organizationName": "test",
            "userId": "user123",
            "userName": "test123@mailinator.com",
            "userStoreName": "DEFAULT",
            "serviceProvider": "My Account"
        }
    }
};
