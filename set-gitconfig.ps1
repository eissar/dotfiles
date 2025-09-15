Write-Progress -Activity "Updating .gitconfig" -Status "Starting..." -PercentComplete 0
try
{
    Set-Content -Path "$env:USERPROFILE/.gitconfig" -Value @"
[include]
   path = $USERPROFILE\\.dotfiles\\.gitconfig
"@
    Write-Host " ✔️Successfully updated .gitconfig" -ForegroundColor Green
} catch
{
    Write-Host " ✖️Failed: $_" -ForegroundColor Red
}
