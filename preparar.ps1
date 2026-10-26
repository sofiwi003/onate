$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & flutter pub get 2>&1 | Tee-Object -Variable taskPubOutput
    if ($LASTEXITCODE -ne 0) {
        if (($taskPubOutput -join "`n") -notmatch 'symlink support') {
            throw 'No se pudieron descargar las dependencias. Revisa el error anterior.'
        }

        # Las uniones de directorio funcionan sin permisos de administrador.
        $taskPlugins = Get-Content -LiteralPath '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
        foreach ($taskPlatform in @('windows', 'linux')) {
            $taskLinks = Join-Path $PSScriptRoot "$taskPlatform\flutter\ephemeral\.plugin_symlinks"
            New-Item -ItemType Directory -Path $taskLinks -Force | Out-Null
            foreach ($taskPlugin in $taskPlugins.plugins.$taskPlatform) {
                $taskLink = Join-Path $taskLinks $taskPlugin.name
                if (-not (Test-Path -LiteralPath $taskLink)) {
                    New-Item -ItemType Junction -Path $taskLink -Target $taskPlugin.path | Out-Null
                }
            }
        }
        & flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw 'Flutter no pudo preparar los plugins.'
        }
    }
    Write-Host 'Dependencias listas.'
} finally {
    Pop-Location
}
