# IT Automation Scripts

[![ci](https://github.com/EbubeNnaemeka/it-automation-scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/EbubeNnaemeka/it-automation-scripts/actions/workflows/ci.yml)

**Status:** PowerShell scripts lint-clean with 10 passing Pester unit tests; Ansible playbook lint-clean at the `production` profile and its Linux play runs in CI. Windows targets pending the AD lab.

A small collection of PowerShell and Ansible automation tools built against the [Active Directory lab](https://github.com/EbubeNnaemeka/active-directory-lab), aimed at replacing repetitive manual sysadmin tasks with scripted, auditable processes.

## Scripts

| Script | Purpose |
|---|---|
| [`powershell/New-PatchComplianceReport.ps1`](powershell/New-PatchComplianceReport.ps1) | Queries all domain-joined computers for last patch/reboot date and flags anything overdue past a configurable threshold |
| [`powershell/Get-DisabledAccountAudit.ps1`](powershell/Get-DisabledAccountAudit.ps1) | Finds stale/disabled AD accounts that still have active group memberships — a common audit finding |
| [`powershell/New-BulkComputerCleanup.ps1`](powershell/New-BulkComputerCleanup.ps1) | Identifies and reports (dry-run by default) computer objects that haven't authenticated in 90+ days, a common "stale AD object" problem |
| [`ansible/site.yml`](ansible/site.yml) | Cross-platform patch-status inventory playbook for a mixed Windows/Linux environment |

## Why this project matters

Sysadmin hiring managers specifically look for automation mindset over point-and-click administration. A public GitHub repo with working, documented scripts is a stronger signal than a resume line claiming "PowerShell scripting" — this is proof, not a claim.

## Testing

The scripts need the RSAT ActiveDirectory module, which only exists on Windows. The tests load a stand-in module ([`tests/stubs`](tests/stubs)) and mock every AD and CIM call, so they run anywhere PowerShell 7 does, including CI:

```powershell
Invoke-Pester ./tests -Output Detailed
```

They cover the logic that matters: stale accounts are reported but not touched unless `-Disable` is passed, `-WhatIf` changes nothing, already-disabled accounts are skipped, the newest hotfix date is used (not the oldest), unreachable hosts are reported instead of crashing the run, and privileged group membership is flagged.

**Bugs these changes fixed:**
- `New-BulkComputerCleanup.ps1` compared the raw `LastLogonTimestamp` (a 64-bit file time) to a `DateTime`, so the filter never matched. It now uses `Search-ADAccount -AccountInactive`, and disabling goes through `ShouldProcess`, so `-WhatIf`/`-Confirm` work.
- `New-PatchComplianceReport.ps1` only checked uptime, not patches. It now reads the newest hotfix install date.
- The Ansible playbook checked `ansible_facts` with fact gathering turned off, so the Linux tasks always skipped. Verified the fixed pending-update count against a deliberately outdated Debian image (44 upgradable packages detected).

## Usage

Each script includes inline comment-based help. Example:
```powershell
Get-Help .\powershell\New-PatchComplianceReport.ps1 -Full
```

## Resume bullet (use once you have completed and verified the lab)

> Wrote PowerShell and Ansible automation to generate patch-compliance and stale-account audit reports with Pester unit tests (mocked AD/CIM) and CI linting, replacing manual review with scheduled scripted reporting.

## Repo contents

```
├── README.md
├── .github/workflows/ci.yml
├── powershell/
│   ├── New-PatchComplianceReport.ps1
│   ├── Get-DisabledAccountAudit.ps1
│   └── New-BulkComputerCleanup.ps1
├── tests/
│   ├── Scripts.Tests.ps1
│   └── stubs/ActiveDirectory/
└── ansible/
    ├── site.yml
    ├── inventory.ini
    └── tests/inventory.local.ini
```

---

Part of my homelab portfolio: **[ebube-nnaemeka.pages.dev](https://ebube-nnaemeka.pages.dev)** · [All projects](https://github.com/EbubeNnaemeka)
