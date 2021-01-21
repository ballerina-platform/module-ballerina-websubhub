// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

# Parameter `hub.mode` representing the mode of the request from hub to subscriber or subscriber to hub.
const string HUB_MODE = "hub.mode";

# Subscription change or intent verification request parameter 'hub.topic'' representing the topic relevant to the for
# which the request is initiated.
const string HUB_TOPIC = "hub.topic";

const string HUB_CALLBACK = "hub.callback";

const string HUB_LEASE_SECONDS = "hub.lease_seconds";

const string HUB_SECRET = "hub.secret";

const string HUB_CHALLENGE = "hub.challenge";

# `hub.mode` value indicating "publish" mode, used by a publisher to notify an update to a topic.
const string MODE_PUBLISH = "publish";

# `hub.mode` value indicating "register" mode, used by a publisher to register a topic at a hub.
const string MODE_REGISTER = "register";

# `hub.mode` value indicating "unregister" mode, used by a publisher to unregister a topic at a hub.
const string MODE_UNREGISTER = "unregister";

# `hub.mode` value indicating "subscribe" mode, used by a subscriber to subscribe a topic at a hub.
const string MODE_SUBSCRIBE = "subscribe";

# `hub.mode` value indicating "unsubscribe" mode, used by a subscriber to unsubscribe a topic at a hub.
const string MODE_UNSUBSCRIBE = "unsubscribe";

const string CONTENT_TYPE = "Content-Type";

const string X_HUB_SIGNATURE = "X-Hub-Signature";

const string LINK = "Link";

const string BALLERINA_PUBLISH_HEADER = "x-ballerina-publisher";

const string SHA256_HMAC = "sha256";

const int STATUS_OK = 200;

const int STATUS_GONE = 410;

type Status distinct object {
    public int code;
};

public readonly class StatusOK {
    *Status;
    public STATUS_OK code = STATUS_OK;
}

final StatusOK STATUS_OK_OBJ = new;

type CommonResponse record {|
    string? mediaType = ();
    map<string|string[]>? headers = ();
    string|byte[]|json|xml|map<string>? body = ();
|};

# Record to represent a WebSub content delivery.
#
# + headers - Additional Request headers to include when distributing content
# + contentType - The content-type of the payload
# + content - The payload to be sent
public type ContentDistributionMessage record {|
    map<string|string[]>? headers = ();
    string? contentType = ();
    json|xml|string|byte[] content;
|};

public type ContentDistributionSuccess record {|
    *CommonResponse;
    readonly StatusOK status = STATUS_OK_OBJ;
|};

public type TopicRegistration record {|
    string topic;
|};

public type TopicUnregistration record {|
    string topic;
|};

// todo Any other params set in the payload(subscribers)
public type Subscription record {
    string hub;
    http:Request rawRequest;
    string hubMode;
    string hubCallback;
    string hubTopic;
    string? hubLeaseSeconds = ();
    string? hubSecret = ();
};

public type VerifiedSubscription record {
    *Subscription;
    boolean verificationSuccess;
};

public type Unsubscription record {
    http:Request rawRequest;
    string hubMode;
    string hubCallback;
    string hubTopic;
    string? hubSecret = ();
};

public type VerifiedUnsubscription record {
    *Unsubscription;
    boolean verificationSuccess;
};

public enum MessageType {
    EVENT,
    PUBLISH
}

public type UpdateMessage record {
    http:Request rawRequest;
    MessageType msgType;
    string hubTopic;
    string contentType;
    string|byte[]|json|xml|map<string>? content;
};

public type TopicRegistrationSuccess record {
    *CommonResponse;
};

public type TopicUnregistrationSuccess record {
    *CommonResponse;
};

public type SubscriptionAccepted record {
    *CommonResponse;
};

public type SubscriptionPermanentRedirect record {
    *CommonResponse;
    string[] redirectUrls;
    readonly StatusPermanentRedirect code = STATUS_PERMANENT_REDIRECT;
};

public type SubscriptionTemporaryRedirect record {
    *CommonResponse;
    string[] redirectUrls;
    readonly StatusTemporaryRedirect code = STATUS_TEMPORARY_REDIRECT;
};

public type UnsubscriptionAccepted record {
    *CommonResponse;
};

public type Acknowledgement record {
    *CommonResponse;
};

type StatusCode distinct object {
     public int code;
};

public readonly class StatusTemporaryRedirect {
    *StatusCode;
    public http:STATUS_TEMPORARY_REDIRECT code = http:STATUS_TEMPORARY_REDIRECT;
}

public readonly class StatusPermanentRedirect {
    *StatusCode;
    public http:STATUS_TEMPORARY_REDIRECT code = http:STATUS_TEMPORARY_REDIRECT;
}

final StatusTemporaryRedirect STATUS_TEMPORARY_REDIRECT = new;

final StatusPermanentRedirect STATUS_PERMANENT_REDIRECT = new;

isolated function isSuccessStatusCode(int statusCode) returns boolean {
    return (200 <= statusCode && statusCode < 300);
}

isolated function generateLinkUrl(string hubUrl, string topic) returns string {
    return hubUrl + "; rel=\"hub\", " + topic + "; rel=\"self\"";
}
