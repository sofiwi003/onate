param(
    [string]$Dispositivo = 'chrome'
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & (Join-Path $PSScriptRoot 'preparar.ps1')
    & flutter run -d $Dispositivo
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter no pudo iniciar la aplicación. Revisa el error anterior.'
    }
} finally {
    Pop-Location
}
