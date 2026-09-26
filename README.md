# IT Automation Scripts

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

## Usage

Each script includes inline comment-based help. Example:
```powershell
Get-Help .\powershell\New-PatchComplianceReport.ps1 -Full
```

## Resume bullet (use once you have completed and verified the lab)

> Wrote PowerShell and Ansible automation to generate patch-compliance and stale-account audit reports across a simulated [N]-endpoint domain, replacing manual review with scheduled scripted reporting.

## Repo contents

```
├── README.md
├── powershell/
│   ├── New-PatchComplianceReport.ps1
│   ├── Get-DisabledAccountAudit.ps1
│   └── New-BulkComputerCleanup.ps1
└── ansible/
    ├── site.yml
    └── inventory.ini
```
