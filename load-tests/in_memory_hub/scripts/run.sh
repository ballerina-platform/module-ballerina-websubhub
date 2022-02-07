#!/bin/bash -e
# Copyright 2022 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Execution script for ballerina performance tests
# ----------------------------------------------------------------------------
set -e

# Using the ballerina zip version for testing. Once finalized, can use a docker image with process_csv_output util
echo "----------Downloading Ballerina----------"
wget https://dist.ballerina.io/downloads/2201.0.0/ballerina-2201.0.0-swan-lake-linux-x64.deb

echo "----------Setting Up Ballerina----------"
sudo dpkg -i ballerina-2201.0.0-swan-lake-linux-x64.deb

echo "----------Finalizing results----------"
bal run $scriptsDir/load_test/ -- "In Memory Hub" "$resultsDir/summary.csv"
