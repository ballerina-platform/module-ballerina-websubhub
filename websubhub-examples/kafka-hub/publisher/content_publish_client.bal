import ballerina/websubhub;
import ballerina/io;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new("http://localhost:9090/hub",
        auth = {
            username: "ballerina",
            issuer: "wso2",
            audience: ["ballerina", "ballerina.org", "ballerina.io"],
            keyId: "5a0b754-895f-4279-8843-b745e11a57e9",
            jwtId: "JlbmMiOiJBMTI4Q0JDLUhTMjU2In",
            customClaims: { "scp": "update_content" },
            expTime: 3600,
            signatureConfig: {
                config: {
                    keyFile: "../resources/server.key"
                }
            }
        }
    );
    json params = { event: "event"};
    var response = websubHubClientEP->publishUpdate("test", params);
    io:println("Receieved content-publish result : ", response);
}