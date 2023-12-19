import ballerina/websub;
import ballerina/log;
import ballerina/http;
import ballerina/websubhub;

type OAuth2Config record {|
    string tokenUrl;
    string clientId;
    string clientSecret;
    string trustStore;
    string trustStorePassword;
|};
configurable OAuth2Config oauth2Config = ?;

listener websub:Listener securedSubscriber = new(9100,
    host = "localhost",
    secureSocket = {
        key: {
            certFile: "./resources/server.crt",
            keyFile: "./resources/server.key"
        }
    }
);

function init() returns error? {
    websubhub:PublisherClient websubHubClientEP = check new("https://localhost:9090/hub",
        auth = {
            tokenUrl: oauth2Config.tokenUrl,
            clientId: oauth2Config.clientId,
            clientSecret: oauth2Config.clientSecret,
            scopes: ["register_topic"],
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
    websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError response = websubHubClientEP->registerTopic("priceUpdate");
    if response is websubhub:TopicRegistrationError {
        int statusCode = response.detail().statusCode;
        if http:STATUS_CONFLICT != statusCode {
            return response;
        }
    }
}

@websub:SubscriberServiceConfig { 
    target: ["https://localhost:9090/hub", "priceUpdate"],
    httpConfig: {
        auth : {
            tokenUrl: oauth2Config.tokenUrl,
            clientId: oauth2Config.clientId,
            clientSecret: oauth2Config.clientSecret,
            scopes: ["subscribe"],
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: oauth2Config.trustStore,
                        password: oauth2Config.trustStorePassword
                    }
                }
            }
        },
        secureSocket : {
            cert: "./resources/server.crt"
        }
    },
    unsubscribeOnShutdown: true
} 
service /JuApTOXq19 on securedSubscriber {
    
    remote function onSubscriptionVerification(websub:SubscriptionVerification msg) 
        returns websub:SubscriptionVerificationSuccess {
        log:printInfo(string `Successfully subscribed for notifications on topic [priceUpdate]`);
        return websub:SUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) returns error? {
        json notification = check event.content.ensureType();
        log:printInfo("Received notification", content = notification);
    }
}
