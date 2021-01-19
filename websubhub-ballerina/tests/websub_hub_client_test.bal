import ballerina/io;
import ballerina/test;

service /sub on new http:Listener(9192) {
    resource function post callback(http:Caller caller, http:Request req)
            returns error? {
        io:println("Published content received : ", req.getTextPayload());
        http:Response res = new;
        res.statusCode = 200;
        res.setPayload("Received Content");
        check caller->respond(res);
    }
}

@test:Config{}
public function testContentPublishToSubscribers() {
    HubClient webSubHubClientEP = checkpanic new ("http://localhost:9192/sub/callback", "http://localhost:9191/hub", "http://websubpubtopic.com");
    var contentDistributionMsg = {
        secret: "seckey1",
        content: "This is a test content."
    };
    webSubHubClientEP->notifyContentDistribution(contentDistributionMsg);
}