import ballerina/websubhub;
import ballerinax/kafka;

type ConsolidatedTopicsConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    websubhub:TopicRegistration[] value;
|};

type ConsolidatedSubscribersConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    websubhub:VerifiedSubscription[] value;
|};

type UpdateMessageConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    json value;
|};
