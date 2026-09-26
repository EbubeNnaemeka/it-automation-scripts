#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Finds disabled AD user accounts that still hold group memberships.
.DESCRIPTION
    Accounts are often disabled at offboarding but never removed from their
    groups. Disabled accounts in privileged groups are flagged high priority.
.EXAMPLE
    .\Get-DisabledAccountAudit.ps1 | Format-Table -AutoSize
#>
[CmdletBinding()]
param(
    [string[]]$PrivilegedGroupPattern = @('Admins', 'Operators', 'Enterprise', 'Schema')
)

$pattern = ($PrivilegedGroupPattern | ForEach-Object { [regex]::Escape($_) }) -join '|'

foreach ($user in Get-ADUser -Filter 'Enabled -eq $false' -Properties MemberOf) {
    if (-not $user.MemberOf) { continue }

    $groups = @($user.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name })
    $privileged = @($groups | Where-Object { $_ -match $pattern })

    [PSCustomObject]@{
        SamAccountName   = $user.SamAccountName
        Name             = $user.Name
        GroupCount       = $groups.Count
        Groups           = $groups -join '; '
        PrivilegedGroups = $privileged -join '; '
        Priority         = if ($privileged.Count -gt 0) { 'High' } else { 'Normal' }
    }
}
