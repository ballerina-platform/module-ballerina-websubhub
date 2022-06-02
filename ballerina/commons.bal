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

const string HUB_MODE = "hub.mode";
const string HUB_TOPIC = "hub.topic";
const string HUB_CALLBACK = "hub.callback";
const string HUB_LEASE_SECONDS = "hub.lease_seconds";
const string HUB_SECRET = "hub.secret";
const string HUB_CHALLENGE = "hub.challenge";
const string HUB_REASON = "hub.reason";

const string MODE_ACCEPTED = "accepted";
const string MODE_DENIED = "denied";
const string MODE_PUBLISH = "publish";
const string MODE_REGISTER = "register";
const string MODE_DEREGISTER = "deregister";
const string MODE_SUBSCRIBE = "subscribe";
const string MODE_UNSUBSCRIBE = "unsubscribe";

const string CONTENT_PUBLISH = "publish";
const string EVENT_NOTIFY = "event";

const string CONTENT_TYPE = "Content-Type";
const string X_HUB_SIGNATURE = "X-Hub-Signature";
const string LINK = "Link";
const string BALLERINA_PUBLISH_HEADER = "x-ballerina-publisher";

const string SHA256_HMAC = "sha256";
const string HTTP_1_1 = "1.1";
const string HTTP_2_0 = "2.0";

const string REGISTER_TOPIC_ACTION = "register-topic";
const string DEREGISTER_TOPIC_ACTION = "deregister-topic";
const string CONTENT_PUBLISH_ACTION = "publish-content";
const string NOTIFY_UPDATE_ACTION = "notify-update";

const int LISTENER_INIT_ERROR = -1;
const int LISTENER_ATTACH_ERROR = -2;
const int LISTENER_START_ERROR = -3;
const int LISTENER_DETACH_ERROR = -4;
const int LISTENER_STOP_ERROR = -5;
const int CLIENT_INIT_ERROR = -10;

# Options to compress using Gzip or deflate.
#
# `AUTO`: When service behaves as a HTTP gateway inbound request/response accept-encoding option is set as the
#         outbound request/response accept-encoding/content-encoding option
# `ALWAYS`: Always set accept-encoding/content-encoding in outbound request/response
# `NEVER`: Never set accept-encoding/content-encoding header in outbound request/response
public type Compression COMPRESSION_AUTO|COMPRESSION_ALWAYS|COMPRESSION_NEVER;

# When service behaves as a HTTP gateway inbound request/response accept-encoding option is set as the
# outbound request/response accept-encoding/content-encoding option.
public const COMPRESSION_AUTO = "AUTO";

# Always set accept-encoding/content-encoding in outbound request/response.
public const COMPRESSION_ALWAYS = "ALWAYS";

# Never set accept-encoding/content-encoding header in outbound request/response.
public const COMPRESSION_NEVER = "NEVER";

# Response Status object, used to communicate status of the executed actions.
# 
# + code - Status code value
type Status distinct object {
    public int code;
};

# Response status OK.
# 
# + code - Status code for action
public readonly class StatusOK {
    *Status;
    public http:STATUS_OK code = http:STATUS_OK;
}

# Response status Temporary Redirect.
# 
# + code - Status code for action
public readonly class StatusTemporaryRedirect {
    *Status;
    public http:STATUS_TEMPORARY_REDIRECT code = http:STATUS_TEMPORARY_REDIRECT;
}

# Response status Permanent Redirect.
# + code - Status code for action
public readonly class StatusPermanentRedirect {
    *Status;
    public http:STATUS_PERMANENT_REDIRECT code = http:STATUS_PERMANENT_REDIRECT;
}

final StatusOK STATUS_OK_OBJ = new;

final StatusTemporaryRedirect STATUS_TEMPORARY_REDIRECT = new;

final StatusPermanentRedirect STATUS_PERMANENT_REDIRECT = new;

# Record to represent the parent type for all the response records.
# 
# + statusCode - HTTP status code for the response
# + mediaType - Content-Type of the request received
# + headers - Additional request headers received to be included in the request
# + body - Received request body
type CommonResponse record {|
    int statusCode;
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
    json|xml|string|byte[]? content;
|};

# Record to represent the successful WebSub content delivery.
# 
# + status - Status of the request processing. This is `200 OK` by default since
#            this is a successful response
public type ContentDistributionSuccess record {|
    *CommonResponse;
    readonly StatusOK status = STATUS_OK_OBJ;
|};

# Record to represent the topic-registration request body.
# 
# + topic - `Topic`, which should be registered in the `hub`
# + hubMode - Current `hub` action
public type TopicRegistration record {|
    string topic;
    string hubMode = MODE_REGISTER;
|};

# Record to represent the topic-deregistration request body.
# 
# + topic - `Topic`, which should be unregistered from the `hub`
# + hubMode - Current `hub` action
public type TopicDeregistration record {|
    string topic;
    string hubMode = MODE_DEREGISTER;
|};

# Record to represent the subscription request body.
# 
# + hub - URL of the `hub` to which the subscriber has subscribed
# + hubMode - Current `hub` action
# + hubCallback - Callback URL for subscriber to receive distributed content
# + hubTopic - Topic to which subscriber has subscribed
# + hubLeaseSeconds - Amount of time in seconds during when the subscription is valid
# + hubSecret - Secret Key to sign the distributed content
public type Subscription record {
    string hub;
    string hubMode;
    string hubCallback;
    string hubTopic;
    string? hubLeaseSeconds = ();
    string? hubSecret = ();
};

# Record to represent the completed subscription.
# 
# + verificationSuccess - Flag to notify whether a subscription verification is successfull
public type VerifiedSubscription record {
    *Subscription;
    boolean verificationSuccess = true;
};

# Record to represent the unsubscription request body.
# 
# + hubMode - Current `hub` action
# + hubCallback - Callback URL for subscriber to received distributed content
# + hubTopic - Topic from which subscriber wants to unsubscribe
# + hubSecret - Secret Key to sign the distributed content
public type Unsubscription record {
    string hubMode;
    string hubCallback;
    string hubTopic;
    string? hubSecret = ();
};

# Record to represent a completed unsubscription.
# 
# + verificationSuccess - Flag to notify whether a unsubscription verification is successfull
public type VerifiedUnsubscription record {
    *Unsubscription;
    boolean verificationSuccess = true;
};

# Enum to differentiate the type of the content-update message.
# 
# + EVENT - Content update in the `topic`
# + PUBLISH - Content distribution to the `topic`
public enum MessageType {
    EVENT,
    PUBLISH
}

# Record to represent the content update message.
# 
# + msgType - Type of the content update message
# + hubTopic - Topic of which the content should be updated
# + contentType - Content-Type of the update-message
# + content - Content to be distributed to subscribers
public type UpdateMessage record {
    MessageType msgType;
    string hubTopic;
    string contentType;
    string|byte[]|json|xml? content;
};

# Record to represent the successful topic registration.
public type TopicRegistrationSuccess record {
    *CommonResponse;
};

# Record to represent the successful topic deregistration.
public type TopicDeregistrationSuccess record {
    *CommonResponse;
};

# Record to represent the subscription accepted by the `hub`.
public type SubscriptionAccepted record {
    *CommonResponse;
};

# Common record to represent the subscription redirects.
# 
# + redirectUrls - URLs to which the subscription has been redirected
type SubscriptionRedirect record {
    *CommonResponse;
    string[] redirectUrls;
};

type Redirect SubscriptionPermanentRedirect|SubscriptionTemporaryRedirect;

# Record to represent the permanent subscription redirects.
# 
# + code - Status code for the action
public type SubscriptionPermanentRedirect record {
    *SubscriptionRedirect;
    readonly http:STATUS_PERMANENT_REDIRECT code = http:STATUS_PERMANENT_REDIRECT;
};

# Record to represent temporary subscription redirects.
# 
# + code - Status code of the action
public type SubscriptionTemporaryRedirect record {
    *SubscriptionRedirect;
    readonly http:STATUS_TEMPORARY_REDIRECT code = http:STATUS_TEMPORARY_REDIRECT;
};

# Record to represent the unsubscription acceptance.
public type UnsubscriptionAccepted record {
    *CommonResponse;
};

# Record to represent the acknowledgement of content updated by the publisher.
public type Acknowledgement record {
    *CommonResponse;
};

# Common response, which could be used for `websubhub:TopicRegistrationSuccess`.
public final readonly & TopicRegistrationSuccess TOPIC_REGISTRATION_SUCCESS = {
    statusCode: http:STATUS_OK
};

# Common response, which could be used for `websubhub:TopicRegistrationError`.
public final TopicRegistrationError TOPIC_REGISTRATION_ERROR = error TopicRegistrationError(
    "Topic registration failed", 
    statusCode = http:STATUS_OK
);

# Common response, which could be used for `websubhub:TopicDeregistrationSuccess`.
public final readonly & TopicDeregistrationSuccess TOPIC_DEREGISTRATION_SUCCESS = {
    statusCode: http:STATUS_OK
};

# Common response, which could be used for `websubhub:TopicDeregistrationError`.
public final TopicDeregistrationError TOPIC_DEREGISTRATION_ERROR = error TopicDeregistrationError(
    "Topic deregistration failed!", 
    statusCode = http:STATUS_OK
);

# Common response, which could be used for `websubhub:Acknowledgement`.
public final readonly & Acknowledgement ACKNOWLEDGEMENT = {
    statusCode: http:STATUS_OK
};

# Common response, which could be used for `websubhub:UpdateMessageError`.
public final UpdateMessageError UPDATE_MESSAGE_ERROR = error UpdateMessageError(
    "Error in accessing content", 
    statusCode = http:STATUS_BAD_REQUEST
);

# Common response, which could be used for `websubhub:SubscriptionAccepted`.
public final readonly & SubscriptionAccepted SUBSCRIPTION_ACCEPTED = {
    statusCode: http:STATUS_ACCEPTED
};

# Common response, which could be used for `websubhub:BadSubscriptionError`.
public final BadSubscriptionError BAD_SUBSCRIPTION_ERROR = error BadSubscriptionError(
    "Bad subscription request", 
    statusCode = http:STATUS_BAD_REQUEST
);

# Common response, which could be used for `websubhub:InternalSubscriptionError`.
public final InternalSubscriptionError INTERNAL_SUBSCRIPTION_ERROR = error InternalSubscriptionError(
    "Internal error occurred while processing subscription request", 
    statusCode = http:STATUS_INTERNAL_SERVER_ERROR
);

# Common response, which could be used for `websubhub:SubscriptionDeniedError`.
public final SubscriptionDeniedError SUBSCRIPTION_DENIED_ERROR = error SubscriptionDeniedError(
    "Subscription denied", 
    statusCode = http:STATUS_BAD_REQUEST
);

# Common response, which could be used for `websubhub:UnsubscriptionAccepted`.
public final readonly & UnsubscriptionAccepted UNSUBSCRIPTION_ACCEPTED = {
    statusCode: http:STATUS_ACCEPTED
};

# Common response, which could be used for `websubhub:BadUnsubscriptionError`.
public final BadUnsubscriptionError BAD_UNSUBSCRIPTION_ERROR = error BadUnsubscriptionError(
    "Bad unsubscription request", 
    statusCode = http:STATUS_BAD_REQUEST
);

# Common response, which could be used for `websubhub:InternalUnsubscriptionError`.
public final InternalUnsubscriptionError INTERNAL_UNSUBSCRIPTION_ERROR = error InternalUnsubscriptionError(
    "Internal error occurred while processing unsubscription request", 
    statusCode = http:STATUS_INTERNAL_SERVER_ERROR
);

# Common response, which could be used for `websubhub:UnsubscriptionDeniedError`.
public final UnsubscriptionDeniedError UNSUBSCRIPTION_DENIED_ERROR = error UnsubscriptionDeniedError(
    "Unsubscription denied", 
    statusCode = http:STATUS_BAD_REQUEST
);

# Record to represent the client configuration for the HubClient/PublisherClient.
# 
# + httpVersion - The HTTP version understood by the client
# + http1Settings - Configurations related to HTTP/1.x protocol
# + http2Settings - Configurations related to HTTP/2 protocol
# + timeout - The maximum time to wait (in seconds) for a response before closing the connection
# + poolConfig - Configurations associated with request pooling
# + auth - Configurations related to client authentication
# + retryConfig - Configurations associated with retrying
# + responseLimits - Configurations associated with inbound response size limits
# + secureSocket - SSL/TLS related options
# + circuitBreaker - Configurations associated with the behaviour of the Circuit Breaker
public type ClientConfiguration record {|
    string httpVersion = HTTP_1_1;
    http:ClientHttp1Settings http1Settings = {};
    http:ClientHttp2Settings http2Settings = {};
    decimal timeout = 60;
    http:PoolConfiguration poolConfig?;
    http:ClientAuthConfig auth?;
    http:RetryConfig retryConfig?;
    http:ResponseLimitConfigs responseLimits = {};
    http:ClientSecureSocket secureSocket?;
    http:CircuitBreakerConfig circuitBreaker?;
|};

# Provides a set of configurations for configure the underlying HTTP listener of the WebSubHub listener.
public type ListenerConfiguration record {|
    *http:ListenerConfiguration;
|};

isolated function isSuccessStatusCode(int statusCode) returns boolean {
    return (200 <= statusCode && statusCode < 300);
}

isolated function generateLinkUrl(string hubUrl, string topic) returns string {
    return string `${hubUrl}; rel=\"hub\", ${topic}; rel=\"self\"`;
}

isolated function retrieveHttpClientConfig(ClientConfiguration config) returns http:ClientConfiguration {
    return {
        httpVersion: config.httpVersion,
        http1Settings: config.http1Settings,
        http2Settings: config.http2Settings,
        timeout: config.timeout,
        poolConfig: config?.poolConfig,
        auth: config?.auth,
        retryConfig: config?.retryConfig,
        responseLimits: config.responseLimits,
        secureSocket: config?.secureSocket,
        circuitBreaker: config?.circuitBreaker
    };
}
