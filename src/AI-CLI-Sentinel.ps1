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
    [switch]$AutoApproveCandidates
)

$ErrorActionPreference = "Stop"

# --- FUNCIONES AUXILIARES ---
function Write-Log {
    param([string]$Message, [string]$Color="White", [string]$Level="INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$TimeStamp] [$Level] $Message"
    Write-Host $Line -ForegroundColor $Color
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

function Initialize-Candidates {
    return [ordered]@{
        generatedAt = (Get-Date).ToString("o")
        npm = @()
    }
}

function Normalize-NpmName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    return $Name.Trim().ToLowerInvariant()
}

function Test-NpmPackageName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }

    # Validacion conservadora para scoped/unscoped packages.
    return ($Name -match '^(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$')
}

# --- INICIO DEL PROCESO ---
Write-Log "INICIANDO AI CLI SENTINEL v3.1 (Patch)" -Color Cyan

# Validación estricta de privilegios de administrador
if (-not (Test-Admin)) {
    Write-Error "Se requieren privilegios de Administrador para la gestión de VSS y actualizaciones globales."
    exit
}

# 1. CARGA DE CONFIGURACIÓN
$Config = @{ npm = @(); winget = @() }
if (Test-Path $ConfigFile) {
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        # Validar estructura mínima requerida
        if (-not $Config.npm) { $Config.npm = @() }
        if (-not $Config.winget) { $Config.winget = @() }
        $Config.npm = @($Config.npm | ForEach-Object { Normalize-NpmName $_ } | Where-Object { $_ } | Sort-Object -Unique)
        Write-Log "Configuración cargada: $($Config.npm.Count) agentes NPM, $($Config.winget.Count) agentes Winget." -Color Gray
    } catch {
        # FIX: Usamos $($ConfigFile) para evitar error de parseo con los dos puntos
        Write-Log "Error al leer $($ConfigFile): $_" -Color Red -Level ERROR
        Write-Warning "Continuando con lista blanca vacía. Solo se ejecutará modo descubrimiento."
    }
} else {
    Write-Warning "No se encontró $ConfigFile. Usando modo solo-descubrimiento o lista vacía."
}

# 2. MODO DESCUBRIMIENTO (AUDITORÍA SOLAMENTE)
if ($Discover) {
    Write-Log ">>> EJECUTANDO MODO DESCUBRIMIENTO (Solo Reporte) <<<" -Color Magenta
    $Keywords = "ai|gpt|claude|bot|llm|chat|copilot|gemini|anthropic|openai|qwen|codex"
    $Candidates = Initialize-Candidates
    try {
        $InstalledJson = npm list -g --depth=0 --json 2>$null
        if ($InstalledJson) {
            $Installed = $InstalledJson | ConvertFrom-Json
            $CandidatesFound = $false
            
            if ($Installed.dependencies) {
                foreach ($pkg in $Installed.dependencies.PSObject.Properties) {
                    # Si coincide con keyword Y NO está en la lista blanca
                    $name = Normalize-NpmName $pkg.Name
                    if (($name -match $Keywords) -and ($name -notin $Config.npm)) {
                        $version = $null
                        try {
                            $depProp = $Installed.dependencies.PSObject.Properties | Where-Object { $_.Name -eq $pkg.Name } | Select-Object -First 1
                            if ($depProp -and $depProp.Value) {
                                $version = $depProp.Value.version
                            }
                        } catch {
                            $version = "unknown"
                        }
                        if (-not $version) { $version = "unknown" }

                        $Candidates.npm += [ordered]@{
                            name = $name
                            version = $version
                            detectedAt = (Get-Date).ToString("o")
                            status = "pending"
                            source = "discover-npm"
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
    return # Salimos porque Discover no debe actualizar
}

# 2.1 REVISIÓN / APROBACIÓN EXPLÍCITA DE CANDIDATOS
if ($ApproveCandidates) {
    Write-Log ">>> EJECUTANDO MODO DE APROBACIÓN DE CANDIDATOS <<<" -Color Magenta

    if (-not (Test-Path $CandidatesFile)) {
        Write-Log "No se encontró archivo de candidatos: $CandidatesFile" -Color Yellow -Level WARN
        Write-Log "Primero ejecuta -Discover para generar candidatos." -Color Gray
        exit 0
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
        $candidateName = Normalize-NpmName $candidate.name
        if (-not (Test-NpmPackageName -Name $candidateName)) {
            Write-Log "Candidato invalido, se omite: $($candidate.name)" -Color Yellow -Level WARN
            $skipped++
            continue
        }

        if ($candidateName -in $Config.npm) {
            Write-Log "Ya estaba en allowlist: $candidateName" -Color Gray
            $candidate.status = "already-allowed"
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
            $candidate.status = "approved"
            $candidate.approvedAt = (Get-Date).ToString("o")
            $approved++
            Write-Log "Aprobado e incorporado: $candidateName" -Color Green
        } else {
            $candidate.status = "rejected"
            $candidate.rejectedAt = (Get-Date).ToString("o")
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

# 3. RESILIENCIA (SYSTEM RESTORE)
# SupportsShouldProcess maneja automáticamente el -WhatIf aquí
if ($PSCmdlet.ShouldProcess("Sistema Operativo", "Crear Punto de Restauración (VSS)")) {
    try {
        Checkpoint-Computer -Description "AI-Sentinel-Update" -RestorePointType APPLICATION_INSTALL -ErrorAction Stop
        Write-Log "Punto de restauración VSS creado exitosamente." -Color Green
    } catch {
        Write-Log "FALLO VSS: $_" -Color Red -Level ERROR
        if ($PSCmdlet.ShouldContinue("¿Continuar sin punto de restauración?", "Advertencia de Seguridad")) {
            Write-Log "Usuario decidió continuar sin VSS." -Color DarkYellow
        } else {
            exit
        }
    }
}

# 4. RESPALDO DE SECRETOS
if ($BackupSecrets) {
    if ($PSCmdlet.ShouldProcess("Archivos de Usuario", "Respaldar Secretos (.ssh, .config)")) {
        $BackupDir = "$HOME\Desktop\AI_Backup_$(Get-Date -Format 'yyyyMMdd')"
        $Paths = @("$HOME\.config", "$HOME\.ssh", "$HOME\.npmrc")
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        foreach ($p in $Paths) {
            if (Test-Path $p) { Copy-Item $p $BackupDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Log "Secretos respaldados en $BackupDir" -Color Green
    }
}

# 5. ACTUALIZACIÓN SEGURA (LISTA BLANCA)
# Validar que hay agentes para actualizar
if ($Config.npm.Count -eq 0 -and $Config.winget.Count -eq 0) {
    Write-Log "Lista blanca vacía. No hay agentes para actualizar." -Color Yellow -Level WARN
    Write-Log "Usa -Discover para encontrar agentes instalados o edita agents.allowlist.json" -Color Gray
    exit 0
}

# NPM
if ($Config.npm.Count -gt 0) {
    Write-Log "Procesando $($Config.npm.Count) agente(s) NPM..." -Color Cyan
    foreach ($AgentName in $Config.npm) {
        # Verificar si está instalado antes de intentar actualizar
        try {
            $CheckJson = npm list -g $AgentName --depth=0 --json 2>$null
            if ($CheckJson) {
                $Check = $CheckJson | ConvertFrom-Json
                if ($Check.dependencies.$AgentName) {
                    if ($PSCmdlet.ShouldProcess($AgentName, "Actualizar NPM (Aislado + Audit)")) {
                        Write-Log "Actualizando $AgentName..." -Color Cyan
                        # --ignore-scripts: BLOQUEO DE MALWARE
                        # --save-exact: EVITAR DRIFT DE VERSIONES
                        npm install -g "$AgentName@latest" --ignore-scripts --audit --save-exact 2>&1 | ForEach-Object {
                            Write-Log "NPM: $_" -Color Gray
                        }
                    }
                } else {
                    Write-Log "Saltando $AgentName (No instalado)" -Color Gray
                }
            } else {
                Write-Log "Saltando $AgentName (No se pudo verificar instalación)" -Color Yellow -Level WARN
            }
        } catch {
            # FIX: Usamos $($AgentName) para evitar error de parseo
            Write-Log "Error procesando $($AgentName): $_" -Color Red -Level ERROR
        }
    }
}

# Winget
if ($Config.winget.Count -gt 0) {
    Write-Log "Procesando $($Config.winget.Count) aplicación(es) Winget..." -Color Cyan
    foreach ($AppId in $Config.winget) {
        if ($PSCmdlet.ShouldProcess($AppId, "Actualizar Winget")) {
            try {
                winget upgrade --id $AppId --silent --accept-source-agreements 2>&1 | ForEach-Object {
                    Write-Log "Winget: $_" -Color Gray
                }
            } catch {
                # FIX: Usamos $($AppId) para evitar error de parseo
                Write-Log "Error actualizando $($AppId): $_" -Color Red -Level ERROR
            }
        }
    }
}

Write-Log "Protocolo Sentinel finalizado correctamente." -Color Green
