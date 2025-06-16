// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

import jmshub.config;

import ballerinax/java.jms;

# Producer which persist the current in-memory state of the Hub.
public final jms:MessageProducer statePersistProducer = check createMessageProducer();

# Consumer which reads the persisted websub events.
public final jms:MessageConsumer websubEventsConsumer = check createMessageConsumer(
        config:websubEventsTopic, string `websub-events-receiver-${config:constructedServerId}`);

isolated function createMessageProducer() returns jms:MessageProducer|error {
    jms:Connection connection = check new (config:brokerConfig);
    jms:Session session = check connection->createSession();
    return session.createProducer();
}

# Creates a `jms:MessageConsumer` for a subscriber.
#
# + topic - The JMS topic to which the consumer should subscribe
# + subscriberName - The name used to identify the subscription 
# + return - `jms:MessageConsumer` if succcessful or else `error`
public isolated function createMessageConsumer(string topic, string subscriberName) returns jms:MessageConsumer|error {
    jms:Connection connection = check new (config:brokerConfig);
    jms:Session session = check connection->createSession(jms:CLIENT_ACKNOWLEDGE);
    return session.createConsumer({
        'type: jms:DURABLE,
        destination: {
            'type: jms:TOPIC,
            name: topic
        },
        subscriberName
    });
}
