import ballerina/websubhub;
import ballerina/io;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new("http://localhost:9090/hub",
        auth = {
            tokenUrl: "https://localhost:9443/oauth2/token",
            clientId: "8EsaVTsN64t4sMDhGvBqJoqMi8Ea",
            clientSecret: "QC71AIfbBjhgAibpi0mpfIEK_bMa",
            scopes: ["register_topic"],
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: "../resources/client-truststore.jks",
                        password: "wso2carbon"
                    }
                }
            }
        }
    );
    var registrationResponse = websubHubClientEP->registerTopic("test");
    io:println("Receieved topic registration result : ", registrationResponse);
}
