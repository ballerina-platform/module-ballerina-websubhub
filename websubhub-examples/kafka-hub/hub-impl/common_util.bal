import ballerina/regex;

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

# Switch to start/stop subscriber notification. 
isolated class Switch {
    private boolean switch;

    # Initiliazes `kafka_hub_service:Switch` instance.
    # ```ballerina
    # kafka_hub_service:Switch switch = new ();
    # ```
    #
    # + switch - Flag to indicate whether switch is on/off
    # + return - The `kafka_hub_service:Switch` or an `error` if the initialization failed
    isolated function init(boolean switch = true) {
        self.switch = switch;
    }

    # Retrieves whether switch is open or not.
    # ```ballerina
    # boolean isOpen = switch.isOpen();
    # ```
    # 
    # + return - An `true`, if switch is open or else `false`
    isolated function isOpen() returns boolean {
        lock {
            return self.switch;
        }
    }

    # Updates the switch state to `close`.
    # ```ballerina
    # switch.close();
    # ```
    isolated function close() {
        lock {
            self.switch = false;
        }
    }
}
