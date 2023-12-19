import ballerina/websubhub;
import ballerina/io;

type OAuth2Config record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
    string trustStore;
    string trustStorePassword;
|};
configurable OAuth2Config oauth2Config = ?;

public function main() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new("https://localhost:9090/hub",
        auth = {
            tokenUrl: oauth2Config.tokenUrl,
            clientId: oauth2Config.clientId,
            clientSecret: oauth2Config.clientSecret,
            scopes: ["register_topic", "update_content"],
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: oauth2Config.trustStore,
                        password: oauth2Config.trustStorePassword
                    }
                }
            }
        },
        secureSocket = {
            cert: "./resources/server.crt"
        }
    );
    json params = {
        itemName: string `Panasonic 32" LED TV`,
        itemCode: "ITM30029",
        previousPrice: 32999.00,
        newPrice: 28999.00,
        currencyCode: "SEK"
    };
    websubhub:Acknowledgement response = check websubHubClientEP->publishUpdate("priceUpdate", params);
    io:println("Receieved content-publish result: ", response);
}
