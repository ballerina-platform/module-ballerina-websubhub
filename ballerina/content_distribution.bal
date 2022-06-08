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
    string topic = check retrieveQueryParameter(params, HUB_TOPIC);
    string contentTypeValue = request.getContentType();
    http:HeaderValue[] values = check http:parseHeader(contentTypeValue);
    string contentType = values[0].value;
    UpdateMessage updateMsg = check createUpdateMessage(contentType, topic, request);
    Acknowledgement|error updateResult = adaptor.callOnUpdateMethod(updateMsg, headers);
    return processResult(updateResult);
}

isolated function createUpdateMessage(string contentType, string topic, http:Request request) returns UpdateMessage|error {
    string|http:HeaderNotFoundError ballerinaPublishEvent = request.getHeader(BALLERINA_PUBLISH_HEADER);
    if ballerinaPublishEvent is string && ballerinaPublishEvent == "event" {
        return {
            hubTopic: topic,
            msgType: EVENT,
            contentType: contentType,
            content: ()
        };
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
            return error Error("Requested content type is not supported", statusCode = http:STATUS_BAD_REQUEST);
        }
    }
}

isolated function processResult(Acknowledgement|error result) returns http:Response {
    http:Response response = new;
    if (result is Acknowledgement) {
        response.statusCode = http:STATUS_OK;
        response.setTextPayload("hub.mode=accepted", mime:APPLICATION_FORM_URLENCODED);
    } else {
        CommonResponse errorDetails = result is UpdateMessageError ? result.detail(): UPDATE_MESSAGE_ERROR.detail();
        updateErrorResponse(response, errorDetails, result.message());
    }
    return response;
}
