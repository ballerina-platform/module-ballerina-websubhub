import ballerinax/kafka;
import ballerina/jballerina.java;
import ballerina/jwt;

const string TOPIC_PREFIX = "topic_";
const string GROUP_PREFIX = "consumer_group_";

isolated function generateTopicName(string topic) returns string {
    return TOPIC_PREFIX + getStringHash(topic).toString();
}

isolated function generateGroupId(string topic, string callbackUrl) returns string {
    string idValue = topic + ":" + callbackUrl;
    return GROUP_PREFIX + getStringHash(idValue).toString();
}

isolated function getStringHash(string value) returns int {
    int hashCount = 0;
    int index = 0;
    while (index < value.length()) {
        hashCount += value.getCodePoint(index);
        index += 1;
    }
    return hashCount;
}

function getConsumer(string[] topics, string consumerGroupId, boolean autoCommit = true) returns kafka:Consumer|error {
    kafka:ConsumerConfiguration consumerConfiguration = {
        groupId: consumerGroupId,
        offsetReset: "latest",
        topics: topics,
        autoCommit: autoCommit
    };

    return check new ("localhost:9092", consumerConfiguration);
}

isolated function validateJwt(jwt:Payload authDetails, string[] validScopes) returns boolean {
    var currentTime = getCurrentDate();
    int currentTimeInMillis = getTimeInMillies(currentTime);
    int? expiryTime = authDetails?.exp;
    if (expiryTime is int && expiryTime > (currentTimeInMillis / 1000)) {
        if (validScopes.length() > 0) {
            var availableScope = authDetails["scope"];
            if (availableScope is string) {
                foreach var scope in validScopes {
                    if (scope == availableScope) {
                        return true;
                    } 
                }
            } else {
                return false;
            }
        } else {
            return true;
        }
    }
    return false;
}

isolated function getCurrentDate() returns handle = @java:Constructor {
    'class: "java.util.Date"
} external;

isolated function getTimeInMillies(handle currentDate) returns int = @java:Method {
    name: "getTime",
    'class: "java.util.Date"
} external;
