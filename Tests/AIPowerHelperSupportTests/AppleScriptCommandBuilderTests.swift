import Testing
@testable import AIPowerHelperSupport

struct AppleScriptCommandBuilderTests {
    @Test
    func buildsAdministratorScriptForPmsetCommand() {
        let builder = AppleScriptCommandBuilder()

        let script = builder.build(arguments: ["-c", "sleep", "0"])

        #expect(script == #"do shell script "/usr/bin/pmset -c sleep 0" with administrator privileges"#)
    }

    @Test
    func escapesQuotesInArguments() {
        let builder = AppleScriptCommandBuilder()

        let script = builder.build(arguments: ["-a", "custom", #"value"quoted"#])

        #expect(script == #"do shell script "/usr/bin/pmset -a custom value\"quoted" with administrator privileges"#)
    }
}
