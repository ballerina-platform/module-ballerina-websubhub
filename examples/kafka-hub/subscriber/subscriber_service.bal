// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/websub;
import ballerina/log;

listener websub:Listener securedSubscriber = new(9091,
    host = "localhost",
    secureSocket = {
        key: {
            certFile: "../_resources/server.crt",
            keyFile: "../_resources/server.key"
        }
    }
);

@websub:SubscriberServiceConfig { 
    target: ["https://localhost:9090/hub", "test"],
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
                        path: "../_resources/client-truststore.jks",
                        password: "wso2carbon"
                    }
                }
            }
        },
        secureSocket : {
            cert: "../_resources/server.crt"
        }
    }
} 
service on securedSubscriber {
    remote function onSubscriptionValidationDenied(websub:SubscriptionDeniedError msg) returns websub:Acknowledgement? {
        log:printInfo("onSubscriptionValidationDenied invoked", 'error = msg);
        return websub:ACKNOWLEDGEMENT;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) returns websub:Acknowledgement{
        log:printInfo("onEventNotification invoked ", contentDistributionMessage = event);
        return websub:ACKNOWLEDGEMENT;
    }
}
