<#
.SYNOPSIS
Finds duplicate files by SHA-256 hash.

.DESCRIPTION
Press Enter to scan PowerShell's current folder recursively, or enter another
folder. Select duplicates in Out-GridView to move them to Duplicates_MM_dd_yyyy
on the Windows system drive for review.

.EXAMPLE
.\find_duplicate_files.ps1

.NOTES
Original author: Patrick Gruenauer | Microsoft MVP on PowerShell [2018-2020]
Website: https://sid-500.com
Edited by Paul Musselman on 4/29/2022 to use underscores in the folder date.
#>

$dependencies = @(
    'ForEach-Object', 'Get-ChildItem', 'Get-Date', 'Get-FileHash', 'Get-Item',
    'Get-Location', 'Group-Object', 'Join-Path', 'Move-Item', 'New-Item',
    'Out-GridView', 'Read-Host', 'Select-Object', 'Start-Process',
    'Where-Object', 'Write-Warning'
)

$missingDependencies = foreach ($dependency in $dependencies) {
    if (-not (Get-Command $dependency -ErrorAction SilentlyContinue)) {
        $dependency
    }
}
if ($missingDependencies) {
    foreach ($dependency in $missingDependencies) {
        [Console]::Error.WriteLine("ERROR: Required command '$dependency' is unavailable.")
    }
    exit 1
}

$currentFolder = Get-Location
$scanPath = Read-Host "Folder to scan (press Enter for $($currentFolder.Path))"
if ([string]::IsNullOrWhiteSpace($scanPath)) {
    $scanPath = '.'
} else {
    $scanPath = $scanPath.Trim().Trim('"')
}

try {
    $folder = Get-Item -LiteralPath $scanPath -Force -ErrorAction Stop
} catch {
    Write-Warning "Folder could not be opened: $scanPath. $($_.Exception.Message)"
    return
}
if (-not $folder.PSIsContainer -or $folder.PSProvider.Name -ne 'FileSystem') {
    Write-Warning "Enter a file system folder path: $scanPath"
    return
}

Write-Warning "Searching for duplicates in $($folder.FullName) ..."
$duplicates = @(
    Get-ChildItem -LiteralPath $folder.FullName -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 } |
        Group-Object -Property Hash |
        Where-Object Count -GT 1
)

if ($duplicates.Count -eq 0) {
    Write-Warning 'No duplicates found.'
    return
}

$result = foreach ($group in $duplicates) {
    $group.Group | Select-Object -Property Path, Hash
}

$date = Get-Date -Format 'MM_dd_yyyy'
$destination = Join-Path -Path "$env:SystemDrive\" -ChildPath "Duplicates_$date"
$itemsToMove = $result |
    Out-GridView -Title "Select files to move to $destination (Ctrl-click for multiple)" -PassThru

if (-not $itemsToMove) {
    Write-Warning 'No files selected.'
    return
}

try {
    $null = New-Item -ItemType Directory -Path $destination -Force -ErrorAction Stop
} catch {
    Write-Warning "Could not create $destination. $($_.Exception.Message)"
    return
}

$movedCount = 0
foreach ($item in $itemsToMove) {
    try {
        Move-Item -LiteralPath $item.Path -Destination $destination -ErrorAction Stop
        $movedCount++
    } catch {
        Write-Warning "Could not move '$($item.Path)': $($_.Exception.Message)"
    }
}

if ($movedCount -gt 0) {
    Write-Warning "Moved $movedCount file(s) to $destination."
    Start-Process -FilePath $destination
}
