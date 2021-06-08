import ballerina/log;
import ballerina/http;
import ballerina/jwt;

final http:ListenerJwtAuthHandler handler = new({
    issuer: "https://localhost:9443/oauth2/token",
    audience: "ballerina",
    signatureConfig: {
        jwksConfig: {
            url: "https://localhost:9443/oauth2/jwks",
            clientConfig: {
                secureSocket: {
                    cert: {
                        path: "./resources/client-truststore.jks",
                        password: "wso2carbon"
                    }
                }
            }
        }
    },
    scopeKey: "scope"
});

isolated function authorize(http:Headers headers, string[] authScopes) returns error? {
    string|http:HeaderNotFoundError authHeader = headers.getHeader(http:AUTH_HEADER);
    if (authHeader is string) {
        jwt:Payload|http:Unauthorized auth = handler.authenticate(authHeader);
        if (auth is jwt:Payload) {
            http:Forbidden? forbiddenError = handler.authorize(auth, authScopes);
            if (forbiddenError is http:Forbidden) {
                log:printError("Forbidden Error received - Authentication credentials invalid");
                return error("Not authorized");
            }
        } else {
            log:printError("Unauthorized Error received - Authentication credentials invalid");
            return error("Not authorized");
        }
    } else {
        log:printError("Authorization header not found");
        return error("Not authorized");
    }
}
