import ballerina/websub;
import ballerina/log;


@websub:SubscriberServiceConfig { 
    target: ["http://0.0.0.0:9090/hub", "test"],
    leaseSeconds: 36000,
    httpConfig: {
        auth : {
            tokenUrl: "https://localhost:9443/oauth2/token",
            clientId: "8EsaVTsN64t4sMDhGvBqJoqMi8Ea",
            clientSecret: "QC71AIfbBjhgAibpi0mpfIEK_bMa",
            scopes: ["subscribe"],
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: "../resources/client-truststore.jks",
                        password: "wso2carbon"
                    }
                }
            }
        }
    }
} 
service /subscriber on new websub:Listener(9091) {
    remote function onSubscriptionValidationDenied(websub:SubscriptionDeniedError msg) returns websub:Acknowledgement? {
        log:printInfo("onSubscriptionValidationDenied invoked");
        return {};
    }

    remote function onSubscriptionVerification(websub:SubscriptionVerification msg) returns websub:SubscriptionVerificationSuccess {
        log:printInfo("onSubscriptionVerification invoked");
        return {};
      }

    remote function onEventNotification(websub:ContentDistributionMessage event) 
                        returns websub:Acknowledgement|websub:SubscriptionDeletedError? {
        log:printInfo("onEventNotification invoked ", contentDistributionMessage = event);
        return {};
    }
}
