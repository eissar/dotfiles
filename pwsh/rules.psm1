function Measure-WarningAboutInvokeSomething {
    <#
    .DESCRIPTION
        Warns when 'Invoke-Something' is called and suggests 'Invoke-SomethingElse'.
    #>

    param (
        [System.Management.Automation.Language.CommandAst]$ast
    )

    if ($ast.GetCommandName() -eq 'Invoke-Something') {
        [int]$startLineNumber =  $ast.Extent.StartLineNumber
        [int]$endLineNumber = $ast.Extent.EndLineNumber
        [int]$startColumnNumber = $ast.Extent.StartColumnNumber
        [int]$endColumnNumber = $ast.Extent.EndColumnNumber
        [string]$correctionText = 'Invoke-SomethingElse'
        [string]$correctionDescription = 'Change to Invoke-SomethingElse'

        $correctionExtent = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' $startLineNumber,$endLineNumber,$startColumnNumber,$endColumnNumber,$correctionText,$correctionDescription
        $suggestedCorrections = New-Object System.Collections.ObjectModel.Collection['Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent']
        $suggestedCorrections.add($correctionExtent) | Out-Null

        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
            RuleName               = 'PSAvoidInvokeSomething' # Explicit rule name for easier reference
            Message                = "The command 'Invoke-Something' should not be used. Please use 'Invoke-SomethingElse' instead." # More descriptive message
            Extent                 = $ast.Extent
            "Severity"             = "Warning"
            "SuggestedCorrections" = $suggestedCorrections
        }
    }
}
Export-ModuleMember 'Measure-WarningAboutInvokeSomething'

<#
.DESCRIPTION
    Finds instances of members with back ticks, which can be used to
    obfuscate the member to evade static analysis IOC matching.
#>
function Measure-TickUsageInMember {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    # Finds MemberExpressionAst nodes that contain one or more back ticks.
    [ScriptBlock] $predicate = {
        param ([System.Management.Automation.Language.Ast] $Ast)

        $targetAst = $Ast -as [System.Management.Automation.Language.MemberExpressionAst]
        if ($targetAst) {
            if ($targetAst.Member.Extent.Text -cmatch '`') {
                return $true
            }
        }
    }

    $foundNodes = $ScriptBlockAst.FindAll($predicate, $true)
    foreach ($foundNode in $foundNodes) {
        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord] @{
            "Message"  = "Possible obfuscation found via back tick in member: " + $foundNode.Member.Extent.Text
            "Extent"   = $foundNode.Extent
            "RuleName" = "MaliciousContent." + $PSCmdlet.MyInvocation.InvocationName.Split('-')[-1]
            "Severity" = "Warning"
        }
    }
}
Export-ModuleMember 'Measure-TickUsageInMember'

