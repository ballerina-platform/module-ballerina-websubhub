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
import jmshub.connections;

import ballerinax/java.jms;

# Producer which persist node coordination related messages.
final jms:MessageProducer producer = check connections:createMessageProducer();

# Consumer which reads the coordination related consensus.
final [jms:Session, jms:MessageConsumer] consensusConnection = check connections:createMessageConsumer(
        CONSENSUS_TOPIC, string `__consensus-receiver-${config:serverId}}`);

# Consumer which reads the node-discovery events.
final [jms:Session, jms:MessageConsumer] nodeDiscoveryConnection = check connections:createMessageConsumer(
        NODE_DISCOVERY_TOPIC, string `__node-discovery-receiver-${config:serverId}}`);
