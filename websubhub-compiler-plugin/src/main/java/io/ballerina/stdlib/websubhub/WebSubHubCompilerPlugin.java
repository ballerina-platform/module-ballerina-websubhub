package io.ballerina.stdlib.websubhub;

import io.ballerina.projects.plugins.CompilerPlugin;
import io.ballerina.projects.plugins.CompilerPluginContext;

/**
 * {@code WebSubCompilerPlugin} handles compile-time code analysis for WebSub based Services.
 */
public class WebSubHubCompilerPlugin extends CompilerPlugin {
    @Override
    public void init(CompilerPluginContext context) {
        context.addCodeAnalyzer(new WebSubHubCodeAnalyzer());
    }
}
