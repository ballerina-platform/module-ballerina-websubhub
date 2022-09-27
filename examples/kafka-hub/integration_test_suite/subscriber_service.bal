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

import ballerina/websub;

isolated boolean subscriptionSuccessful = false;
isolated boolean unsubscriptionSuccessful = false;
isolated int recievedNotificationCount = 0;

isolated function isSubscriptionSuccessful() returns boolean {
    lock {
        return subscriptionSuccessful;
    }
}

isolated function isUnsubscriptionSuccessful() returns boolean {
    lock {
        return unsubscriptionSuccessful;
    }
}

isolated function getReceivedNotificationCount() returns int {
    lock {
        return recievedNotificationCount;
    }
}

final websub:SubscriberService subscriberService = service object {
    remote function onSubscriptionValidationDenied(websub:SubscriptionDeniedError msg) {
        lock {
            if !subscriptionSuccessful {
                subscriptionSuccessful = true;
                return;
            }
        }
        lock {
            if !unsubscriptionSuccessful {
                unsubscriptionSuccessful = true;
                return;
            }
        }
    }

    remote function onSubscriptionVerification(websub:SubscriptionVerification msg) returns websub:SubscriptionVerificationSuccess {
        lock {
            subscriptionSuccessful = true;
        }
        return websub:SUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onUnsubscriptionVerification(websub:UnsubscriptionVerification msg) returns websub:UnsubscriptionVerificationSuccess {
        lock {
            unsubscriptionSuccessful = true;
        }
        return websub:UNSUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) {
        lock {
            recievedNotificationCount += 1;
        }
    }
};
