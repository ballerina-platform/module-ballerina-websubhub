package io.ballerina.stdlib.websubhub;

import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.plugins.CodeAnalysisContext;
import io.ballerina.projects.plugins.CodeAnalyzer;
import io.ballerina.stdlib.websubhub.task.CheckExpAnalysisTask;

/**
 * {@code WebSubCodeAnalyzer} handles syntax analysis for WebSub Services.
 */
public class WebSubHubCodeAnalyzer extends CodeAnalyzer {
    @Override
    public void init(CodeAnalysisContext codeAnalysisContext) {
        codeAnalysisContext.addSyntaxNodeAnalysisTask(new CheckExpAnalysisTask(), SyntaxKind.CHECK_EXPRESSION);
    }
}
