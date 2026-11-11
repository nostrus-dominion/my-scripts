# Get-ComputerDetails.ps1
# Local Windows event log inventory for troubleshooting and auditing.
# Based on Get-ComputerDetails by Joe Bialek:
# https://github.com/clymb3r/PowerShell

[CmdletBinding()]
param(
    [ValidateRange(1, 10000)]
    [int]$MaxEvents = 500,

    [switch]$ToString
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get events without failing the entire report when a log is unavailable.
function Read-EventLog {
    param(
        [string]$LogName,
        [int[]]$EventId,
        [int]$Limit
    )

    try {
        @(Get-WinEvent -FilterHashtable @{
            LogName = $LogName
            Id = $EventId
        } -MaxEvents $Limit -ErrorAction Stop)
    }
    catch {
        Write-Warning "Cannot read '$LogName': $($_.Exception.Message)"
        @()
    }
}

# Build a predictable, compact record from each event.
function Format-EventRecord {
    param(
        [object[]]$Events,
        [string]$Category
    )

    foreach ($Event in $Events) {
        $Message = if ($null -ne $Event.Message) {
            ($Event.Message -replace '\s+', ' ').Trim()
        }
        else {
            ''
        }

        [pscustomobject]@{
            Category = $Category
            EventId = $Event.Id
            Time = $Event.TimeCreated
            Provider = $Event.ProviderName
            Computer = $Event.MachineName
            Message = $Message
        }
    }
}

# Security events: successful logons and explicit credential use.
$Logons = Read-EventLog -LogName 'Security' -EventId @(4624, 4648) -Limit $MaxEvents

# Application control and PowerShell operational events.
$AppLocker = Read-EventLog -LogName 'Microsoft-Windows-AppLocker/EXE and DLL' -EventId @(8002) -Limit $MaxEvents
$PowerShell = Read-EventLog -LogName 'Microsoft-Windows-PowerShell/Operational' -EventId @(4100, 4103, 4104) -Limit $MaxEvents

$Report = @(
    Format-EventRecord -Events $Logons -Category 'Logon'
    Format-EventRecord -Events $AppLocker -Category 'AppLocker'
    Format-EventRecord -Events $PowerShell -Category 'PowerShell'
) | Sort-Object Time -Descending

if ($ToString) {
    $Report | Format-Table Time, Category, EventId, Provider, Computer -AutoSize | Out-String -Width 200
}
else {
    $Report
}
