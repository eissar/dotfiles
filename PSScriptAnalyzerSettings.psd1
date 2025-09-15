@{
    IncludeRules = @(
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSAlignAssignmentStatement',
        'PSUseCorrectCasing',
        'PSAvoidUsingWriteHost',
        'PSProvideCommentHelp'

        # Custom rules
        'Measure-*'
    )
    ExcludeRules = @(
        'PSAvoidUsingCmdletAliases'
    )
    # Rules        = @{
    #
    #     PSUseConsistentIndentation = @{
    #         Enable          = $true
    #         Kind            = 'space'
    #         PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
    #         IndentationSize = 4
    #     }
    #     PSAvoidLongLines                          = @{
    #         Enable            = $true
    #         MaximumLineLength = 80
    #     }
    #
    #     PSUseConsistentWhitespace  = @{
    #         Enable                          = $true
    #         CheckInnerBrace                 = $true
    #         CheckOpenBrace                  = $true
    #         CheckOpenParen                  = $true
    #         CheckOperator                   = $true
    #         CheckPipe                       = $true
    #         CheckPipeForRedundantWhitespace = $false
    #         CheckSeparator                  = $true
    #         CheckParameter                  = $false
    #         IgnoreAssignmentOperatorInsideHashTable = $true
    #     }
    #
    #     PSAlignAssignmentStatement = @{
    #         Enable         = $false
    #         CheckHashtable = $true
    #     }
    #
    #     PSUseCorrectCasing     = @{
    #         Enable             = $true
    #     }
    # }
    CustomRulePath = "~/.dotfiles/pwsh/rules.psm1"
}



