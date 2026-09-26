<#
.SYNOPSIS
    Audits disabled AD accounts that still hold active group memberships.
.DESCRIPTION
    A common security/compliance finding: accounts get disabled on offboarding
    but are never removed from privileged groups. This script flags that gap.
.EXAMPLE
    .\Get-DisabledAccountAudit.ps1 | Format-Table -AutoSize
#>
#Requires -Modules ActiveDirectory

$disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties MemberOf

foreach ($user in $disabledUsers) {
    if ($user.MemberOf.Count -gt 0) {
        $groups = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }

        [PSCustomObject]@{
            SamAccountName = $user.SamAccountName
            Name           = $user.Name
            GroupCount     = $groups.Count
            Groups         = ($groups -join "; ")
            Recommendation = if ($groups -match "Admins") {
                "HIGH PRIORITY - privileged group membership on disabled account"
            } else {
                "Remove from groups during next cleanup cycle"
            }
        }
    }
}
