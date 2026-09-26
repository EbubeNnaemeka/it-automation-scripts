#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Finds stale computer accounts in AD and optionally disables them.
.DESCRIPTION
    Uses Search-ADAccount to find enabled computer accounts that have not
    authenticated within -DaysStale days. Reports only by default.
    With -Disable, each account is disabled through ShouldProcess, so
    -WhatIf and -Confirm work as expected.
.EXAMPLE
    .\New-BulkComputerCleanup.ps1 -DaysStale 90
.EXAMPLE
    .\New-BulkComputerCleanup.ps1 -DaysStale 90 -Disable -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateRange(1, 3650)]
    [int]$DaysStale = 90,
    [switch]$Disable
)

# LastLogonTimestamp only replicates every ~14 days, so treat results as approximate.
$stale = Search-ADAccount -AccountInactive -ComputersOnly -TimeSpan (New-TimeSpan -Days $DaysStale) |
    Where-Object { $_.Enabled }

foreach ($computer in $stale) {
    $action = 'Reported'
    if ($Disable -and $PSCmdlet.ShouldProcess($computer.Name, 'Disable stale computer account')) {
        Disable-ADAccount -Identity $computer.DistinguishedName
        $action = 'Disabled'
    }

    [PSCustomObject]@{
        Name              = $computer.Name
        LastLogonDate     = $computer.LastLogonDate
        DistinguishedName = $computer.DistinguishedName
        Action            = $action
    }
}

Write-Verbose "Found $(@($stale).Count) computer accounts inactive for $DaysStale+ days"
