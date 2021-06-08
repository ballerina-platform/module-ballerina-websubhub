configurable boolean SECURITY_ON = ?;
configurable string SERVER_ID = ?;
configurable string REGISTERED_TOPICS = "registered-topics";
configurable string REGISTERED_CONSUMERS = "registered-consumers";
final string constructedServerId = string`${SERVER_ID}-${generateRandomString()}`;