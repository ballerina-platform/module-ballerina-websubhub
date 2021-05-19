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
import org.testng.Assert;
import org.testng.annotations.Test;

import java.io.PrintStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.MessageFormat;

/**
 * This class includes tests for Ballerina WebSub compiler plugin.
 */
public class CompilerPluginTest {
    private static final Path RESOURCE_DIRECTORY = Paths
            .get("src", "test", "resources", "ballerina_sources").toAbsolutePath();
    private static final PrintStream OUT = System.out;
    private static final Path DISTRIBUTION_PATH = Paths
            .get("build", "target", "ballerina-distribution").toAbsolutePath();

    @Test
    public void testValidServiceDeclaration() {
        Package currentPackage = loadPackage("sample_1");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 0);
    }

    @Test
    public void testCompilerPluginForRemoteMethodValidation() {
        Package currentPackage = loadPackage("sample_2");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_102;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        Assert.assertEquals(diagnostic.message(), expectedCode.getDescription());
    }

    @Test
    public void testCompilerPluginForRequiredMethodValidation() {
        Package currentPackage = loadPackage("sample_3");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        WebSubHubDiagnosticCodes expectedCode = WebSubHubDiagnosticCodes.WEBSUBHUB_106;
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), expectedCode.getCode());
        String expectedMsg = MessageFormat.format(expectedCode.getDescription(),
                "onUpdateMessage", "websubhub:UpdateMessage,http:Request");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testCompilerPluginForInvalidReturnTypes() {
        Package currentPackage = loadPackage("sample_8");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
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
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 0);
    }

    @Test
    public void testCompilerPluginForParamOrder() {
        Package currentPackage = loadPackage("sample_13");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 1);
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.diagnostics().toArray()[0];
        DiagnosticInfo diagnosticInfo = diagnostic.diagnosticInfo();
        Assert.assertNotNull(diagnosticInfo, "DiagnosticInfo is null for erroneous service definition");
        Assert.assertEquals(diagnosticInfo.code(), "WEBSUBHUB_109");
        String expectedMsg = MessageFormat.format("{0} method params should follow {1} order",
                "onUnsubscription", "websubhub:Unsubscription,http:Request");
        Assert.assertEquals(diagnostic.message(), expectedMsg);
    }

    @Test
    public void testValidServiceDeclarationWithIncludedRecordParams() {
        Package currentPackage = loadPackage("sample_14");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 0);
    }

    @Test
    public void testWithReturnTypesWithErrorsWithModuleAliases() {
        Package currentPackage = loadPackage("sample_15");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 0);
    }

    @Test
    public void testWithReturnTypesWithErrors() {
        Package currentPackage = loadPackage("sample_16");
        PackageCompilation compilation = currentPackage.getCompilation();
        DiagnosticResult diagnosticResult = compilation.diagnosticResult();
        Assert.assertEquals(diagnosticResult.diagnostics().size(), 0);
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
