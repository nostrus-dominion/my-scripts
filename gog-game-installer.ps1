# Dependency check.
$dependencies = @('Get-ChildItem', 'Sort-Object', 'Split-Path', 'Start-Process', 'Write-Host')
$missingDependencies = @()
foreach ($dependency in $dependencies) {
    if (-not (Get-Command $dependency -ErrorAction SilentlyContinue)) {
        $missingDependencies += $dependency
    }
}
if ($missingDependencies.Count -gt 0) {
    foreach ($dependency in $missingDependencies) {
        [Console]::Error.WriteLine("ERROR: Required command '$dependency' is unavailable.")
    }
    exit 1
}

# this script is desinged for gog games with multiple dlcs and installer files

$folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$installers = Get-ChildItem -Path $folder -Filter *.exe | Sort-Object Name

foreach ($installer in $installers) {
    Write-Host "Installing $($installer.Name) to $folder..."
    Start-Process -FilePath $installer.FullName -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/DIR=`"$folder`"" -Wait
}
