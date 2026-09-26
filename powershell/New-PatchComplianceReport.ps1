#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Reports last-patch and last-reboot age for every enabled domain computer.
.DESCRIPTION
    For each enabled computer in AD, queries the most recent hotfix install
    date (Win32_QuickFixEngineering) and last boot time (Win32_OperatingSystem)
    over CIM. A host is compliant when both are within their thresholds.
    Results are written to CSV and also returned as objects.
.EXAMPLE
    .\New-PatchComplianceReport.ps1 -PatchDaysThreshold 30 -RebootDaysThreshold 14
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 365)]
    [int]$PatchDaysThreshold = 30,
    [ValidateRange(1, 365)]
    [int]$RebootDaysThreshold = 14,
    [string]$OutputPath = ".\patch-compliance-$(Get-Date -Format 'yyyy-MM-dd').csv"
)

function Get-LastHotfixDate {
    param([string]$ComputerName)
    $dates = foreach ($hotfix in Get-CimInstance -ComputerName $ComputerName -ClassName Win32_QuickFixEngineering -ErrorAction Stop) {
        $parsed = [datetime]::MinValue
        # InstalledOn comes back as a string over CIM and can be empty.
        if ($hotfix.InstalledOn -and [datetime]::TryParse([string]$hotfix.InstalledOn, [ref]$parsed)) { $parsed }
    }
    $dates | Sort-Object -Descending | Select-Object -First 1
}

$now = Get-Date
$computers = Get-ADComputer -Filter 'Enabled -eq $true'

$results = foreach ($computer in $computers) {
    try {
        $lastBoot = (Get-CimInstance -ComputerName $computer.Name -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
        $lastPatch = Get-LastHotfixDate -ComputerName $computer.Name
        $daysSinceBoot = [int]($now - $lastBoot).TotalDays
        $daysSincePatch = if ($lastPatch) { [int]($now - $lastPatch).TotalDays } else { $null }

        [PSCustomObject]@{
            ComputerName   = $computer.Name
            LastPatchDate  = $lastPatch
            DaysSincePatch = $daysSincePatch
            LastBootUpTime = $lastBoot
            DaysSinceBoot  = $daysSinceBoot
            Compliant      = ($null -ne $daysSincePatch) -and ($daysSincePatch -le $PatchDaysThreshold) -and ($daysSinceBoot -le $RebootDaysThreshold)
            Status         = 'Reachable'
        }
    }
    catch {
        [PSCustomObject]@{
            ComputerName   = $computer.Name
            LastPatchDate  = $null
            DaysSincePatch = $null
            LastBootUpTime = $null
            DaysSinceBoot  = $null
            Compliant      = $false
            Status         = "Unreachable: $($_.Exception.Message)"
        }
    }
}

$results | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Verbose "Report written to $OutputPath"
Write-Verbose "$(@($results | Where-Object { -not $_.Compliant }).Count) of $(@($results).Count) hosts non-compliant"
$results
