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
import ballerina/test;

listener http:Listener utilServiceListener = new http:Listener(9102);

service /subscription on utilServiceListener {
    isolated resource function get . (string key1, string key2) returns string {
        return string `Key1=${key1}/Key2=${key2}`;
    }

        isolated resource function get additional (string baseKey, string key1, string key2) returns string {
        return string `BaseKey=${baseKey}/Key1=${key1}/Key2=${key2}`;
    }
}

@test:Config { 
    groups: ["sendNotification"]
}
isolated function testSendNotification() returns error? {
    [string, string?][] params = [
        ["key1", "val1"],
        ["key2", "val2"]    
    ];
    http:Response res = check sendNotification("http://localhost:9102/subscription", params, {});
    string payload = check res.getTextPayload();
    test:assertEquals(payload, "Key1=val1/Key2=val2");
}

// @test:Config { 
//     groups: ["sendNotification"]
// }
isolated function testSendNotificationWithQueyParamInCallback() returns error? {
    [string, string?][] params = [
        ["key1", "val1"],
        ["key2", "val2"]    
    ];
    http:Response res = check sendNotification("http://localhost:9102/subscription/additional?baseKey=baseVal", params, {});
    string payload = check res.getTextPayload();
    test:assertEquals(payload, "BaseKey=baseVal/Key1=val1/Key2=val2");
}
