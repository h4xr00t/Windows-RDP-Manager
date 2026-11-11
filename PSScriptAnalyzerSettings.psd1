@{
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Colored console output is intentional in this project.
        'PSAvoidUsingWriteHost'

        # Functions are self-documenting; the noun reflects real scope (e.g. -Files).
        'PSUseSingularNouns'

        # These scripts are admin entry points, not interactive cmdlets;
        # they already log and prompt explicitly.
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules = @{
        PSReviewUnusedParameter = @{ Enabled = $true }
    }
}