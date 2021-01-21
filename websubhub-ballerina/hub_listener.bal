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

# Represents a Service listener endpoint.
public class Listener {
    private http:Listener httpListener;
    private http:ListenerConfiguration listenerConfig;
    private int port;
    private HttpService? httpService;

    // todo HTTP config needs to be passed as optional parameter
    # Invoked during the initialization of a `websubhub:Listener`. Either an `http:Listener` or a port number must be
    # provided to initialize the listener.
    #
    # + listenTo - An `http:Listener` or a port number to listen for the service
    public isolated function init(int|http:Listener listenTo) returns error? {
        if (listenTo is int) {
            self.httpListener = check new(listenTo);
        } else {
            self.httpListener = listenTo;
        }
        self.listenerConfig = self.httpListener.getConfig();
        self.port = self.httpListener.getPort();
        self.httpService = ();
    }

    # Attaches the provided Service to the Listener.
    #
    # + s - The `websubhub:Service` object to attach
    # + name - The path of the Service to be hosted
    # + return - An `error`, if an error occurred during the service attaching process
    public isolated function attach(Service s, string[]|string? name = ()) returns error? {
        string hubUrl = self.retrieveHubUrl(name);
        self.httpService = new(s, hubUrl);
        checkpanic self.httpListener.attach(<HttpService> self.httpService, name);
    }

    isolated function retrieveHubUrl(string[]|string? servicePath) returns string {
        string host = self.listenerConfig.host;
        string protocol = self.listenerConfig.secureSocket is () ? "http" : "https";
        
        string concatenatedServicePath = "";
        
        if (servicePath is string) {
            concatenatedServicePath += "/" + <string>servicePath;
        } else if (servicePath is string[]) {
            foreach var pathSegment in <string[]>servicePath {
                concatenatedServicePath += "/" + pathSegment;
            }
        }

        return protocol + "://" + host + ":" + self.port.toString() + concatenatedServicePath;
    }

    # Detaches the provided Service from the Listener.
    #
    # + s - The service to be detached
    # + return - An `error`, if an error occurred during the service detaching process
    public isolated function detach(Service s) returns error? {
        checkpanic self.httpListener.detach(<HttpService> self.httpService);
    }

    # Starts the attached Service.
    #
    # + return - An `error`, if an error occurred during the listener starting process
    public isolated function 'start() returns error? {
        checkpanic self.httpListener.'start();
    }

    # Gracefully stops the hub listener. Already accepted requests will be served before the connection closure.
    #
    # + return - An `error`, if an error occurred during the listener stopping process
    public isolated function gracefulStop() returns error? {
        return self.httpListener.gracefulStop();
    }

    # Stops the service listener immediately. It is not implemented yet.
    #
    # + return - An `error`, if an error occurred during the listener stopping process
    public isolated function immediateStop() returns error? {
        return self.httpListener.immediateStop();
    }
}
