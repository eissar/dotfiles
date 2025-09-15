Write-Progress -Activity "Updating .gitconfig" -Status "Starting..." -PercentComplete 0
try
{
    $p = $env:USERPROFILE.Replace('\', '\\')
    Set-Content -Path "$env:USERPROFILE/.gitconfig" -Value @"
[include]
   path = $p\\.dotfiles\\.gitconfig
"@
    Write-Host " ✔️Successfully updated .gitconfig" -ForegroundColor Green
} catch
{
    Write-Host " ✖️Failed: $_" -ForegroundColor Red
}
