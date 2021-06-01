// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

# Represents a websubhub distinct error.
public type Error distinct error<CommonResponse>;

# Represents a websubhub service execution error.
public type ServiceExecutionError distinct Error;

# Error type representing the errors in the topic registration action.
public type TopicRegistrationError distinct Error;

# Error type representing the errors in the topic unregistration action.
public type TopicDeregistrationError distinct Error;

# Error type representing the errors in the subscription request.
public type BadSubscriptionError distinct Error;

# Error type representing the internal errors in the subscription action.
public type InternalSubscriptionError distinct Error;

# Error type representing the validation errors in the subscription request body.
public type SubscriptionDeniedError distinct Error;

# Error type representing the errors in the unsubscription request.
public type BadUnsubscriptionError distinct Error;

# Error type representing the internal errors in the unsubscription action.
public type InternalUnsubscriptionError distinct Error;

# Error type representing the validation errors in the unsubscription request body.
public type UnsubscriptionDeniedError distinct Error;

# Error type representing the errors in the content update request.
public type UpdateMessageError distinct Error;

# Error type representing the subscriber ending the subscription
# by sending `HTTP 410` for the content delivery response.
public type SubscriptionDeletedError distinct Error;

# Error type representing the internal errors in the content distribution.
public type ContentDeliveryError distinct Error;
