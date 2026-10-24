# Convert-FileToByteArrayString.ps1
# Read a local file and print its bytes as comma-separated decimal values.
# Adapted from clymb3r/PowerShell (original author attribution retained).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$File
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the file before attempting to read it.
$FilePath = (Resolve-Path -LiteralPath $File -ErrorAction Stop).ProviderPath

if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    throw "Not a file: $FilePath"
}

$Bytes = [System.IO.File]::ReadAllBytes($FilePath)
($Bytes | ForEach-Object { $_.ToString() }) -join ','
