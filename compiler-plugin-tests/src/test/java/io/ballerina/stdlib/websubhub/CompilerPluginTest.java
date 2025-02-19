/*
 * Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.websubhub;

import io.ballerina.projects.DiagnosticResult;
import io.ballerina.projects.Package;
import io.ballerina.projects.PackageCompilation;
import io.ballerina.projects.ProjectEnvironmentBuilder;
import io.ballerina.projects.directory.BuildProject;
import io.ballerina.projects.environment.Environment;
import io.ballerina.projects.environment.EnvironmentBuilder;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticInfo;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;
import org.testng.Assert;
import org.testng.annotations.Test;

import java.io.PrintStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.MessageFormat;
import java.util.List;
import java.util.stream.Collectors;

/**
 * This class includes tests for Ballerina WebSub compiler plugin.
 */
public class CompilerPluginTest {
    private static final Path RESOURCE_DIRECTORY = Paths
            .get("src", "test", "resources", "ballerina_sources").toAbsolutePath();
    private static final PrintStream OUT = System.out;
    private static final Path DISTRIBUTION_PATH = Paths
            .get("../", "target", "ballerina-runtime").toAbsolutePath();

    @Test
    public void testValidServiceDeclaration() {
        Package currentPackage = loadPackage("sample_1");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testCompilerPluginForRemoteMethodValidation() {
        Package currentPackage = loadPackage("sample_2");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_102;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        String expectedMsg = MessageFormat.format(
                expectedCode.getDescription(), "onUnsubscriptionIntentVerified");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForRequiredMethodValidation() {
        Package currentPackage = loadPackage("sample_3");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_103;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMessage = MessageFormat.format(expectedCode.getDescription(),
                "onUpdateMessage");
        Assert.assertEquals(diagnostic.message(), expectedMessage);
    }

    @Test
    public void testCompilerPluginForNotAllowedMethods() {
        Package currentPackage = loadPackage("sample_4");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_104;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMessage = MessageFormat.format(expectedCode.getDescription(), "onNewAction");
        Assert.assertEquals(diagnostic.message(), expectedMessage);
    }

    @Test
    public void testCompilerPluginForInvalidParameterTypesWithUnions() {
        Package currentPackage = loadPackage("sample_5");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_105;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(),
                "websubhub:TopicRegistration|sample_5:MetaDetails", "onRegisterTopic");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForInvalidParameterTypes() {
        Package currentPackage = loadPackage("sample_6");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_105;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(),
                "sample_6:SimpleObj", "onDeregisterTopic");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForNoParameterAvailable() {
        Package currentPackage = loadPackage("sample_7");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_106;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(),
                "onUpdateMessage", "websubhub:UpdateMessage,http:Headers");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForInvalidReturnTypes() {
        Package currentPackage = loadPackage("sample_8");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_107;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String typeDesc = String.format("%s|%s|%s|%s|%s|%s",
                "websubhub:SubscriptionAccepted", "websubhub:SubscriptionPermanentRedirect",
                "websubhub:SubscriptionTemporaryRedirect", "websubhub:BadSubscriptionError",
                "websubhub:InternalSubscriptionError", "sample_8:NewResponse");
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(), typeDesc, "onSubscription");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForNoReturnType() {
        Package currentPackage = loadPackage("sample_9");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_108;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String typeDesc = String.format("%s|%s|%s",
                "websubhub:UnsubscriptionAccepted", "websubhub:BadUnsubscriptionError",
                "websubhub:InternalUnsubscriptionError");
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(),
                "onUnsubscription", typeDesc);
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForListenerImplicitInit() {
        Package currentPackage = loadPackage("sample_10");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_101;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        Assert.assertEquals(diagnostic.message(), expectedCode.getDescription());
    }

    @Test
    public void testCompilerPluginForListenerExplicitInit() {
        Package currentPackage = loadPackage("sample_11");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_101;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        Assert.assertEquals(diagnostic.message(), expectedCode.getDescription());
    }

    @Test
    public void testValidServiceDeclarationWithAliases() {
        Package currentPackage = loadPackage("sample_12");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testCompilerPluginForParamOrder() {
        Package currentPackage = loadPackage("sample_13");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_109;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(),
                "onUnsubscription", "websubhub:Unsubscription,http:Headers");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testValidServiceDeclarationWithIncludedRecordParams() {
        Package currentPackage = loadPackage("sample_14");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testWithReturnTypesWithErrorsWithModuleAliases() {
        Package currentPackage = loadPackage("sample_15");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testWithReturnTypesWithErrors() {
        Package currentPackage = loadPackage("sample_16");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testWithAdditionalMethods() {
        Package currentPackage = loadPackage("sample_17");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testWithAdditionalExternMethods() {
        Package currentPackage = loadPackage("sample_18");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testWithReadonlyParams() {
        Package currentPackage = loadPackage("sample_19");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testInvalidReadonlyParams() {
        Package currentPackage = loadPackage("sample_20");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 5);
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_105;
        String invalidTypeDesc = "http:Headers & readonly";
        validateErrorsForInvalidReadonlyTypes(expectedCode, errorDiagnostics.get(0),
                invalidTypeDesc, "onRegisterTopic");
        validateErrorsForInvalidReadonlyTypes(expectedCode, errorDiagnostics.get(1),
                invalidTypeDesc, "onDeregisterTopic");
        validateErrorsForInvalidReadonlyTypes(expectedCode, errorDiagnostics.get(2),
                invalidTypeDesc, "onUpdateMessage");
        validateErrorsForInvalidReadonlyTypes(expectedCode, errorDiagnostics.get(3),
                invalidTypeDesc, "onSubscription");
        validateErrorsForInvalidReadonlyTypes(expectedCode, errorDiagnostics.get(4),
                invalidTypeDesc, "onUnsubscription");
    }

    @Test
    public void testWithNexExprWithUserDefinedClasses() {
        Package currentPackage = loadPackage("sample_21");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.errorCount(), 0);
    }

    @Test
    public void testCompilerPluginForListenerImplicitInitWithCheckExpr() {
        Package currentPackage = loadPackage("sample_22");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .collect(Collectors.toList());
        Assert.assertEquals(errorDiagnostics.size(), 1);
        Diagnostic diagnostic = (Diagnostic) errorDiagnostics.toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_101;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        Assert.assertEquals(diagnostic.message(), expectedCode.getDescription());
    }

    @Test
    public void testCompilerPluginForListenerInitWithPortConfig() {
        Package currentPackage = loadPackage("sample_23");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .toList();
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    @Test
    public void testCompilerPluginWebsubhubControllerUsage() {
        Package currentPackage = loadPackage("sample_24");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        List<Diagnostic> errorDiagnostics = diagnosticResult.diagnostics().stream()
                .filter(d -> DiagnosticSeverity.ERROR.equals(d.diagnosticInfo().severity()))
                .toList();
        Assert.assertEquals(errorDiagnostics.size(), 0);
    }

    private void validateErrorsForInvalidReadonlyTypes(WebSubHubDiagnosticCodes expectedCode, Diagnostic diagnostic,
                                                       String typeDesc, String remoteMethodName) {
        DiagnosticInfo info = diagnostic.diagnosticInfo();
        Assert.assertEquals(info.code(), expectedCode.getCode());
        String expectedMsg1 = MessageFormat.format(expectedCode.getDescription(), typeDesc, remoteMethodName);
        Assert.assertEquals(diagnostic.message(), expectedMsg1);
    }

    private Package loadPackage(String path) {
        Path projectDirPath = RESOURCE_DIRECTORY.resolve(path);
        BuildProject project = BuildProject.load(getEnvironmentBuilder(), projectDirPath);
        return project.currentPackage();
    }

    private static ProjectEnvironmentBuilder getEnvironmentBuilder() {
        Environment environment = EnvironmentBuilder.getBuilder().setBallerinaHome(DISTRIBUTION_PATH).build();
        return ProjectEnvironmentBuilder.getBuilder(environment);
    }
}
