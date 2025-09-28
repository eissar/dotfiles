#Requires -RunAsAdministrator

# Check if .CSX and .FSX are in $env:PATHEXT, and append if they don't exist
$pathExt = $env:PATHEXT -split ';'

if ('.CSX' -notin $pathExt) {
    $env:PATHEXT += ';.CSX'
    Write-Host 'Added .CSX to PATHEXT'
}

if ('.FSX' -notin $pathExt) {
    $env:PATHEXT += ';.FSX'
    Write-Host 'Added .FSX to PATHEXT'
}

# To make the change permanent, update the registry
[Environment]::SetEnvironmentVariable('PATHEXT', $env:PATHEXT, 'User')


cmd /c assoc .csx=csxfile
cmd /c "ftype csxfile=""C:\Users\eshaa\.dotnet\tools\dotnet-script.exe"" ""%1"""

cmd /c assoc .fsx=fsxfile
cmd /c "ftype csxfile=""C:\Users\eshaa\.dotnet\tools\dotnet-script.exe"" ""%1"""
