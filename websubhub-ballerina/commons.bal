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

# Parameter `hub.callback` represents the callback URL for subscriber to receive distributed contents
const string HUB_CALLBACK = "hub.callback";

# Parameter `hub.lease_seconds` represents the lease time in seconds until which the subscription is valid
const string HUB_LEASE_SECONDS = "hub.lease_seconds";

# Parameter `hub.secret` represents the secret-key which `hub` should use to sign the content
# in content distribution
const string HUB_SECRET = "hub.secret";

# Parameter `hub.challenge` represents a hub-generated, random string that MUST be echoed by the subscriber to verify the subscription
const string HUB_CHALLENGE = "hub.challenge";

# `hub.mode` value indicating "publish" mode, used by a publisher to notify an update to a topic.
const string MODE_PUBLISH = "publish";

# `hub.mode` value indicating "register" mode, used by a publisher to register a topic at a hub.
const string MODE_REGISTER = "register";

# `hub.mode` value indicating "deregister" mode, used by a publisher to deregister a topic at a hub.
const string MODE_DEREGISTER = "deregister";

# `hub.mode` value indicating "subscribe" mode, used by a subscriber to subscribe a topic at a hub.
const string MODE_SUBSCRIBE = "subscribe";

# `hub.mode` value indicating "unsubscribe" mode, used by a subscriber to unsubscribe a topic at a hub.
const string MODE_UNSUBSCRIBE = "unsubscribe";

# `HTTP Content-Type` Header Name, used to include `Content-Type` header value manually to `HTTP Request`.
const string CONTENT_TYPE = "Content-Type";

# `HTTP X-Hub-Signature` Header Name, used to include `X-Hub-Signature` header value manually to `HTTP Request`,
#  value of this `HTTP Header` is used by subscriber to verify whether the content is published by a valid hub.
const string X_HUB_SIGNATURE = "X-Hub-Signature";

# `HTTP Link` Header Name, used to include `Link` header value manually to `HTTP Request`.
const string LINK = "Link";

const string BALLERINA_PUBLISH_HEADER = "x-ballerina-publisher";

# `SHA256 HMAC` algorithm name, this is prepended to the generated signature value.
const string SHA256_HMAC = "sha256";

# Represents HTTP/1.1 protocol
const string HTTP_1_1 = "1.1";

# Represents HTTP/2.0 protocol
const string HTTP_2_0 = "2.0";

# Options to compress using gzip or deflate.
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
# + code - status code value
type Status distinct object {
    public int code;
};

# Response status OK
# + code - Status code for action
public readonly class StatusOK {
    *Status;
    public http:STATUS_OK code = http:STATUS_OK;
}

# Response status Temporary Redirect
# + code - Status code for action
public readonly class StatusTemporaryRedirect {
    *Status;
    public http:STATUS_TEMPORARY_REDIRECT code = http:STATUS_TEMPORARY_REDIRECT;
}

# Response status Permanent Redirect
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
# + mediaType - Content-Type of the request received
# + headers - Additional request headers received to be included in the request
# + body - Received request body
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
    map<string>|json|xml|string|byte[] content;
|};

# Record to represent the successful WebSub content delivery
# 
# + status - Status of the request processing , this is `200 OK` by default since
# this is a success reponse
public type ContentDistributionSuccess record {|
    *CommonResponse;
    readonly StatusOK status = STATUS_OK_OBJ;
|};

# Record to represent Topic-Registration request body
# 
# + topic - `Topic` which should be registered in the `hub`
public type TopicRegistration record {|
    string topic;
|};

# Record to represent Topic-Deregistration request body
# 
# + topic - `Topic` which should be unregistered from the `hub`
public type TopicDeregistration record {|
    string topic;
|};

// todo Any other params set in the payload(subscribers)
//todo: update this accordingly [ayesh]
# Record to represent subscription request body
# 
# + hub - URL of the `hub` where subscriber has subscribed
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

# Record to represent completed subscription
# 
# + verificationSuccess - true / false based on subscription is successfully completed or not
public type VerifiedSubscription record {
    *Subscription;
    boolean verificationSuccess;
};

# Record to represent the unsubscription request body
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

# Record to represent completed unsubscription
# 
# + verificationSuccess - true / false based on unsubscription is successfully completed or not
public type VerifiedUnsubscription record {
    *Unsubscription;
    boolean verificationSuccess;
};

//todo: update this accordingly [ayesh]
# Enum to differenciate the type of content-update message
# 
# + EVENT - 
# + PUBLISH -
public enum MessageType {
    EVENT,
    PUBLISH
}

# Record to represent content-update message
# 
# + msgType - Type of the content update message
# + hubTopic - Topic to which the content should be updated
# + contentType - Content-Type of the update-message
# + content - Content to be distributed to subscribers
public type UpdateMessage record {
    MessageType msgType;
    string hubTopic;
    string contentType;
    string|byte[]|json|xml|map<string>? content;
};

# Record to represent Topic Registration success
public type TopicRegistrationSuccess record {
    *CommonResponse;
};

# Record to represent Topic Deregistration Success
public type TopicDeregistrationSuccess record {
    *CommonResponse;
};

# Record to represent accepted subscription by the `hub`
public type SubscriptionAccepted record {
    *CommonResponse;
};

# Common Record to represent subscription redirects
# 
# + redirectUrls - URLs to which subscription has redirected
type SubscriptionRedirect record {
    *CommonResponse;
    string[] redirectUrls;
};

# Record to represent permanent subscription redirects
# 
# + code - Status code for action
public type SubscriptionPermanentRedirect record {
    *SubscriptionRedirect;
    readonly http:STATUS_PERMANENT_REDIRECT code = http:STATUS_PERMANENT_REDIRECT;
};

# Record to represent temporary subscription redirects
# 
# + code - Status code of the action
public type SubscriptionTemporaryRedirect record {
    *SubscriptionRedirect;
    readonly http:STATUS_TEMPORARY_REDIRECT code = http:STATUS_TEMPORARY_REDIRECT;
};

# Record to represent unsubscription acceptance
public type UnsubscriptionAccepted record {
    *CommonResponse;
};

# Record to represent acknowledgement of content updated by the publisher
public type Acknowledgement record {
    *CommonResponse;
};

# Common Responses to be used in hub-implementation
public final readonly & TopicRegistrationSuccess TOPIC_REGISTRATION_SUCCESS = {};
public final TopicRegistrationError TOPIC_REGISTRATION_ERROR = error TopicRegistrationError("Topic registration failed");
public final readonly & TopicDeregistrationSuccess TOPIC_DEREGISTRATION_SUCCESS = {};
public final TopicDeregistrationError TOPIC_DEREGISTRATION_ERROR = error TopicDeregistrationError("Topic deregistration failed!");
public final readonly & Acknowledgement ACKNOWLEDGEMENT = {};
public final UpdateMessageError UPDATE_MESSAGE_ERROR = error UpdateMessageError("Error in accessing content");
public final readonly & SubscriptionAccepted SUBSCRIPTION_ACCEPTED = {};
public final BadSubscriptionError BAD_SUBSCRIPTION_ERROR = error BadSubscriptionError("Bad subscription request");
public final InternalSubscriptionError INTERNAL_SUBSCRIPTION_ERROR = error InternalSubscriptionError("Internal error occurred while processing subscription request");
public final SubscriptionDeniedError SUBSCRIPTION_DENIED_ERROR = error SubscriptionDeniedError("Subscription denied");
public final readonly & UnsubscriptionAccepted UNSUBSCRIPTION_ACCEPTED = {};
public final BadUnsubscriptionError BAD_UNSUBSCRIPTION_ERROR = error BadUnsubscriptionError("Bad unsubscription request");
public final InternalUnsubscriptionError INTERNAL_UNSUBSCRIPTION_ERROR = error InternalUnsubscriptionError("Internal error occurred while processing unsubscription request");
public final UnsubscriptionDeniedError UNSUBSCRIPTION_DENIED_ERROR = error UnsubscriptionDeniedError("Unsubscription denied");

# Record to represent client configuration for HubClient / PublisherClient
# 
# + httpVersion - The HTTP version understood by the client
# + http1Settings - Configurations related to HTTP/1.x protocol
# + http2Settings - Configurations related to HTTP/2 protocol
# + timeout - The maximum time to wait (in seconds) for a response before closing the connection
# + poolConfig - Configurations associated with request pooling
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
    http:RetryConfig retryConfig?;
    http:ResponseLimitConfigs responseLimits = {};
    http:ClientSecureSocket secureSocket?;
    http:CircuitBreakerConfig circuitBreaker?;
|};

# Provides a set of configurations for configure the underlying HTTP listener of the WebSubHub listener.
public type ListenerConfiguration record {|
    *http:ListenerConfiguration;
|};

# Checks whether `HTTP Response` is a success response
# ```ballerina
#       boolean isSuccess = websubhub:isSuccessStatusCode(300);
# ```
# 
# + statusCode - `HTTP Status Code` of current response
# + return - a `boolean` if the `statusCode` is in `2XX` range
isolated function isSuccessStatusCode(int statusCode) returns boolean {
    return (200 <= statusCode && statusCode < 300);
}

# Generates the `HTTP Link Header` for content-distribution request
# ```ballerina
#       string linkHeaderValue = websubhub:generateLinkUrl("https://sample.hub.com", "https://sample.topic.com");
# ```
# 
# + hubUrl - URL for the current `hub`
# + topic - Name of the `topic`
# + return - a `string` containing the value for `HTTP Link Header`
isolated function generateLinkUrl(string hubUrl, string topic) returns string {
    return string`${hubUrl}; rel=\"hub\", ${topic}; rel=\"self\"`;
}

# Converts {@code websubhub:ClientConfiguration} to {@code http:ClientConfiguration}
# 
# + config - provided {@code websubhub:ClientConfiguration}
# + return - a {@code http:ClientConfiguration} from the provided {@code websubhub:ClientConfiguration}
isolated function retrieveHttpClientConfig(ClientConfiguration config) returns http:ClientConfiguration {
    return {
        httpVersion: config.httpVersion,
        http1Settings: config.http1Settings,
        http2Settings: config.http2Settings,
        timeout: config.timeout,
        poolConfig: config?.poolConfig,
        retryConfig: config?.retryConfig,
        responseLimits: config.responseLimits,
        secureSocket: config?.secureSocket,
        circuitBreaker: config?.circuitBreaker
    };
}
