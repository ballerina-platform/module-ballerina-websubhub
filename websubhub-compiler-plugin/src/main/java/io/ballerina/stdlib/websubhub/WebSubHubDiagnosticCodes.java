package io.ballerina.stdlib.websubhub;

import io.ballerina.tools.diagnostics.DiagnosticSeverity;

/**
 * {@code WebSubDiagnosticCodes} is used to hold websub related diagnostic codes.
 */
public enum WebSubHubDiagnosticCodes {
    WEBSUBHUB_100("WEBSUBHUB_100", "checkpanic detected, use check",
            DiagnosticSeverity.WARNING);

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
