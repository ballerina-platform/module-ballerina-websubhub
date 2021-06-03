import ballerina/websub;
import ballerina/log;


@websub:SubscriberServiceConfig { 
    target: ["http://0.0.0.0:9090/hub", "test"],
    leaseSeconds: 36000,
    httpConfig: {
        auth: {
            username: "ballerina",
            issuer: "wso2",
            audience: ["ballerina", "ballerina.org", "ballerina.io"],
            keyId: "5a0b754-895f-4279-8843-b745e11a57e9",
            jwtId: "JlbmMiOiJBMTI4Q0JDLUhTMjU2In",
            customClaims: { "scp": "subscribe" },
            expTime: 3600,
            signatureConfig: {
                config: {
                    keyFile: "../resources/server.key"
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
