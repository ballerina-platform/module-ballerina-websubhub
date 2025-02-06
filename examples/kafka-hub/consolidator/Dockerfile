# ------------------------------------------------------------------------
#
# Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
#
#  WSO2 LLC. licenses this file to you under the Apache License,
#  Version 2.0 (the "License"); you may not use this file except
#  in compliance with the License.
#  You may obtain a copy of the License at

#  http://www.apache.org/licenses/LICENSE-2.0

#  Unless required by applicable law or agreed to in writing,
#  software distributed under the License is distributed on an
#  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#  KIND, either express or implied.  See the License for the
#  specific language governing permissions and limitations
#  under the License.
#
# ------------------------------------------------------------------------

ARG BASE_IMAGE_DIGEST=sha256:6bb29faf5333dcc2034cad9d29abd0832846c8d961143c70a4c0e504fdfc9543
FROM eclipse-temurin:17.0.14_7-jdk-ubi9-minimal@${BASE_IMAGE_DIGEST}
LABEL maintainer="WSO2 Docker Maintainers <dev@wso2.org>"

# set Docker image build arguments
# build arguments for user/group configurations
ARG USER=consolidator
ARG USER_ID=10001
ARG USER_GROUP=wso2
ARG USER_GROUP_ID=10001
ARG USER_HOME=/home/${USER}

# build arguments for WSO2 product installation
ARG JAR_FILE_PATH=target/bin/consolidatorService.jar

# build argument for MOTD
ARG MOTD="\n\
Welcome to WSO2 Docker resources.\n\
------------------------------------ \n\
This Docker container comprises of a WSO2 product, running with its latest GA release \n\
which is under the Apache License, Version 2.0. \n\
Read more about Apache License, Version 2.0 here @ http://www.apache.org/licenses/LICENSE-2.0.\n"

# create the non-root user and group and set MOTD login message
RUN \
    addgroup -g ${USER_GROUP_ID} -S ${USER_GROUP} && adduser -u ${USER_ID} -S ${USER} \
    -G ${USER_GROUP} -h ${USER_HOME} \
    && echo '[ ! -z "${TERM}" -a -r /etc/motd ] && cat /etc/motd' >> /etc/bash.bashrc; echo "${MOTD}" > /etc/motd

# copy init script to user home
COPY --chown=${USER}:${USER_GROUP} ${JAR_FILE_PATH} ${USER_HOME}/

# set the user and work directory
USER ${USER_ID}
WORKDIR ${USER_HOME}

# set environment variables
ENV JAVA_OPTS="-Djava.util.prefs.systemRoot=${USER_HOME}/.java -Djava.util.prefs.userRoot=${USER_HOME}/.java/.userPrefs" \
    WORKING_DIRECTORY=${USER_HOME}

CMD java -jar consolidatorService.jar
