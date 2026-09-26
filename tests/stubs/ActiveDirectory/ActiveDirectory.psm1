# Stand-in for the RSAT ActiveDirectory module so scripts can be unit-tested
# on machines without it. Every function is replaced by a Pester Mock in tests.
function Get-ADComputer { param($Filter, $Properties) }
function Get-ADUser { param($Filter, $Properties) }
function Get-ADGroup { param($Identity) }
function Search-ADAccount { param([switch]$AccountInactive, [switch]$ComputersOnly, $TimeSpan) }
function Disable-ADAccount { param($Identity) }

Export-ModuleMember -Function *
