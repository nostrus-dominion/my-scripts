# .SYNOPSIS
# find_ducplicate_files.ps1 finds duplicate files based on hash values.
 
# .DESCRIPTION
# Prompts for entering file path. Shows duplicate files for selection. 
# Selected files will be moved to new folder C:\Duplicates_Date for further review.

# .EXAMPLE
# Open PowerShell. Nagivate to the file location. Type .\find_duplicate_files.ps1 OR
# Open PowerShell ISE. Open find_duplicate.ps1 and hit F5.
 
# .NOTES
# Author: Patrick Gruenauer | Microsoft MVP on PowerShell [2018-2020]
# Web: https://sid-500.com

# Edited by Paul Musselman on 4/29/2022
# Modified Line 47 from MM/DD/YY to MM_dd_yyyy as "/" character is not allowed in filenames

############# Find Duplicate Files based on Hash Value ###############
''
$filepath = Read-Host 'Enter file path for searching duplicate files (e.g. C:\Temp, C:\)'

If (Test-Path $filepath) {
''
Write-Warning 'Searching for duplicates ... Please wait ...'

$duplicates = Get-ChildItem $filepath -File -Recurse `
-ErrorAction SilentlyContinue | 
Get-FileHash | 
Group-Object -Property Hash |
Where-Object Count -GT 1

If ($duplicates.count -lt 1)

{
    Write-Warning 'No duplicates found.'
    Break  ''
}

else {
    Write-Warning "Duplicates found."
    $result = foreach ($d in $duplicates) 
    { 
    $d.Group | Select-Object -Property Path, Hash   
    } 

$date = Get-Date -Format "MM_dd_yyyy"
$itemstomove = $result | 
Out-GridView -Title `
"Select files (CTRL for multiple) and press OK. Selected files will be moved to C:\Duplicates_$date" `
-PassThru 

If ($itemstomove)

{
New-Item -ItemType Directory `
-Path $env:SystemDrive\Duplicates_$date -Force
Move-Item $itemstomove.Path `
-Destination $env:SystemDrive\Duplicates_$date -Force
''
Write-Warning `
"Mission accomplished. Selected files moved to C:\Duplicates_$date"

Start-Process "C:\Duplicates_$date"
}

else 
{
Write-Warning "Operation aborted. No files selected."
}
}
}
else 
{
    Write-Warning `
    "Folder not found. Use full path to directory e.g. C:\photos\patrick"
}