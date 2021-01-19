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

# Represents a HubService listener endpoint.
public class Listener {
    private http:Listener httpListener;
    private HttpService? httpService;

    # Invoked during the initialization of a `websubhub:Listener`. Either an `http:Listner` or a port number must be
    # provided to initialize the listener.
    #
    # + listenTo - An `http:Listener` or a port number to listen for the service
    public isolated function init(int|http:Listener listenTo) returns error? {
        if (listenTo is int) {
            self.httpListener = check new(listenTo);
        } else {
            self.httpListener = listenTo;
        }
        self.httpService = ();
    }

    # Attaches the provided HubService to the Listener.
    #
    # + s - The `websubhub:Service` object to attach
    # + name - The path of the HubService to be hosted
    # + return - An `error`, if an error occurred during the service attaching process
    public isolated function attach(HubService s, string[]|string? name = ()) returns error? {
        self.httpService = new(s);
        checkpanic self.httpListener.attach(<HttpService> self.httpService, name);
    }

    # Detaches the provided HubService from the Listener.
    #
    # + s - The service to be detached
    # + return - An `error`, if an error occurred during the service detaching process
    public isolated function detach(HubService s) returns error? {
        checkpanic self.httpListener.detach(<HttpService> self.httpService);
    }

    # Starts the attached HubService.
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
