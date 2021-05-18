package io.ballerina.stdlib.websubhub.task.validator;

import io.ballerina.compiler.api.ModuleID;
import io.ballerina.compiler.api.symbols.FunctionSymbol;
import io.ballerina.compiler.api.symbols.FunctionTypeSymbol;
import io.ballerina.compiler.api.symbols.ModuleSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.Qualifier;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.NodeLocation;
import io.ballerina.compiler.syntax.tree.ServiceDeclarationNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.stdlib.websubhub.Constants;
import io.ballerina.stdlib.websubhub.WebSubHubDiagnosticCodes;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import static io.ballerina.stdlib.websubhub.task.AnalyserUtils.getParamTypeDescription;
import static io.ballerina.stdlib.websubhub.task.AnalyserUtils.getQualifiedType;
import static io.ballerina.stdlib.websubhub.task.AnalyserUtils.getReturnTypeDescription;
import static io.ballerina.stdlib.websubhub.task.AnalyserUtils.updateContext;

/**
 * {@code ServiceDeclarationValidator} validates whether websubhub service declaration is complying to current websubhub
 * package implementation.
 */
public class ServiceDeclarationValidator {
    private static final ServiceDeclarationValidator INSTANCE = new ServiceDeclarationValidator();
    private static final List<String> allowedMethods;
    private static final List<String> requiredMethods;
    private static final Map<String, List<String>> allowedParameterTypes;
    private static final Map<String, List<String>> allowedReturnTypes;
    private static final List<String> methodsWithOptionalReturnTypes;

    static {
        allowedMethods = List.of(
                Constants.ON_REGISTER_TOPIC, Constants.ON_DEREGISTER_TOPIC, Constants.ON_UPDATE_MESSAGE,
                Constants.ON_SUBSCRIPTION, Constants.ON_SUBSCRIPTION_VALIDATION,
                Constants.ON_SUBSCRIPTION_INTENT_VERIFICATION, Constants.ON_UNSUBSCRIPTION,
                Constants.ON_UNSUBSCRIPTION_VALIDATION, Constants.ON_UNSUBSCRIPTION_INTENT_VERIFICATION
        );
        requiredMethods = List.of(
                Constants.ON_REGISTER_TOPIC, Constants.ON_DEREGISTER_TOPIC, Constants.ON_UPDATE_MESSAGE,
                Constants.ON_SUBSCRIPTION_INTENT_VERIFICATION, Constants.ON_UNSUBSCRIPTION_INTENT_VERIFICATION
        );
        allowedParameterTypes = Map.of(
                Constants.ON_REGISTER_TOPIC,
                List.of(Constants.TOPIC_REGISTRATION, Constants.BASE_REQUEST),
                Constants.ON_DEREGISTER_TOPIC,
                List.of(Constants.TOPIC_DEREGISTRATION, Constants.BASE_REQUEST),
                Constants.ON_UPDATE_MESSAGE,
                List.of(Constants.UPDATE_MESSAGE, Constants.BASE_REQUEST),
                Constants.ON_SUBSCRIPTION,
                List.of(Constants.SUBSCRIPTION, Constants.BASE_REQUEST),
                Constants.ON_SUBSCRIPTION_VALIDATION,
                Collections.singletonList(Constants.SUBSCRIPTION),
                Constants.ON_SUBSCRIPTION_INTENT_VERIFICATION,
                Collections.singletonList(Constants.VERIFIED_SUBSCRIPTION),
                Constants.ON_UNSUBSCRIPTION,
                List.of(Constants.UNSUBSCRIPTION, Constants.BASE_REQUEST),
                Constants.ON_UNSUBSCRIPTION_VALIDATION,
                Collections.singletonList(Constants.UNSUBSCRIPTION),
                Constants.ON_UNSUBSCRIPTION_INTENT_VERIFICATION,
                Collections.singletonList(Constants.VERIFIED_UNSUBSCRIPTION)
        );
        allowedReturnTypes = Map.of(
                Constants.ON_REGISTER_TOPIC,
                List.of(Constants.TOPIC_REGISTRATION_SUCCESS, Constants.TOPIC_REGISTRATION_ERROR),
                Constants.ON_DEREGISTER_TOPIC,
                List.of(Constants.TOPIC_DEREGISTRATION_SUCCESS, Constants.TOPIC_DEREGISTRATION_ERROR),
                Constants.ON_UPDATE_MESSAGE,
                List.of(Constants.ACKNOWLEDGEMENT, Constants.UPDATE_MESSAGE_ERROR),
                Constants.ON_SUBSCRIPTION,
                List.of(
                        Constants.SUBSCRIPTION_ACCEPTED, Constants.SUBSCRIPTION_PERMANENT_REDIRECT,
                        Constants.SUBSCRIPTION_TEMP_REDIRECT, Constants.BAD_SUBSCRIPTION_ERROR,
                        Constants.SUBSCRIPTION_INTERNAL_ERROR
                ),
                Constants.ON_SUBSCRIPTION_VALIDATION,
                Collections.singletonList(Constants.SUBSCRIPTION_DENIED_ERROR),
                Constants.ON_SUBSCRIPTION_INTENT_VERIFICATION, Collections.emptyList(),
                Constants.ON_UNSUBSCRIPTION,
                List.of(
                        Constants.UNSUBSCRIPTION_ACCEPTED, Constants.BAD_UNSUBSCRIPTION,
                        Constants.UNSUBSCRIPTION_INTERNAL_ERROR
                ),
                Constants.ON_UNSUBSCRIPTION_VALIDATION,
                Collections.singletonList(Constants.UNSUBSCRIPTION_DENIED_ERROR),
                Constants.ON_UNSUBSCRIPTION_INTENT_VERIFICATION, Collections.emptyList()
        );
        methodsWithOptionalReturnTypes = List.of(
                Constants.ON_SUBSCRIPTION_VALIDATION, Constants.ON_SUBSCRIPTION_INTENT_VERIFICATION,
                Constants.ON_UNSUBSCRIPTION_VALIDATION, Constants.ON_UNSUBSCRIPTION_INTENT_VERIFICATION
        );
    }

    public static ServiceDeclarationValidator getInstance() {
        return INSTANCE;
    }

    public void validate(SyntaxNodeAnalysisContext context, ServiceDeclarationNode serviceNode) {
        List<FunctionDefinitionNode> availableFunctionDeclarations = serviceNode.members().stream()
                .filter(member -> member.kind() == SyntaxKind.OBJECT_METHOD_DEFINITION)
                .map(member -> (FunctionDefinitionNode) member).collect(Collectors.toList());
        validateRequiredMethodsImplemented(context, availableFunctionDeclarations, serviceNode.location());
        availableFunctionDeclarations.forEach(fd -> {
            context.semanticModel().symbol(fd).ifPresent(fs -> {
                NodeLocation location = fd.location();
                validateRemoteQualifier(context, (FunctionSymbol) fs, location);
                validateAdditionalMethodImplemented(context, fd, location);
                validateMethodParameters(context, fd, ((FunctionSymbol) fs).typeDescriptor());
                validateMethodReturnTypes(context, fd, ((FunctionSymbol) fs).typeDescriptor());
            });
        });
    }

    private void validateRequiredMethodsImplemented(SyntaxNodeAnalysisContext context,
                                                    List<FunctionDefinitionNode> availableFunctionDeclarations,
                                                    NodeLocation location) {
        List<String> availableMethods = availableFunctionDeclarations.stream()
                .map(fd -> fd.functionName().toString()).collect(Collectors.toList());
        boolean requiredMethodsImplemented = availableMethods.containsAll(requiredMethods);
        if (!requiredMethodsImplemented) {
            List<String> unavailableRequiredMethods = requiredMethods.stream()
                    .filter(e -> !availableMethods.contains(e))
                    .collect(Collectors.toList());
            WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_103;
            String requiredMethodsMsg = String.join(",", unavailableRequiredMethods);
            updateContext(context, errorCode, location, requiredMethodsMsg);
        }
    }

    private void validateRemoteQualifier(SyntaxNodeAnalysisContext context, FunctionSymbol functionSymbol,
                                         NodeLocation location) {
        boolean containsRemoteQualifier = functionSymbol.qualifiers().contains(Qualifier.REMOTE);
        if (!containsRemoteQualifier) {
            WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_102;
            updateContext(context, errorCode, location);
        }
    }

    private void validateAdditionalMethodImplemented(SyntaxNodeAnalysisContext context,
                                                     FunctionDefinitionNode functionDefinition, NodeLocation location) {
        String functionName = functionDefinition.functionName().toString();
        if (!allowedMethods.contains(functionName)) {
            WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_104;
            updateContext(context, errorCode, location, functionName);
        }
    }

    private void validateMethodParameters(SyntaxNodeAnalysisContext context, FunctionDefinitionNode functionDefinition,
                                          FunctionTypeSymbol typeSymbol) {
        String functionName = functionDefinition.functionName().toString();
        if (allowedMethods.contains(functionName)) {
            List<String> allowedParameters = allowedParameterTypes.get(functionName);
            Optional<List<ParameterSymbol>> paramOpt = typeSymbol.params();
            if (paramOpt.isPresent()) {
                List<ParameterSymbol> params = paramOpt.get();
                if (params.isEmpty()) {
                    if (!allowedParameters.isEmpty()) {
                        WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_106;
                        updateContext(context, errorCode, functionDefinition.location(), functionName,
                                String.join(",", allowedParameters));
                    }
                } else {
                    List<String> availableParamNames = params.stream()
                            .map(e -> getParamTypeDescription(e.typeDescriptor()))
                            .collect(Collectors.toList());
                    if (allowedParameters.containsAll(availableParamNames)) {
                        validateParamOrder(context, functionDefinition, functionName, allowedParameters,
                                availableParamNames);
                    } else {
                        List<String> notAllowedParams = availableParamNames.stream()
                                .filter(e -> !allowedParameters.contains(e))
                                .collect(Collectors.toList());
                        String message = String.join(",", notAllowedParams);
                        WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_105;
                        updateContext(context, errorCode, functionDefinition.location(), message, functionName);
                    }
                }
            } else {
                if (!allowedParameters.isEmpty()) {
                    WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_106;
                    updateContext(context, errorCode, functionDefinition.location(), functionName,
                            String.join(",", allowedParameters));
                }
            }
        }
    }

    private void validateParamOrder(SyntaxNodeAnalysisContext context, FunctionDefinitionNode functionDefinition,
                                    String functionName, List<String> allowedParameters,
                                    List<String> availableParamNames) {
        if (allowedParameters.size() >= availableParamNames.size()) {
            for (int idx = 0; idx < availableParamNames.size(); idx++) {
                String availableParam = availableParamNames.get(idx);
                String allowedParam = allowedParameters.get(idx);
                if (!allowedParam.equals(availableParam)) {
                    WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_109;
                    updateContext(context, errorCode, functionDefinition.location(), functionName,
                            String.join(",", allowedParameters));
                    return;
                }
            }
        }
    }

    private void validateMethodReturnTypes(SyntaxNodeAnalysisContext context,
                                           FunctionDefinitionNode functionDefinition, FunctionTypeSymbol typeSymbol) {
        String functionName = functionDefinition.functionName().toString();
        List<String> predefinedReturnTypes = allowedReturnTypes.get(functionName);
        boolean nilableReturnTypeAllowed = methodsWithOptionalReturnTypes.contains(functionName);
        if (allowedMethods.contains(functionName)) {
            Optional<TypeSymbol> returnTypesOpt = typeSymbol.returnTypeDescriptor();
            if (returnTypesOpt.isPresent()) {
                TypeSymbol returnTypeDescription = returnTypesOpt.get();
                if (returnTypeDescription.typeKind().equals(TypeDescKind.NIL) && !nilableReturnTypeAllowed) {
                    WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_108;
                    updateContext(context, errorCode, functionDefinition.location(), functionName,
                            String.join("|", predefinedReturnTypes));
                    return;
                }

                boolean invalidReturnTypePresent = isReturnTypeNotAllowed(
                        predefinedReturnTypes, returnTypeDescription, nilableReturnTypeAllowed);
                if (invalidReturnTypePresent) {
                    String returnTypeName = getReturnTypeDescription(returnTypeDescription);
                    WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_107;
                    updateContext(context, errorCode, functionDefinition.location(), returnTypeName, functionName);
                }
            } else {
                if (!nilableReturnTypeAllowed) {
                    WebSubHubDiagnosticCodes errorCode = WebSubHubDiagnosticCodes.WEBSUBHUB_108;
                    updateContext(context, errorCode, functionDefinition.location(), functionName,
                            String.join("|", predefinedReturnTypes));
                }
            }
        }
    }

    private boolean isReturnTypeNotAllowed(List<String> allowedReturnTypes, TypeSymbol returnTypeDescriptor,
                                           boolean nilableReturnTypeAllowed) {
        TypeDescKind typeKind = returnTypeDescriptor.typeKind();
        if (TypeDescKind.UNION.equals(typeKind)) {
            return ((UnionTypeSymbol) returnTypeDescriptor)
                    .memberTypeDescriptors().stream()
                    .map(e -> isReturnTypeNotAllowed(allowedReturnTypes, e, nilableReturnTypeAllowed))
                    .reduce(false, (a , b) -> a || b);
        } else if (TypeDescKind.TYPE_REFERENCE.equals(typeKind)) {
            String moduleName = returnTypeDescriptor.getModule().flatMap(ModuleSymbol::getName).orElse("");
            String paramType = returnTypeDescriptor.getName().orElse("");
            String qualifiedParamType = getQualifiedType(paramType, moduleName);
            return !allowedReturnTypes.contains(qualifiedParamType);
        } else if (TypeDescKind.ERROR.equals(typeKind)) {
            String signature = returnTypeDescriptor.signature();
            Optional<ModuleID> moduleIdOpt = returnTypeDescriptor.getModule().map(ModuleSymbol::id);
            String moduleId = moduleIdOpt.map(ModuleID::toString).orElse("");
            String paramType = signature.replace(moduleId, "").replace(":", "");
            String moduleName = moduleIdOpt.map(ModuleID::modulePrefix).orElse("");
            String qualifiedParamType = getQualifiedType(paramType, moduleName);
            if (Constants.ERROR.equals(qualifiedParamType)) {
                return false;
            } else {
                return !allowedReturnTypes.contains(qualifiedParamType);
            }
        } else if (TypeDescKind.NIL.equals(typeKind)) {
            return !nilableReturnTypeAllowed;
        } else {
            return true;
        }
    }
}
