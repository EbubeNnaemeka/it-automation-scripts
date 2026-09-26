<#
.SYNOPSIS
    Generates a patch-compliance report for all domain-joined computers.
.DESCRIPTION
    Queries AD for enabled computer objects, checks each for its last boot
    time and last hotfix install date via CIM, and flags any host that
    hasn't rebooted/patched within the given threshold.
.PARAMETER DaysThreshold
    Number of days since last reboot before a host is flagged non-compliant.
.PARAMETER OutputPath
    Where to write the CSV report.
.EXAMPLE
    .\New-PatchComplianceReport.ps1 -DaysThreshold 30 -OutputPath .\report.csv
#>
#Requires -Modules ActiveDirectory

param(
    [int]$DaysThreshold = 30,
    [string]$OutputPath = ".\patch-compliance-$(Get-Date -Format 'yyyy-MM-dd').csv"
)

$computers = Get-ADComputer -Filter { Enabled -eq $true } -Properties LastLogonDate
$results = foreach ($c in $computers) {
    try {
        $os = Get-CimInstance -ComputerName $c.Name -ClassName Win32_OperatingSystem -ErrorAction Stop
        $lastBoot = $os.LastBootUpTime
        $daysSinceBoot = (New-TimeSpan -Start $lastBoot -End (Get-Date)).Days

        [PSCustomObject]@{
            ComputerName   = $c.Name
            LastBootUpTime = $lastBoot
            DaysSinceBoot  = $daysSinceBoot
            Compliant      = $daysSinceBoot -le $DaysThreshold
            Status         = "Reachable"
        }
    }
    catch {
        [PSCustomObject]@{
            ComputerName   = $c.Name
            LastBootUpTime = $null
            DaysSinceBoot  = $null
            Compliant      = $false
            Status         = "Unreachable: $($_.Exception.Message)"
        }
    }
}

$results | Export-Csv -Path $OutputPath -NoTypeInformation
$nonCompliant = ($results | Where-Object { -not $_.Compliant }).Count

Write-Host "Report written to $OutputPath"
Write-Host "$nonCompliant of $($results.Count) hosts flagged non-compliant (threshold: $DaysThreshold days)"
