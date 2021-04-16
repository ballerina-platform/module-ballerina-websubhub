/*
 * Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.websubhub;

import io.ballerina.tools.diagnostics.DiagnosticSeverity;

/**
 * {@code WebSubHubDiagnosticCodes} is used to hold websubhub related diagnostic codes.
 */
public enum WebSubHubDiagnosticCodes {
    WEBSUBHUB_100("WEBSUBHUB_100", "checkpanic detected, use check",
            DiagnosticSeverity.WARNING),
    WEBSUBHUB_101("WEBSUBHUB_101",
            "websubhub:Listener should only take either http:Listener or websubhub:ListenerConfiguration",
            DiagnosticSeverity.ERROR),
    WEBSUBHUB_102("WEBSUBHUB_102", "websubhub:Service should only implement remote methods",
               DiagnosticSeverity.ERROR),
    WEBSUBHUB_103("WEBSUBHUB_103", "websubhub:Service should implement {0} methods",
            DiagnosticSeverity.ERROR),
    WEBSUBHUB_104("WEBSUBHUB_104", "{0} method is not allowed in websubhub:Service declaration",
            DiagnosticSeverity.ERROR),
    WEBSUBHUB_105("WEBSUBHUB_105", "{0} type parameters not allowed for {1} method",
            DiagnosticSeverity.ERROR),
    WEBSUBHUB_106("WEBSUBHUB_106", "{0} method should have parameters of following {1} types",
            DiagnosticSeverity.ERROR),
    WEBSUBHUB_107("WEBSUBHUB_107", "{0} type is not allowed to be returned from {1} method",
            DiagnosticSeverity.ERROR),
    WEBSUBHUB_108("WEBSUBHUB_108", "{0} method should return {1} types", DiagnosticSeverity.ERROR),
    WEBSUBHUB_109("WEBSUBHUB_109", "{0} method params should follow {1} order",
            DiagnosticSeverity.ERROR);

    private final String code;
    private final String description;
    private final DiagnosticSeverity severity;

    WebSubHubDiagnosticCodes(String code, String description, DiagnosticSeverity severity) {
        this.code = code;
        this.description = description;
        this.severity = severity;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    public DiagnosticSeverity getSeverity() {
        return severity;
    }
}
