# Set your folder path
$folder = "C:\PATH\TO\GAME\FOLDER\"

$installers = Get-ChildItem -Path $folder -Filter *.exe | Sort-Object Name

foreach ($installer in $installers) {
    Write-Host "Installing $($installer.Name)..."
    Start-Process -FilePath $installer.FullName -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES" -Wait
}
