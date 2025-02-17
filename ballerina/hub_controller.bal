// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

public isolated class Controller {
    private final boolean autoVerifySubscription;

    private final map<Subscription|Unsubscription> autoVerifyState = {};

    isolated function init(boolean autoVerifySubscription) {
        self.autoVerifySubscription = autoVerifySubscription;
    }

    public isolated function markAsVerified(Subscription|Unsubscription subscription) returns Error? {
        if !self.autoVerifySubscription {
            return error Error(
                "Trying mark a subcription as auto-verifiable, but the `hub` has not enabled subscription auto-verification", 
                statusCode = SUB_AUTO_VERIFY_ERROR);
        }

        string 'key = constructSubscriptionKey(subscription);
        lock {
            self.autoVerifyState['key] = subscription.cloneReadOnly();
        }
    }

    isolated function skipSubscriptionVerification(Subscription|Unsubscription subscription) returns boolean {
        string 'key = constructSubscriptionKey(subscription);
        Subscription|Unsubscription? skipped;
        lock {
            skipped = self.autoVerifyState.removeIfHasKey('key).cloneReadOnly();
        }
        return skipped !is ();
    }
}

isolated function constructSubscriptionKey(record {} message) returns string {
    string[] values = message.toArray().'map(v => string `${v.toString()}`);
    return string:'join(":::", ...values);
}
