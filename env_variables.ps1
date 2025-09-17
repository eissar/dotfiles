
# Set KOMOREBI_CONFIG_HOME environment variable
$path = Join-Path $HOME ".dotfiles"
[System.Environment]::SetEnvironmentVariable(
    "KOMOREBI_CONFIG_HOME",
    $path,
    "User"
)

$path = Join-Path $HOME ".dotfiles"
[System.Environment]::SetEnvironmentVariable(
    "WHKD_CONFIG_HOME",
    $path,
    "User"
)

