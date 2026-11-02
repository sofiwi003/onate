param(
    [string]$Dispositivo
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & (Join-Path $PSScriptRoot 'preparar.ps1')
    if ($Dispositivo) {
        & flutter run -d $Dispositivo
    } else {
        & flutter run
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter no pudo iniciar la aplicación. Revisa el error anterior.'
    }
} finally {
    Pop-Location
}
