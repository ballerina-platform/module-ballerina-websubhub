import ballerina/websub;

final websub:SubscriberService subscriberService = service object {
    remote function onSubscriptionValidationDenied(websub:SubscriptionDeniedError msg) {

    }

    remote function onSubscriptionVerification(websub:SubscriptionVerification msg) returns websub:SubscriptionVerificationSuccess {
        return websub:SUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onUnsubscriptionVerification(websub:UnsubscriptionVerification msg) returns websub:UnsubscriptionVerificationSuccess {
        return websub:UNSUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) {

    }
};
