<#
.SYNOPSIS
    AI CLI Sentinel - Gestor de seguridad para la cadena de suministro de IA.

.DESCRIPTION
    Herramienta de gobernanza que actualiza agentes de IA basándose en una lista blanca estricta.
    Implementa mitigaciones de seguridad como --ignore-scripts y puntos de restauración VSS.

.PARAMETER ConfigFile
    Ruta al archivo JSON con la lista blanca de agentes.

.PARAMETER Discover
    Modo de auditoría. Busca posibles agentes de IA instalados que NO están en la lista blanca.
    NO realiza cambios, solo reporta.

.PARAMETER CandidatesFile
    Ruta al archivo JSON usado para exportar candidatos detectados y revisar aprobaciones.

.PARAMETER ApproveCandidates
    Revisa candidatos previamente detectados y permite agregarlos de forma explícita a la lista blanca.

.PARAMETER AutoApproveCandidates
    Aprueba todos los candidatos pendientes sin interacción (uso controlado/no interactivo).

.PARAMETER BackupSecrets
    Realiza una copia de seguridad de .ssh y .config antes de operar.

.PARAMETER ReportPath
    Ruta al archivo JSON estructurado con el resultado de la ejecución.

.PARAMETER NoReport
    Deshabilita la escritura del reporte JSON.

.EXAMPLE
    # Ejecución estándar (Modo seguro, solo lista blanca)
    .\AI-CLI-Sentinel.ps1 -BackupSecrets

.EXAMPLE
    # Modo simulación (No hace nada, solo muestra qué haría)
    .\AI-CLI-Sentinel.ps1 -WhatIf

.EXAMPLE
    # Buscar nuevos agentes instalados (No actualiza, solo informa)
    .\AI-CLI-Sentinel.ps1 -Discover
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
param (
    [string]$ConfigFile = "$PSScriptRoot\agents.allowlist.json",
    [switch]$Discover,
    [switch]$BackupSecrets,
    [string]$LogPath = "$HOME\Desktop\AI_Sentinel_Log.txt",
    [string]$CandidatesFile = "$PSScriptRoot\agents.candidates.json",
    [switch]$ApproveCandidates,
    [switch]$AutoApproveCandidates,
    [string]$ReportPath = "$HOME\Desktop\AI_Sentinel_Report.json",
    [switch]$NoReport
)

$ErrorActionPreference = "Stop"
$RunStartedAt = Get-Date

function Write-Log {
    param([string]$Message, [string]$Color="White", [string]$Level="INFO")

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$TimeStamp] [$Level] $Message"
    Write-Host $Line -ForegroundColor $Color

    if ($WhatIfPreference) {
        return
    }

    $Line | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

function Test-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Save-JsonFile {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $json = $Object | ConvertTo-Json -Depth 10
    $json | Set-Content -Path $Path -Encoding UTF8
}

function New-CandidatesDocument {
    return [ordered]@{
        generatedAt = (Get-Date).ToString("o")
        npm = @()
    }
}

function ConvertTo-NpmName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    return $Name.Trim().ToLowerInvariant()
}

function Test-NpmPackageName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    return ($Name -match '^(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$')
}

function Get-MeaningfulCommandLines {
    param([object[]]$Lines)

    $meaningful = @()
    foreach ($line in $Lines) {
        $text = "$line".TrimEnd()
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($text -match '^\s*[-\\|/]\s*$') { continue }
        if ($text -match '^\s*[-\s]{3,}$') { continue }
        $meaningful += $text
    }

    return $meaningful
}

function Write-CommandOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prefix,
        [Parameter(Mandatory=$true)]
        [object[]]$Lines
    )

    foreach ($text in (Get-MeaningfulCommandLines -Lines $Lines)) {
        Write-Log "$Prefix$text" -Color Gray
    }
}

function New-OperationResult {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Manager,
        [Parameter(Mandatory=$true)]
        [string]$Status,
        [string]$InstalledVersionBefore,
        [string]$AvailableVersionBefore,
        [string]$InstalledVersionAfter,
        [bool]$Changed = $false,
        [string[]]$Notes = @()
    )

    return [pscustomobject][ordered]@{
        name = $Name
        manager = $Manager
        status = $Status
        installedVersionBefore = $InstalledVersionBefore
        availableVersionBefore = $AvailableVersionBefore
        installedVersionAfter = $InstalledVersionAfter
        changed = $Changed
        timestamp = (Get-Date).ToString("o")
        notes = @($Notes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
}

function Format-VersionValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "n/a"
    }

    return $Value
}

function Get-OperationCounts {
    param([object[]]$Results)

    $counts = [ordered]@{
        updated = 0
        'would-update' = 0
        'already-current' = 0
        'not-installed' = 0
        failed = 0
        unknown = 0
    }

    foreach ($result in $Results) {
        if ($counts.Contains($result.status)) {
            $counts[$result.status]++
        }
    }

    return $counts
}

function Write-OperationSummary {
    param([object[]]$Results)

    foreach ($result in $Results) {
        $before = Format-VersionValue -Value $result.installedVersionBefore
        if ($result.status -eq 'would-update') {
            $after = Format-VersionValue -Value $result.availableVersionBefore
        } else {
            $after = Format-VersionValue -Value $result.installedVersionAfter
        }

        Write-Log ("Resultado | {0} | {1} | {2} -> {3} | {4}" -f $result.manager.ToUpperInvariant(), $result.name, $before, $after, $result.status) -Color Gray
        foreach ($note in $result.notes) {
            Write-Log ("Nota | {0} | {1}" -f $result.name, $note) -Color DarkGray
        }
    }

    $counts = Get-OperationCounts -Results $Results
    Write-Log ("Resumen: updated={0}, would-update={1}, already-current={2}, not-installed={3}, failed={4}, unknown={5}" -f $counts['updated'], $counts['would-update'], $counts['already-current'], $counts['not-installed'], $counts['failed'], $counts['unknown']) -Color Cyan
    return $counts
}

function Write-RunReport {
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Results,
        [Parameter(Mandatory=$true)]
        [datetime]$StartedAt,
        [Parameter(Mandatory=$true)]
        [datetime]$EndedAt,
        [Parameter(Mandatory=$true)]
        [hashtable]$Counts,
        [Parameter(Mandatory=$true)]
        [int]$ExitCode
    )

    if ($NoReport) {
        Write-Log "Reporte JSON omitido por -NoReport." -Color DarkGray
        return $true
    }

    if ($WhatIfPreference) {
        Write-Log "Reporte JSON omitido en -WhatIf para evitar efectos laterales." -Color DarkGray
        return $true
    }

    $report = [ordered]@{
        reportVersion = '1.0'
        startedAt = $StartedAt.ToString('o')
        endedAt = $EndedAt.ToString('o')
        durationSeconds = [Math]::Round(($EndedAt - $StartedAt).TotalSeconds, 2)
        exitCode = $ExitCode
        whatIf = [bool]$WhatIfPreference
        configFile = $ConfigFile
        logPath = $LogPath
        counts = $Counts
        results = @($Results)
    }

    try {
        Save-JsonFile -Object $report -Path $ReportPath
        Write-Log "Reporte JSON escrito en: $ReportPath" -Color Green
        return $true
    } catch {
        Write-Log "No se pudo escribir reporte JSON en $($ReportPath): $_" -Color Yellow -Level WARN
        return $false
    }
}

function Get-NpmInstalledPackageInfo {
    param([string]$Name)

    try {
        $json = npm list -g $Name --depth=0 --json 2>$null
        if (-not $json) {
            return [pscustomobject]@{
                querySucceeded = $false
                installed = $false
                installedVersion = $null
                availableVersion = $null
                notes = @('npm list no devolvió salida utilizable.')
            }
        }

        $parsed = $json | ConvertFrom-Json
        $packageProperty = $null
        if ($parsed.dependencies) {
            $packageProperty = $parsed.dependencies.PSObject.Properties[$Name]
        }

        if ($packageProperty) {
            return [pscustomobject]@{
                querySucceeded = $true
                installed = $true
                installedVersion = "$($packageProperty.Value.version)"
                availableVersion = $null
                notes = @()
            }
        }

        return [pscustomobject]@{
            querySucceeded = $true
            installed = $false
            installedVersion = $null
            availableVersion = $null
            notes = @()
        }
    } catch {
        return [pscustomobject]@{
            querySucceeded = $false
            installed = $false
            installedVersion = $null
            availableVersion = $null
            notes = @("No se pudo consultar npm list: $_")
        }
    }
}

function Get-NpmLatestVersion {
    param([string]$Name)

    try {
        $output = @(npm view $Name version 2>&1)
        $exitCode = $LASTEXITCODE
        $lines = Get-MeaningfulCommandLines -Lines $output
        $version = $lines | Select-Object -Last 1

        if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($version)) {
            return [pscustomobject]@{
                querySucceeded = $false
                version = $null
                notes = @('No se pudo consultar npm view para la versión más reciente.') + @($lines)
            }
        }

        return [pscustomobject]@{
            querySucceeded = $true
            version = $version.Trim()
            notes = @()
        }
    } catch {
        return [pscustomobject]@{
            querySucceeded = $false
            version = $null
            notes = @("No se pudo consultar npm view: $_")
        }
    }
}

function Get-WingetInstalledPackageInfo {
    param([string]$Id)

    try {
        $output = @(winget list --id $Id --exact --accept-source-agreements --disable-interactivity 2>&1)
        $exitCode = $LASTEXITCODE
        $lines = Get-MeaningfulCommandLines -Lines $output
        $joined = $lines -join [System.Environment]::NewLine
        $escapedId = [regex]::Escape($Id)
        $row = $lines | Where-Object { $_ -match "(^|\s)$escapedId(\s|$)" } | Select-Object -Last 1

        if ($row) {
            $rowTrimmed = $row.Trim()
            $patternWithAvailable = "^(?<name>.+?)\s+$escapedId\s+(?<installed>\S+)\s+(?<available>\S+)\s+(?<source>\S+)$"
            $patternWithoutAvailable = "^(?<name>.+?)\s+$escapedId\s+(?<installed>\S+)\s+(?<source>\S+)$"

            if ($rowTrimmed -match $patternWithAvailable) {
                return [pscustomobject]@{
                    querySucceeded = $true
                    installed = $true
                    installedVersion = $Matches.installed
                    availableVersion = $(if ([string]::IsNullOrWhiteSpace($Matches.available) -or $Matches.available -eq '-') { $null } else { $Matches.available })
                    parseSucceeded = $true
                    notes = @()
                }
            }

            if ($rowTrimmed -match $patternWithoutAvailable) {
                return [pscustomobject]@{
                    querySucceeded = $true
                    installed = $true
                    installedVersion = $Matches.installed
                    availableVersion = $null
                    parseSucceeded = $true
                    notes = @()
                }
            }

            return [pscustomobject]@{
                querySucceeded = $true
                installed = $true
                installedVersion = $null
                availableVersion = $null
                parseSucceeded = $false
                notes = @('La salida de winget list no se pudo parsear con suficiente certeza.') + @($lines)
            }
        }

        if ($joined -match 'No installed package found matching input criteria') {
            return [pscustomobject]@{
                querySucceeded = $true
                installed = $false
                installedVersion = $null
                availableVersion = $null
                parseSucceeded = $true
                notes = @()
            }
        }

        if ($exitCode -eq 0) {
            return [pscustomobject]@{
                querySucceeded = $true
                installed = $false
                installedVersion = $null
                availableVersion = $null
                parseSucceeded = $true
                notes = @()
            }
        }

        return [pscustomobject]@{
            querySucceeded = $false
            installed = $false
            installedVersion = $null
            availableVersion = $null
            parseSucceeded = $false
            notes = @('winget list devolvió error al consultar el paquete.') + @($lines)
        }
    } catch {
        return [pscustomobject]@{
            querySucceeded = $false
            installed = $false
            installedVersion = $null
            availableVersion = $null
            parseSucceeded = $false
            notes = @("No se pudo consultar winget list: $_")
        }
    }
}

function Get-UvInstalledToolInfo {
    param([string]$Name)

    try {
        $output = @(uv tool list 2>&1)
        $exitCode = $LASTEXITCODE
        $lines = Get-MeaningfulCommandLines -Lines $output

        if ($exitCode -ne 0) {
            return [pscustomobject]@{
                querySucceeded = $false
                installed = $false
                installedVersion = $null
                availableVersion = $null
                notes = @('uv tool list devolvió error al consultar herramientas instaladas.') + @($lines)
            }
        }

        $escapedName = [regex]::Escape($Name)
        $row = $lines | Where-Object { $_ -match "^$escapedName\s+v(?<version>\S+)" } | Select-Object -Last 1
        if (-not $row) {
            return [pscustomobject]@{
                querySucceeded = $true
                installed = $false
                installedVersion = $null
                availableVersion = $null
                notes = @()
            }
        }

        if ($row -match "^$escapedName\s+v(?<version>\S+)") {
            return [pscustomobject]@{
                querySucceeded = $true
                installed = $true
                installedVersion = $Matches.version
                availableVersion = $null
                notes = @()
            }
        }

        return [pscustomobject]@{
            querySucceeded = $true
            installed = $true
            installedVersion = $null
            availableVersion = $null
            notes = @('No se pudo parsear la versión instalada en uv tool list.') + @($lines)
        }
    } catch {
        return [pscustomobject]@{
            querySucceeded = $false
            installed = $false
            installedVersion = $null
            availableVersion = $null
            notes = @("No se pudo consultar uv tool list: $_")
        }
    }
}

function Get-PypiLatestVersion {
    param([string]$Name)

    try {
        $uri = "https://pypi.org/pypi/$Name/json"
        $response = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 15 -ErrorAction Stop
        $version = "$($response.info.version)"
        if ([string]::IsNullOrWhiteSpace($version)) {
            return [pscustomobject]@{
                querySucceeded = $false
                version = $null
                notes = @('PyPI respondió sin versión utilizable.')
            }
        }

        return [pscustomobject]@{
            querySucceeded = $true
            version = $version
            notes = @()
        }
    } catch {
        return [pscustomobject]@{
            querySucceeded = $false
            version = $null
            notes = @("No se pudo consultar versión en PyPI para $($Name): $_")
        }
    }
}

Write-Log "INICIANDO AI CLI SENTINEL v3.1 (Patch)" -Color Cyan

if (-not (Test-Admin)) {
    Write-Error "Se requieren privilegios de Administrador para la gestión de VSS y actualizaciones globales."
    exit
}

$Config = @{ npm = @(); winget = @(); uv = @() }
if (Test-Path $ConfigFile) {
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if (-not $Config.npm) { $Config.npm = @() }
        if (-not $Config.winget) { $Config.winget = @() }
        if (-not $Config.uv) { $Config.uv = @() }
        $Config.npm = @($Config.npm | ForEach-Object { ConvertTo-NpmName $_ } | Where-Object { $_ } | Sort-Object -Unique)
        $Config.uv = @($Config.uv | ForEach-Object { "$($_)".Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        Write-Log "Configuración cargada: $($Config.npm.Count) agentes NPM, $($Config.winget.Count) agentes Winget, $($Config.uv.Count) herramientas UV." -Color Gray
    } catch {
        Write-Log "Error al leer $($ConfigFile): $_" -Color Red -Level ERROR
        Write-Warning "Continuando con lista blanca vacía. Solo se ejecutará modo descubrimiento."
    }
} else {
    Write-Warning "No se encontró $ConfigFile. Usando modo solo-descubrimiento o lista vacía."
}

if ($Discover) {
    Write-Log ">>> EJECUTANDO MODO DESCUBRIMIENTO (Solo Reporte) <<<" -Color Magenta
    $Keywords = "ai|gpt|claude|bot|llm|chat|copilot|gemini|anthropic|openai|qwen|codex"
    $Candidates = New-CandidatesDocument

    try {
        $InstalledJson = npm list -g --depth=0 --json 2>$null
        if ($InstalledJson) {
            $Installed = $InstalledJson | ConvertFrom-Json
            $CandidatesFound = $false

            if ($Installed.dependencies) {
                foreach ($pkg in $Installed.dependencies.PSObject.Properties) {
                    $name = ConvertTo-NpmName $pkg.Name
                    if (($name -match $Keywords) -and ($name -notin $Config.npm)) {
                        $version = 'unknown'
                        if ($pkg.Value -and $pkg.Value.version) {
                            $version = $pkg.Value.version
                        }

                        $Candidates.npm += [ordered]@{
                            name = $name
                            version = $version
                            detectedAt = (Get-Date).ToString('o')
                            status = 'pending'
                            source = 'discover-npm'
                        }

                        Write-Log "[CANDIDATO DETECTADO] $name (v$version) - pendiente de aprobacion." -Color Yellow -Level WARN
                        $CandidatesFound = $true
                    }
                }
            }

            if (-not $CandidatesFound) {
                Write-Log "No se encontraron candidatos fuera de la lista blanca." -Color Gray
            } else {
                Save-JsonFile -Object $Candidates -Path $CandidatesFile
                Write-Log "Candidatos exportados en: $CandidatesFile" -Color Cyan
                Write-Log "Siguiente paso recomendado: ejecutar -ApproveCandidates para revisar y aprobar." -Color Gray
            }
        } else {
            Write-Log "No se pudo obtener lista de paquetes NPM instalados globalmente." -Color Yellow -Level WARN
        }
    } catch {
        Write-Log "Error durante descubrimiento: $_" -Color Red -Level ERROR
    }

    Write-Log "Fin del descubrimiento. No se realizaron cambios." -Color Magenta
    return
}

if ($ApproveCandidates) {
    Write-Log ">>> EJECUTANDO MODO DE APROBACIÓN DE CANDIDATOS <<<" -Color Magenta

    if (-not (Test-Path $CandidatesFile)) {
        Write-Log "No se encontró archivo de candidatos: $CandidatesFile" -Color Yellow -Level WARN
        Write-Log "Primero ejecuta -Discover para generar candidatos." -Color Gray
        return
    }

    try {
        $CandidateData = Get-Content $CandidatesFile -Raw | ConvertFrom-Json
        if (-not $CandidateData.npm) { $CandidateData.npm = @() }
    } catch {
        Write-Log "Error al leer candidatos en $($CandidatesFile): $_" -Color Red -Level ERROR
        exit 1
    }

    $approved = 0
    $skipped = 0

    foreach ($candidate in $CandidateData.npm) {
        $candidateName = ConvertTo-NpmName $candidate.name
        if (-not (Test-NpmPackageName -Name $candidateName)) {
            Write-Log "Candidato invalido, se omite: $($candidate.name)" -Color Yellow -Level WARN
            $skipped++
            continue
        }

        if ($candidateName -in $Config.npm) {
            Write-Log "Ya estaba en allowlist: $candidateName" -Color Gray
            $candidate.status = 'already-allowed'
            $skipped++
            continue
        }

        $approve = $false
        if ($AutoApproveCandidates) {
            $approve = $true
        } else {
            $choice = Read-Host "Agregar '$candidateName' a allowlist? [y/N]"
            if ($choice -match '^(y|yes|s|si)$') {
                $approve = $true
            }
        }

        if ($approve) {
            $Config.npm += $candidateName
            $candidate.status = 'approved'
            $candidate.approvedAt = (Get-Date).ToString('o')
            $approved++
            Write-Log "Aprobado e incorporado: $candidateName" -Color Green
        } else {
            $candidate.status = 'rejected'
            $candidate.rejectedAt = (Get-Date).ToString('o')
            $skipped++
            Write-Log "Rechazado: $candidateName" -Color DarkYellow -Level WARN
        }
    }

    $Config.npm = @($Config.npm | Sort-Object -Unique)
    Save-JsonFile -Object $Config -Path $ConfigFile
    Save-JsonFile -Object $CandidateData -Path $CandidatesFile

    Write-Log "Resumen aprobación: aprobados=$approved, omitidos/rechazados=$skipped" -Color Cyan
    Write-Log "Allowlist actualizada en: $ConfigFile" -Color Green
    Write-Log "Este modo no actualiza paquetes. Ejecuta el flujo estándar para actualizar." -Color Gray
    return
}

if ($PSCmdlet.ShouldProcess('Sistema Operativo', 'Crear Punto de Restauración (VSS)')) {
    try {
        Checkpoint-Computer -Description 'AI-Sentinel-Update' -RestorePointType APPLICATION_INSTALL -ErrorAction Stop
        Write-Log 'Punto de restauración VSS creado exitosamente.' -Color Green
    } catch {
        Write-Log "FALLO VSS: $_" -Color Red -Level ERROR
        if ($PSCmdlet.ShouldContinue('¿Continuar sin punto de restauración?', 'Advertencia de Seguridad')) {
            Write-Log 'Usuario decidió continuar sin VSS.' -Color DarkYellow
        } else {
            exit
        }
    }
}

if ($BackupSecrets) {
    if ($PSCmdlet.ShouldProcess('Archivos de Usuario', 'Respaldar Secretos (.ssh, .config)')) {
        $BackupDir = "$HOME\Desktop\AI_Backup_$(Get-Date -Format 'yyyyMMdd')"
        $Paths = @("$HOME\.config", "$HOME\.ssh", "$HOME\.npmrc")
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        foreach ($p in $Paths) {
            if (Test-Path $p) {
                Copy-Item $p $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Log "Secretos respaldados en $BackupDir" -Color Green
    }
}

if ($Config.npm.Count -eq 0 -and $Config.winget.Count -eq 0 -and $Config.uv.Count -eq 0) {
    Write-Log 'Lista blanca vacía. No hay agentes para actualizar.' -Color Yellow -Level WARN
    Write-Log 'Usa -Discover para encontrar agentes instalados o edita agents.allowlist.json' -Color Gray
    exit 0
}

$OperationResults = @()

if ($Config.npm.Count -gt 0) {
    Write-Log "Procesando $($Config.npm.Count) agente(s) NPM..." -Color Cyan
    foreach ($AgentName in $Config.npm) {
        try {
            $installedInfo = Get-NpmInstalledPackageInfo -Name $AgentName
            if (-not $installedInfo.querySucceeded) {
                $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'failed' -Notes $installedInfo.notes
                Write-Log "Error consultando instalación NPM de $($AgentName)." -Color Red -Level ERROR
                continue
            }

            if (-not $installedInfo.installed) {
                Write-Log "Saltando $AgentName (No instalado)" -Color Gray
                $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'not-installed' -Notes @('El paquete no está instalado globalmente.')
                continue
            }

            $latestInfo = Get-NpmLatestVersion -Name $AgentName
            if (-not $latestInfo.querySucceeded) {
                $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'failed' -InstalledVersionBefore $installedInfo.installedVersion -Notes $latestInfo.notes
                Write-Log "No se pudo determinar la versión más reciente de $($AgentName)." -Color Red -Level ERROR
                continue
            }

            if ($installedInfo.installedVersion -eq $latestInfo.version) {
                Write-Log "$AgentName ya está en la versión más reciente ($($installedInfo.installedVersion))." -Color Gray
                $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'already-current' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $installedInfo.installedVersion -Notes @('No se requiere actualización.')
                continue
            }

            if ($PSCmdlet.ShouldProcess($AgentName, 'Actualizar NPM (Aislado)')) {
                Write-Log "Actualizando $AgentName de $($installedInfo.installedVersion) a $($latestInfo.version)..." -Color Cyan
                $npmOutput = @(npm install -g "$AgentName@latest" --ignore-scripts 2>&1)
                $npmExitCode = $LASTEXITCODE
                Write-CommandOutput -Prefix 'NPM: ' -Lines $npmOutput

                if ($npmExitCode -ne 0) {
                    $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'failed' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $installedInfo.installedVersion -Notes @("npm install falló con exit=$npmExitCode.")
                    Write-Log "Fallo al actualizar $AgentName (exit=$npmExitCode)." -Color Red -Level ERROR
                    continue
                }

                $postInstallInfo = Get-NpmInstalledPackageInfo -Name $AgentName
                if (-not $postInstallInfo.querySucceeded -or -not $postInstallInfo.installed) {
                    $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -Notes @('La instalación terminó, pero no se pudo verificar la versión final.')
                    Write-Log "No se pudo verificar la versión final de $AgentName tras la actualización." -Color Yellow -Level WARN
                    continue
                }

                if ($postInstallInfo.installedVersion -eq $latestInfo.version) {
                    $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'updated' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $postInstallInfo.installedVersion -Changed ($postInstallInfo.installedVersion -ne $installedInfo.installedVersion)
                    continue
                }

                $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $postInstallInfo.installedVersion -Notes @('La versión final no coincide con la versión objetivo reportada por npm view.')
                Write-Log "Resultado incierto al verificar la versión final de $AgentName." -Color Yellow -Level WARN
                continue
            }

            $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'would-update' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $installedInfo.installedVersion -Notes @('Actualización omitida por -WhatIf.')
        } catch {
            Write-Log "Error procesando $($AgentName): $_" -Color Red -Level ERROR
            $OperationResults += New-OperationResult -Name $AgentName -Manager 'npm' -Status 'failed' -Notes @("Excepción no controlada: $_")
        }
    }
}

if ($Config.uv.Count -gt 0) {
    Write-Log "Procesando $($Config.uv.Count) herramienta(s) UV..." -Color Cyan
    foreach ($ToolName in $Config.uv) {
        try {
            $installedInfo = Get-UvInstalledToolInfo -Name $ToolName
            if (-not $installedInfo.querySucceeded) {
                $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'failed' -Notes $installedInfo.notes
                Write-Log "No se pudo consultar uv tool list para $($ToolName)." -Color Red -Level ERROR
                continue
            }

            if (-not $installedInfo.installed) {
                Write-Log "Saltando $ToolName (No instalado)" -Color Gray
                $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'not-installed' -Notes @('La herramienta no está instalada en uv tool.')
                continue
            }

            $latestInfo = Get-PypiLatestVersion -Name $ToolName
            if (-not $latestInfo.querySucceeded) {
                $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -Notes $latestInfo.notes
                Write-Log "No se pudo determinar la versión más reciente en PyPI para $($ToolName)." -Color Yellow -Level WARN
                continue
            }

            if ($installedInfo.installedVersion -eq $latestInfo.version) {
                Write-Log "$ToolName ya está en la versión más reciente ($($installedInfo.installedVersion))." -Color Gray
                $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'already-current' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $installedInfo.installedVersion -Notes @('No se requiere actualización.')
                continue
            }

            if ($PSCmdlet.ShouldProcess($ToolName, 'Actualizar UV Tool')) {
                Write-Log "Actualizando $ToolName de $($installedInfo.installedVersion) a $($latestInfo.version)..." -Color Cyan
                $uvOutput = @(uv tool upgrade $ToolName 2>&1)
                $uvExitCode = $LASTEXITCODE
                Write-CommandOutput -Prefix 'UV: ' -Lines $uvOutput

                if ($uvExitCode -ne 0) {
                    $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'failed' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $installedInfo.installedVersion -Notes @("uv tool upgrade falló con exit=$uvExitCode.")
                    Write-Log "Fallo al actualizar $ToolName (exit=$uvExitCode)." -Color Red -Level ERROR
                    continue
                }

                $postInstallInfo = Get-UvInstalledToolInfo -Name $ToolName
                if (-not $postInstallInfo.querySucceeded -or -not $postInstallInfo.installed) {
                    $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -Notes @('La actualización terminó, pero no se pudo verificar la versión final con uv tool list.')
                    Write-Log "No se pudo verificar la versión final de $ToolName tras la actualización." -Color Yellow -Level WARN
                    continue
                }

                if ($postInstallInfo.installedVersion -eq $latestInfo.version) {
                    $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'updated' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $postInstallInfo.installedVersion -Changed ($postInstallInfo.installedVersion -ne $installedInfo.installedVersion)
                    continue
                }

                $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $postInstallInfo.installedVersion -Notes @('La versión final no coincide con la versión objetivo detectada en PyPI.')
                Write-Log "Resultado incierto al verificar la versión final de $ToolName." -Color Yellow -Level WARN
                continue
            }

            $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'would-update' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $latestInfo.version -InstalledVersionAfter $installedInfo.installedVersion -Notes @('Actualización omitida por -WhatIf.')
        } catch {
            Write-Log "Error procesando $($ToolName): $_" -Color Red -Level ERROR
            $OperationResults += New-OperationResult -Name $ToolName -Manager 'uv' -Status 'failed' -Notes @("Excepción no controlada: $_")
        }
    }
}

if ($Config.winget.Count -gt 0) {
    Write-Log "Procesando $($Config.winget.Count) aplicación(es) Winget..." -Color Cyan
    foreach ($AppId in $Config.winget) {
        try {
            $installedInfo = Get-WingetInstalledPackageInfo -Id $AppId
            if (-not $installedInfo.querySucceeded) {
                $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'failed' -Notes $installedInfo.notes
                Write-Log "No se pudo consultar winget list para $($AppId)." -Color Red -Level ERROR
                continue
            }

            if (-not $installedInfo.installed) {
                Write-Log "Saltando $AppId (No instalado)" -Color Gray
                $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'not-installed' -Notes @('La aplicación no está instalada localmente.')
                continue
            }

            if (-not $installedInfo.parseSucceeded) {
                $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -Notes $installedInfo.notes
                Write-Log "No se pudo determinar con certeza el estado de $AppId desde winget list." -Color Yellow -Level WARN
                continue
            }

            if ([string]::IsNullOrWhiteSpace($installedInfo.availableVersion)) {
                Write-Log "$AppId ya está en la versión más reciente ($($installedInfo.installedVersion))." -Color Gray
                $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'already-current' -InstalledVersionBefore $installedInfo.installedVersion -InstalledVersionAfter $installedInfo.installedVersion -Notes @('winget list no reporta versión disponible; se asume estado al día.')
                continue
            }

            if ($installedInfo.availableVersion -eq $installedInfo.installedVersion) {
                Write-Log "$AppId ya está en la versión más reciente ($($installedInfo.installedVersion))." -Color Gray
                $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'already-current' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $installedInfo.availableVersion -InstalledVersionAfter $installedInfo.installedVersion
                continue
            }

            if ($PSCmdlet.ShouldProcess($AppId, 'Actualizar Winget')) {
                Write-Log "Actualizando $AppId de $($installedInfo.installedVersion) a $($installedInfo.availableVersion)..." -Color Cyan
                $wingetOutput = @(winget upgrade --id $AppId --exact --silent --disable-interactivity --accept-source-agreements --accept-package-agreements 2>&1)
                $wingetExitCode = $LASTEXITCODE
                Write-CommandOutput -Prefix 'Winget: ' -Lines $wingetOutput

                if ($wingetExitCode -ne 0) {
                    $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'failed' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $installedInfo.availableVersion -InstalledVersionAfter $installedInfo.installedVersion -Notes @("winget upgrade falló con exit=$wingetExitCode.")
                    Write-Log "Fallo al actualizar $AppId (exit=$wingetExitCode)." -Color Red -Level ERROR
                    if (($wingetOutput -join [System.Environment]::NewLine) -imatch '0x80070005') {
                        Write-Log 'Diagnóstico: Access denied (0x80070005). Verifica privilegios elevados y que la app no esté en uso.' -Color Yellow -Level WARN
                    }
                    continue
                }

                $postInstallInfo = Get-WingetInstalledPackageInfo -Id $AppId
                if (-not $postInstallInfo.querySucceeded -or -not $postInstallInfo.installed) {
                    $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $installedInfo.availableVersion -Notes @('La actualización terminó, pero no se pudo verificar la versión final mediante winget list.')
                    Write-Log "No se pudo verificar la versión final de $AppId tras la actualización." -Color Yellow -Level WARN
                    continue
                }

                if ($postInstallInfo.installedVersion -eq $installedInfo.availableVersion) {
                    $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'updated' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $installedInfo.availableVersion -InstalledVersionAfter $postInstallInfo.installedVersion -Changed ($postInstallInfo.installedVersion -ne $installedInfo.installedVersion)
                    continue
                }

                $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'unknown' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $installedInfo.availableVersion -InstalledVersionAfter $postInstallInfo.installedVersion -Notes @('La versión final no coincide con la versión disponible detectada antes de actualizar.')
                Write-Log "Resultado incierto al verificar la versión final de $AppId." -Color Yellow -Level WARN
                continue
            }

            $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'would-update' -InstalledVersionBefore $installedInfo.installedVersion -AvailableVersionBefore $installedInfo.availableVersion -InstalledVersionAfter $installedInfo.installedVersion -Notes @('Actualización omitida por -WhatIf.')
        } catch {
            Write-Log "Error actualizando $($AppId): $_" -Color Red -Level ERROR
            $OperationResults += New-OperationResult -Name $AppId -Manager 'winget' -Status 'failed' -Notes @("Excepción no controlada: $_")
        }
    }
}

$counts = Write-OperationSummary -Results $OperationResults
$RunEndedAt = Get-Date
$exitCode = 0
if ($counts['failed'] -gt 0) {
    $exitCode = 1
}

$reportWritten = Write-RunReport -Results $OperationResults -StartedAt $RunStartedAt -EndedAt $RunEndedAt -Counts $counts -ExitCode $exitCode

if (-not $reportWritten) {
    Write-Log 'Protocolo Sentinel finalizó con errores al escribir el reporte JSON.' -Color Red -Level ERROR
    exit 1
}

if ($exitCode -ne 0) {
    Write-Log 'Protocolo Sentinel finalizó con errores.' -Color Red -Level ERROR
    exit 1
}

Write-Log 'Protocolo Sentinel finalizado correctamente.' -Color Green