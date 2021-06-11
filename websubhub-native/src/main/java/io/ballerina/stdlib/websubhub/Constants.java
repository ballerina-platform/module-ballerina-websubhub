package io.ballerina.stdlib.websubhub;

public interface Constants {
    String PACKAGE_ORG = "ballerina";
    String PACKAGE_NAME = "websubhub";

    String TOPIC_REGISTRATION_ERROR = "TopicRegistrationError";
    String TOPIC_DEREGISTRATION_ERROR = "TopicDeregistrationError";
    String UPDATE_MESSAGE_ERROR = "UpdateMessageError";
    String BAD_SUBSCRIPTION_ERROR = "BadSubscriptionError";
    String SUBSCRIPTION_INTERNAL_ERROR = "InternalSubscriptionError";
    String SUBSCRIPTION_DENIED_ERROR = "SubscriptionDeniedError";
    String UNSUBSCRIPTION_INTERNAL_ERROR = "InternalUnsubscriptionError";
    String UNSUBSCRIPTION_DENIED_ERROR = "UnsubscriptionDeniedError";
}
