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

import ballerina/http;
import ballerina/log;

# Represents a Service listener endpoint.
public class Listener {
    private final int defaultHubLeaseSeconds = 864000;
    private http:Listener httpListener;
    private http:ListenerConfiguration listenerConfig;
    private int port;
    private HttpService? httpService;

    # Initiliazes the `websubhub:Listener` instance.
    # ```ballerina
    # listener websubhub:Listener hubListenerEp = check new (9090);
    # ```
    #
    # + listenTo - Port number or an `http:Listener` instance
    # + config - Custom `websubhub:ListenerConfiguration` to be provided to the underlying HTTP listener
    # + return - The `websubhub:Listener` or an `error` if the initialization failed
    public isolated function init(int|http:Listener listenTo, *ListenerConfiguration config) returns error? {
        if listenTo is int {
            self.httpListener = check new(listenTo, config);
        } else {
            self.httpListener = listenTo;
        }

        self.listenerConfig = self.httpListener.getConfig();
        self.port = self.httpListener.getPort();
        self.httpService = ();
    }

    # Attaches the provided `websubhub:Service` to the `websubhub:Listener`.
    # ```ballerina
    # check hubListenerEp.attach('service, "/hub");
    # ```
    # 
    # + 'service - The `websubhub:Service` object to attach
    # + name - The path of the service to be hosted
    # + return - An `error` if an error occurred during the service attaching process or else `()`
    public isolated function attach(Service 'service, string[]|string? name = ()) returns error? {
        if self.listenerConfig.secureSocket is () {
            log:printWarn("HTTPS is recommended but using HTTP");
        }

        string hubUrl = self.retrieveHubUrl(name);
        ServiceConfiguration? configuration = retrieveServiceAnnotations('service);
        HttpToWebsubhubAdaptor adaptor = check new ('service);
        if configuration is ServiceConfiguration {
            int leaseSeconds = configuration?.leaseSeconds is int ? <int>(configuration?.leaseSeconds) : self.defaultHubLeaseSeconds;
            if configuration?.webHookConfig is ClientConfiguration {
                self.httpService = new(adaptor, hubUrl, leaseSeconds, <ClientConfiguration>(configuration?.webHookConfig));
            } else {
                self.httpService = new(adaptor, hubUrl, leaseSeconds);
            }
        } else {
            self.httpService = new(adaptor, hubUrl, self.defaultHubLeaseSeconds);
        }
        check self.httpListener.attach(<HttpService> self.httpService, name);
    }

    # Retrieves the URL on which the `hub` is published.
    # ```ballerina
    # string hubUrl = retrieveHubUrl("/hub");
    # ```
    #
    # + servicePath - Current service path
    # + return - Callback URL, which should be used in the subscription request
    isolated function retrieveHubUrl(string[]|string? servicePath) returns string {
        string host = self.listenerConfig.host;
        string protocol = self.listenerConfig.secureSocket is () ? "http" : "https";
        
        string concatenatedServicePath = "";
        
        if servicePath is string {
            concatenatedServicePath += "/" + <string>servicePath;
        } else if servicePath is string[] {
            foreach var pathSegment in <string[]>servicePath {
                concatenatedServicePath += "/" + pathSegment;
            }
        }

        return protocol + "://" + host + ":" + self.port.toString() + concatenatedServicePath;
    }

    # Detaches the provided `websubhub:Service` from the `websubhub:Listener`.
    # ```ballerina
    # check hubListenerEp.detach('service);
    # ```
    # 
    # + s - The `websubhub:Service` object to be detached
    # + return - An `error` if an error occurred during the service detaching process or else `()`
    public isolated function detach(Service s) returns error? {
        check self.httpListener.detach(<HttpService> self.httpService);
    }

    # Starts the registered service programmatically.
    # ```ballerina
    # check hubListenerEp.'start();
    # ```
    # 
    # + return - An `error` if an error occurred during the listener-starting process or else `()`
    public isolated function 'start() returns error? {
        check self.httpListener.'start();
    }

    # Gracefully stops the hub listener. Already-accepted requests will be served before the connection closure.
    # ```ballerina
    # check hubListenerEp.gracefulStop();
    # ```
    # 
    # + return - An `error` if an error occurred during the listener-stopping process
    public isolated function gracefulStop() returns error? {
        return self.httpListener.gracefulStop();
    }

    # Stops the service listener immediately. It is not implemented yet.
    # ```ballerina
    # check hubListenerEp.immediateStop();
    # ```
    # 
    # + return - An `error` if an error occurred during the listener-stopping process or else `()`
    public isolated function immediateStop() returns error? {
        return self.httpListener.immediateStop();
    }
}

# Retrieves the `websubhub:ServiceConfiguration` annotation values.
# ```ballerina
# websubhub:ServiceConfiguration? config = retrieveServiceAnnotations('service);
# ```
# 
# + serviceType - Current `websubhub:Service` object
# + return - Provided `websubhub:ServiceConfiguration` or else `()`
isolated function retrieveServiceAnnotations(Service serviceType) returns ServiceConfiguration? {
    typedesc<any> serviceTypedesc = typeof serviceType;
    return serviceTypedesc.@ServiceConfig;
}
