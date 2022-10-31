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

package io.ballerina.stdlib.websubhub.task;

import io.ballerina.compiler.api.ModuleID;
import io.ballerina.compiler.api.symbols.ErrorTypeSymbol;
import io.ballerina.compiler.api.symbols.FunctionSymbol;
import io.ballerina.compiler.api.symbols.IntersectionTypeSymbol;
import io.ballerina.compiler.api.symbols.ModuleSymbol;
import io.ballerina.compiler.api.symbols.Qualifier;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.compiler.syntax.tree.NodeLocation;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.stdlib.websubhub.Constants;
import io.ballerina.stdlib.websubhub.WebSubHubDiagnosticCodes;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticFactory;
import io.ballerina.tools.diagnostics.DiagnosticInfo;

import java.util.List;
import java.util.Optional;

/**
 * {@code AnalyserUtils} contains utility functions required for {@code websubhub:Service} validation.
 */
public final class AnalyserUtils {
    public static void updateContext(SyntaxNodeAnalysisContext context, WebSubHubDiagnosticCodes errorCode,
                                     NodeLocation location, Object... args) {
        DiagnosticInfo diagnosticInfo = new DiagnosticInfo(
                errorCode.getCode(), errorCode.getDescription(), errorCode.getSeverity());
        Diagnostic diagnostic = DiagnosticFactory.createDiagnostic(diagnosticInfo, location, args);
        context.reportDiagnostic(diagnostic);
    }

    public static boolean isWebSubHubListener(TypeSymbol listenerType) {
        if (listenerType.typeKind() == TypeDescKind.UNION) {
            return ((UnionTypeSymbol) listenerType).memberTypeDescriptors().stream()
                    .filter(typeDescriptor -> typeDescriptor instanceof TypeReferenceTypeSymbol)
                    .map(typeReferenceTypeSymbol -> (TypeReferenceTypeSymbol) typeReferenceTypeSymbol)
                    .anyMatch(AnalyserUtils::isWebSubListenerType);
        }
        if (listenerType.typeKind() == TypeDescKind.TYPE_REFERENCE) {
            return isWebSubListenerType((TypeReferenceTypeSymbol) listenerType);
        }
        if (listenerType.typeKind() == TypeDescKind.OBJECT) {
            Optional<ModuleSymbol> moduleOpt = listenerType.getModule();
            return moduleOpt.isPresent() && isWebSubHub(moduleOpt.get());
        }
        return false;
    }

    private static boolean isWebSubListenerType(TypeReferenceTypeSymbol typeSymbol) {
        if (typeSymbol.getName().isEmpty() || !Constants.LISTENER_IDENTIFIER.equals(typeSymbol.getName().get())) {
            return false;
        }
        return typeSymbol.getModule().isPresent() && isWebSubHub(typeSymbol.getModule().get());
    }

    public static boolean isWebSubHub(ModuleSymbol moduleSymbol) {
        Optional<String> moduleNameOpt = moduleSymbol.getName();
        return moduleNameOpt.isPresent() && Constants.PACKAGE_NAME.equals(moduleNameOpt.get())
                && Constants.PACKAGE_ORG.equals(moduleSymbol.id().orgName());
    }

    public static String getTypeDescription(TypeSymbol paramType) {
        TypeDescKind paramKind = paramType.typeKind();
        if (TypeDescKind.TYPE_REFERENCE.equals(paramKind)) {
            TypeSymbol internalType = ((TypeReferenceTypeSymbol) paramType).typeDescriptor();
            if (internalType instanceof ErrorTypeSymbol) {
                return getErrorTypeDescription(paramType);
            } else {
                String moduleName = paramType.getModule().flatMap(ModuleSymbol::getName).orElse("");
                String type = paramType.getName().orElse("");
                return getQualifiedType(type, moduleName);
            }
        } else if (TypeDescKind.UNION.equals(paramKind)) {
            List<TypeSymbol> availableTypes = ((UnionTypeSymbol) paramType).memberTypeDescriptors();
            boolean optionalSymbolAvailable = availableTypes.stream()
                    .anyMatch(t -> TypeDescKind.NIL.equals(t.typeKind()));
            String concatenatedTypeDesc = availableTypes.stream()
                    .map(AnalyserUtils::getTypeDescription)
                    .filter(e -> !e.isEmpty() && !e.isBlank())
                    .reduce((a, b) -> String.join("|", a, b)).orElse("");
            return optionalSymbolAvailable ? concatenatedTypeDesc + Constants.OPTIONAL : concatenatedTypeDesc;
        } else if (TypeDescKind.INTERSECTION.equals(paramKind)) {
            List<TypeSymbol> availableTypes = ((IntersectionTypeSymbol) paramType).memberTypeDescriptors();
            // Intersection type description generation, should not skip `readonly` for `http:Headers`
            boolean containsHttpHeaders = availableTypes.stream()
                    .anyMatch(e -> Constants.HTTP_HEADERS.equals(getTypeDescription(e)));
            return availableTypes.stream()
                    .filter(e -> containsHttpHeaders || !TypeDescKind.READONLY.equals(e.typeKind()))
                    .map(AnalyserUtils::getTypeDescription)
                    .filter(e -> !e.isEmpty() && !e.isBlank())
                    .reduce((a, b) -> String.join(" & ", a, b)).orElse("");
        } else if (TypeDescKind.ERROR.equals(paramKind)) {
            return getErrorTypeDescription(paramType);
        } else if (TypeDescKind.READONLY.equals(paramKind)) {
            return Constants.READONLY;
        } else {
            return paramType.getName().orElse("");
        }
    }

    private static String getErrorTypeDescription(TypeSymbol internalType) {
        String signature = internalType.signature();
        Optional<ModuleID> moduleIdOpt = internalType.getModule().map(ModuleSymbol::id);
        String moduleId = moduleIdOpt.map(ModuleID::toString).orElse("");
        String type = signature.replace(moduleId, "").replace(":", "");
        String moduleName = moduleIdOpt.map(ModuleID::modulePrefix).orElse("");
        return getQualifiedType(type, moduleName);
    }

    public static String getQualifiedType(String paramType, String moduleName) {
        return moduleName.isBlank() ? paramType : String.format("%s:%s", moduleName, paramType);
    }

    public static boolean isRemoteMethod(FunctionSymbol functionSymbol) {
        return functionSymbol.qualifiers().contains(Qualifier.REMOTE);
    }
}
