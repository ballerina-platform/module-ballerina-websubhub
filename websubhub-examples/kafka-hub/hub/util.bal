import ballerina/regex;
import ballerina/random;
import ballerina/lang.'string as strings;

isolated function generateTopicName(string topic) returns string {
    return nomalizeString(topic);
}

isolated function generateGroupName(string topic, string callbackUrl) returns string {
    string idValue = topic + ":::" + callbackUrl;
    return nomalizeString(idValue);
}

isolated function nomalizeString(string baseString) returns string {
    return regex:replaceAll(baseString, "[^a-zA-Z0-9]", "_");
}

isolated function generateRandomString() returns string {
    int[] codePoints = [];
    int leftLimit = 48; // numeral '0'
    int rightLimit = 122; // letter 'z'
    int iterator = 0;
    while iterator < 10 {
        int|error randomInt = random:createIntInRange(leftLimit, rightLimit);
        if randomInt is error {
            break;
        } else {
            // character literals from 48 - 57 are numbers | 65 - 90 are capital letters | 97 - 122 are simple letters
            if (randomInt <= 57 || randomInt >= 65) && (randomInt <= 90 || randomInt >= 97) {
                codePoints.push(randomInt);
                iterator += 1;
            }
        }
    }
    string|error generatedValue = strings:fromCodePointInts(codePoints);
    return generatedValue is string ? generatedValue : "";
}
