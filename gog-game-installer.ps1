# this script is desinged for gog games with multiple dlcs

$folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$installers = Get-ChildItem -Path $folder -Filter *.exe | Sort-Object Name

foreach ($installer in $installers) {
    Write-Host "Installing $($installer.Name) to $folder..."
    Start-Process -FilePath $installer.FullName -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/DIR=`"$folder`"" -Wait
}
