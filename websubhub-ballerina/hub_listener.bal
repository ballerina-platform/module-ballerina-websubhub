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
    # + return - The `websubhub:Listener` or an `websubhub:Error` if the initialization failed
    public isolated function init(int|http:Listener listenTo, *ListenerConfiguration config) returns Error? {
        if listenTo is int {
            http:Listener|error httpListener = new(listenTo, config);
            if httpListener is http:Listener {
                self.httpListener = httpListener;
            } else {
                return error Error("Listener initialization failed", httpListener);
            }
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
    # + return - An `websubhub:Error` if an error occurred during the service attaching process or else `()`
    public isolated function attach(Service 'service, string[]|string? name = ()) returns Error? {
        if self.listenerConfig.secureSocket is () {
            log:printWarn("HTTPS is recommended but using HTTP");
        }

        string hubUrl = self.retrieveHubUrl(name);
        ServiceConfiguration? configuration = retrieveServiceAnnotations('service);
        HttpToWebsubhubAdaptor adaptor = new('service);
        if configuration is ServiceConfiguration {
            int leaseSeconds = configuration?.leaseSeconds is int ? <int>(configuration?.leaseSeconds) : self.defaultHubLeaseSeconds;
            ClientConfiguration? webhookConfig = configuration?.webHookConfig; 
            if webhookConfig is ClientConfiguration {
                self.httpService = new(adaptor, hubUrl, leaseSeconds, webhookConfig);
            } else {
                self.httpService = new(adaptor, hubUrl, leaseSeconds);
            }
        } else {
            self.httpService = new(adaptor, hubUrl, self.defaultHubLeaseSeconds);
        }
        error? result = self.httpListener.attach(<HttpService> self.httpService, name);
        if (result is error) {
            return error Error("Error occurred while attaching the service", result);
        }
    }

    isolated function retrieveHubUrl(string[]|string? servicePath) returns string {
        string host = self.listenerConfig.host;
        string protocol = self.listenerConfig.secureSocket is () ? "http" : "https";
        string concatenatedServicePath = "";
        if servicePath is string {
            concatenatedServicePath += "/" + servicePath;
        } else if servicePath is string[] {
            foreach string pathSegment in servicePath {
                concatenatedServicePath += "/" + pathSegment;
            }
        }
        return string `${protocol}://${host}:${self.port.toString()}${concatenatedServicePath}`;
    }

    # Detaches the provided `websubhub:Service` from the `websubhub:Listener`.
    # ```ballerina
    # check hubListenerEp.detach('service);
    # ```
    # 
    # + s - The `websubhub:Service` object to be detached
    # + return - An `websubhub:Error` if an error occurred during the service detaching process or else `()`
    public isolated function detach(Service s) returns Error? {
        error? result = self.httpListener.detach(<HttpService> self.httpService);
        if (result is error) {
            return error Error("Error occurred while detaching the service", result);
        }
    }

    # Starts the registered service programmatically.
    # ```ballerina
    # check hubListenerEp.'start();
    # ```
    # 
    # + return - An `websubhub:Error` if an error occurred during the listener-starting process or else `()`
    public isolated function 'start() returns Error? {
        error? listenerError = self.httpListener.'start();
        if (listenerError is error) {
            return error Error("Error occurred while starting the service", listenerError);
        }
    }

    # Gracefully stops the hub listener. Already-accepted requests will be served before the connection closure.
    # ```ballerina
    # check hubListenerEp.gracefulStop();
    # ```
    # 
    # + return - An `websubhub:Error` if an error occurred during the listener-stopping process
    public isolated function gracefulStop() returns Error? {
        error? result = self.httpListener.gracefulStop();
        if (result is error) {
            return error Error("Error occurred while stopping the service", result);
        }
    }

    # Stops the service listener immediately. It is not implemented yet.
    # ```ballerina
    # check hubListenerEp.immediateStop();
    # ```
    # 
    # + return - An `websubhub:Error` if an error occurred during the listener-stopping process or else `()`
    public isolated function immediateStop() returns Error? {
        error? result = self.httpListener.immediateStop();
        if (result is error) {
            return error Error("Error occurred while stopping the service", result);
        }
    }
}

isolated function retrieveServiceAnnotations(Service serviceType) returns ServiceConfiguration? {
    typedesc<any> serviceTypedesc = typeof serviceType;
    return serviceTypedesc.@ServiceConfig;
}
