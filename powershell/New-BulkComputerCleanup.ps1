<#
.SYNOPSIS
    Identifies stale computer objects in AD (dry-run by default).
.DESCRIPTION
    Flags computer objects that haven't authenticated to the domain in
    90+ days (configurable), a common source of AD hygiene findings.
    Defaults to reporting only — pass -Disable to actually disable flagged
    objects, which still requires -Confirm since this is a destructive action.
.EXAMPLE
    .\New-BulkComputerCleanup.ps1 -DaysStale 90
.EXAMPLE
    .\New-BulkComputerCleanup.ps1 -DaysStale 90 -Disable -Confirm
#>
#Requires -Modules ActiveDirectory

param(
    [int]$DaysStale = 90,
    [switch]$Disable,
    [switch]$Confirm
)

$cutoffDate = (Get-Date).AddDays(-$DaysStale)
$staleComputers = Get-ADComputer -Filter { LastLogonTimestamp -lt $cutoffDate -and Enabled -eq $true } `
    -Properties LastLogonTimestamp |
    Select-Object Name, DistinguishedName, @{N = 'LastLogon'; E = { [DateTime]::FromFileTime($_.LastLogonTimestamp) } }

Write-Host "Found $($staleComputers.Count) computer objects with no logon in $DaysStale+ days:"
$staleComputers | Format-Table -AutoSize

if ($Disable -and $Confirm) {
    foreach ($c in $staleComputers) {
        Disable-ADAccount -Identity $c.DistinguishedName
        Write-Host "Disabled: $($c.Name)"
    }
}
elseif ($Disable -and -not $Confirm) {
    Write-Warning "Run with -Disable -Confirm to actually disable these accounts. This was a dry run only."
}
