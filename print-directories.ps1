## Powershell script designed to print all directories

## Version 0.5
## License: Open Source GPL
## Copyright: (c) 2023

# Prompt the user for the directory path
$directoryPath = Read-Host "Enter the directory path: "

# Get a sorted listing of files and directories in the specified directory
$listing = Get-ChildItem -Path $directoryPath | Sort-Object -Property Name -Descending

# Get the path to the user's desktop folder
$desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Directory List.txt")

# Save the sorted listing to a file called "Listing.txt" on the user's desktop
$listing | Out-File -FilePath $desktopPath -Force

# Open "Listing.txt" file on the user's desktop using Notepad
Start-Process notepad -ArgumentList $desktopPath -Wait

# Remove the "Listing.txt" file from the user's desktop after it's closed in Notepad
Remove-Item $desktopPath -Force

# Exit the script
Exit
