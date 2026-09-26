BeforeAll {
    $env:PSModulePath = (Join-Path $PSScriptRoot 'stubs') + [IO.Path]::PathSeparator + $env:PSModulePath
    Import-Module ActiveDirectory -Force

    # Get-CimInstance only exists on Windows; define a stub elsewhere so it can be mocked.
    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        function global:Get-CimInstance { param($ComputerName, $ClassName, $ErrorAction) }
    }

    $scripts = Join-Path $PSScriptRoot '..' 'powershell'
}

Describe 'New-BulkComputerCleanup' {
    BeforeEach {
        Mock Search-ADAccount {
            @(
                [PSCustomObject]@{ Name = 'OLD-PC1'; Enabled = $true; LastLogonDate = (Get-Date).AddDays(-200); DistinguishedName = 'CN=OLD-PC1' }
                [PSCustomObject]@{ Name = 'OLD-PC2'; Enabled = $false; LastLogonDate = (Get-Date).AddDays(-300); DistinguishedName = 'CN=OLD-PC2' }
            )
        }
        Mock Disable-ADAccount {}
    }

    It 'only reports by default' {
        $result = & "$scripts/New-BulkComputerCleanup.ps1"
        $result.Name | Should -Be 'OLD-PC1'
        $result.Action | Should -Be 'Reported'
        Should -Invoke Disable-ADAccount -Times 0 -Exactly
    }

    It 'skips accounts that are already disabled' {
        $result = & "$scripts/New-BulkComputerCleanup.ps1"
        $result.Name | Should -Not -Contain 'OLD-PC2'
    }

    It 'disables stale accounts with -Disable' {
        $result = & "$scripts/New-BulkComputerCleanup.ps1" -Disable -Confirm:$false
        $result.Action | Should -Be 'Disabled'
        Should -Invoke Disable-ADAccount -Times 1 -Exactly -ParameterFilter { $Identity -eq 'CN=OLD-PC1' }
    }

    It 'changes nothing with -WhatIf' {
        & "$scripts/New-BulkComputerCleanup.ps1" -Disable -WhatIf | Out-Null
        Should -Invoke Disable-ADAccount -Times 0 -Exactly
    }
}

Describe 'New-PatchComplianceReport' {
    BeforeEach {
        $out = Join-Path $TestDrive 'report.csv'
        Mock Get-ADComputer { @([PSCustomObject]@{ Name = 'PC1' }) }
    }

    It 'marks a recently patched and rebooted host compliant' {
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } { [PSCustomObject]@{ LastBootUpTime = (Get-Date).AddDays(-2) } }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } {
            [PSCustomObject]@{ InstalledOn = (Get-Date).AddDays(-40).ToString() }
            [PSCustomObject]@{ InstalledOn = (Get-Date).AddDays(-5).ToString() }
        }
        $r = & "$scripts/New-PatchComplianceReport.ps1" -OutputPath $out
        $r.DaysSincePatch | Should -Be 5
        $r.Compliant | Should -BeTrue
        Test-Path $out | Should -BeTrue
    }

    It 'flags a host whose newest patch is older than the threshold' {
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } { [PSCustomObject]@{ LastBootUpTime = (Get-Date).AddDays(-1) } }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } { [PSCustomObject]@{ InstalledOn = (Get-Date).AddDays(-60).ToString() } }
        (& "$scripts/New-PatchComplianceReport.ps1" -OutputPath $out).Compliant | Should -BeFalse
    }

    It 'flags a host with no readable hotfix dates' {
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } { [PSCustomObject]@{ LastBootUpTime = (Get-Date).AddDays(-1) } }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_QuickFixEngineering' } { [PSCustomObject]@{ InstalledOn = '' } }
        (& "$scripts/New-PatchComplianceReport.ps1" -OutputPath $out).Compliant | Should -BeFalse
    }

    It 'reports unreachable hosts instead of failing' {
        Mock Get-CimInstance { throw 'RPC server unavailable' }
        $r = & "$scripts/New-PatchComplianceReport.ps1" -OutputPath $out
        $r.Status | Should -BeLike 'Unreachable*'
        $r.Compliant | Should -BeFalse
    }
}

Describe 'Get-DisabledAccountAudit' {
    BeforeEach {
        Mock Get-ADUser {
            @(
                [PSCustomObject]@{ SamAccountName = 'jdoe'; Name = 'J Doe'; MemberOf = @('CN=Domain Admins', 'CN=Finance') }
                [PSCustomObject]@{ SamAccountName = 'asmith'; Name = 'A Smith'; MemberOf = @('CN=Sales') }
                [PSCustomObject]@{ SamAccountName = 'nogroups'; Name = 'No Groups'; MemberOf = @() }
            )
        }
        Mock Get-ADGroup { [PSCustomObject]@{ Name = ($Identity -replace '^CN=', '') } }
    }

    It 'skips accounts with no group memberships' {
        (& "$scripts/Get-DisabledAccountAudit.ps1").SamAccountName | Should -Not -Contain 'nogroups'
    }

    It 'marks privileged group membership as high priority' {
        $r = & "$scripts/Get-DisabledAccountAudit.ps1"
        ($r | Where-Object SamAccountName -eq 'jdoe').Priority | Should -Be 'High'
        ($r | Where-Object SamAccountName -eq 'jdoe').PrivilegedGroups | Should -Be 'Domain Admins'
        ($r | Where-Object SamAccountName -eq 'asmith').Priority | Should -Be 'Normal'
    }
}
