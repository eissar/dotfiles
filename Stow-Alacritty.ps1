$ErrorActionPreference = "Stop"

$df_path = "~/dotfiles/alacritty"
$df_path_exist = Test-Path $df_path
if  (!$df_path_exist) {
    write-host 'run cd ~ && git clone eissar/dotfiles and try again'
}

try { Copy-Item -Recurse $df_path $env:APPDATA } catch [System.IO.IOException] {
    write-host "Err" $_.FullyQualifiedErrorId
    write-host "try:"
    write-host '    rm -rf $env:APPDATA/alacritty'
    write-host 'and try again'
}
