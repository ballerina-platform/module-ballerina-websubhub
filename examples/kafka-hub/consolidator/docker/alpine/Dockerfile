# syntax = docker/dockerfile:1.0-experimental
# ------------------------------------------------------------------------
#
# Copyright 2022 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
#
# ------------------------------------------------------------------------

# ACR image tag: adoptopenjdk/openjdk11:jre-11.0.16_8-alpine
ARG BASE_IMAGE_DIGEST="sha256:409b76ab70e60ca49fb974171fc40a44fffe6da89591ce80835d33ddb801b4c1"
FROM adoptopenjdk/openjdk11@${BASE_IMAGE_DIGEST}
LABEL maintainer="WSO2 Docker Maintainers <dev@wso2.org>"

# set Docker image build arguments
# build arguments for user/group configurations
ARG USER=websubhub
ARG USER_ID=10001
ARG USER_GROUP=wso2
ARG USER_GROUP_ID=10001
ARG USER_HOME=/home/${USER}
# build arguments for WSO2 product installation
ARG WEBSUBHUB_HOME=${USER_HOME}/kafkaHub
ARG JAR_FILE_PATH=consolidatorService.jar


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

# create Java prefs dir
# this is to avoid warning logs printed by FileSystemPreferences class
RUN \
    mkdir -p ${USER_HOME}/.java/.systemPrefs \
    && mkdir -p ${USER_HOME}/.java/.userPrefs \
    && chmod -R 755 ${USER_HOME}/.java \
    && chown -R ${USER}:${USER_GROUP} ${USER_HOME}/.java

# copy init script to user home
COPY --chown=${USER}:${USER_GROUP} ${JAR_FILE_PATH} ${USER_HOME}/
COPY --chown=${USER}:${USER_GROUP} Config.toml ${USER_HOME}/Config.toml

# install required packages
RUN \
    apk update \
    && DEBIAN_FRONTEND=noninteractive apk add --no-cache \
        wget \
        jq \
        curl

# set the user and work directory
USER ${USER_ID}
WORKDIR ${WEBSUBHUB_HOME}

# set environment variables
ENV JAVA_OPTS="-Djava.util.prefs.systemRoot=${USER_HOME}/.java -Djava.util.prefs.userRoot=${USER_HOME}/.java/.userPrefs" \
    WORKING_DIRECTORY=${WEBSUBHUB_HOME} \
    WEBSUBHUB_HOME=${WEBSUBHUB_HOME}

CMD java -jar ${JAR_FILE_PATH}
