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
import ballerina/mime;

isolated function processContentPublish(http:Request request, http:Headers headers, 
                                        map<string> params, HttpToWebsubhubAdaptor adaptor) returns http:Response|error {
    string? topic = params[HUB_TOPIC];
    if topic is () {
        return error Error("Could not find the `hub.topic` parameter");
    } else {
        string contentTypeValue = request.getContentType();
        var [contentType, headerParameters] = check http:parseHeader(contentTypeValue);
        UpdateMessage updateMsg = check createUpdateMessage(contentType, topic, request);
        Acknowledgement|error updateResult = adaptor.callOnUpdateMethod(updateMsg, headers);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        if (updateResult is Acknowledgement) {
            response.setTextPayload("hub.mode=accepted");
            response.setHeader("Content-type","application/x-www-form-urlencoded");
        } else if (updateResult is UpdateMessageError) {
            var errorDetails = updateResult.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], updateResult.message());
        } else {
            var errorDetails = UPDATE_MESSAGE_ERROR.detail();
            updateErrorResponse(response, errorDetails["body"], errorDetails["headers"], updateResult.message());
        }
        return response;
    }
}

isolated function createUpdateMessage(string contentType, string topic, http:Request request) returns UpdateMessage|error {
    string|http:HeaderNotFoundError ballerinaPublishEvent = request.getHeader(BALLERINA_PUBLISH_HEADER);
    if ballerinaPublishEvent is string {
        if ballerinaPublishEvent == "publish" {
            return {
                hubTopic: topic,
                msgType: PUBLISH,
                contentType: contentType,
                content: check retrieveRequestBody(contentType, request)
            };
        } else {
            return {
                hubTopic: topic,
                msgType: EVENT,
                contentType: contentType,
                content: ()
            };
        }
    } else {
        return {
            hubTopic: topic,
            msgType: PUBLISH,
            contentType: contentType,
            content: check retrieveRequestBody(contentType, request)
        };
    }
}

isolated function retrieveRequestBody(string contentType, http:Request request) returns json|xml|string|byte[]|error {
    match contentType {
        mime:APPLICATION_FORM_URLENCODED => {
            return check request.getFormParams();
        }
        mime:APPLICATION_JSON => {
            return check request.getJsonPayload();
        }
        mime:APPLICATION_XML => {
            return check request.getXmlPayload();
        }
        mime:TEXT_PLAIN => {
            return check request.getTextPayload();
        }
        mime:APPLICATION_OCTET_STREAM => {
            return check request.getBinaryPayload();
        }
        _ => {
            return error Error("Requested content type is not supported");
        }
    }
}
