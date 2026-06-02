# Compatible con Pester 3.x y 5.x

Describe "AI-CLI-Sentinel Tests" {
    BeforeAll {
        # Configurar variables de entorno para tests
        $TestConfigPath = Join-Path $PSScriptRoot "..\src\agents.allowlist.json"
        $ScriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
        $ScriptContent = Get-Content $ScriptPath -Raw
    }
    
    Context "Archivo de Configuración" {
        It "Debe existir el archivo agents.allowlist.json" {
            Test-Path $TestConfigPath | Should -Be $true
        }
        
        It "Debe ser un JSON válido" {
            if (Test-Path $TestConfigPath) {
                $config = Get-Content $TestConfigPath -Raw | ConvertFrom-Json
                $config | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Debe tener estructura correcta con npm y winget" {
            if (Test-Path $TestConfigPath) {
                $config = Get-Content $TestConfigPath -Raw | ConvertFrom-Json
                ($config.PSObject.Properties.Name -contains "npm") | Should -Be $true
                ($config.PSObject.Properties.Name -contains "winget") | Should -Be $true
                ($config.PSObject.Properties.Name -contains "uv") | Should -Be $true
                ($config.npm -is [System.Array]) | Should -Be $true
                ($config.winget -is [System.Array]) | Should -Be $true
                ($config.uv -is [System.Array]) | Should -Be $true
            }
        }
    }
    
    Context "Estructura del Script Principal" {
        It "Debe existir el script AI-CLI-Sentinel.ps1" {
            Test-Path $ScriptPath | Should -Be $true
        }
        
        It "Debe tener función Write-Log definida" {
            $ScriptContent | Should -Match "function Write-Log"
        }
        
        It "Debe tener función Test-Admin definida" {
            $ScriptContent | Should -Match "function Test-Admin"
        }
        
        It "Debe soportar ShouldProcess para WhatIf" {
            $ScriptContent | Should -Match "SupportsShouldProcess"
        }
        
        It "Debe tener parámetro Discover" {
            $ScriptContent | Should -Match '\[switch\]\$Discover'
        }
        
        It "Debe tener parámetro BackupSecrets" {
            $ScriptContent | Should -Match '\[switch\]\$BackupSecrets'
        }

        It "Debe tener parámetro BackupPath para respaldos explícitos" {
            $ScriptContent | Should -Match '\[string\]\$BackupPath'
        }

        It "Debe tener parámetro ReportPath" {
            $ScriptContent | Should -Match '\[string\]\$ReportPath'
        }

        It "Debe tener parámetro NoReport" {
            $ScriptContent | Should -Match '\[switch\]\$NoReport'
        }
        
        It "Debe tener parámetro ConfigFile" {
            $ScriptContent | Should -Match '\[string\]\$ConfigFile'
        }

        It "Debe resolver la allowlist desde ProgramData antes del fallback del repositorio" {
            $ScriptContent | Should -Match 'function Get-SecurePolicyPath'
            $ScriptContent | Should -Match "GetFolderPath\('CommonApplicationData'\)"
            $ScriptContent | Should -Match 'AI-CLI-Sentinel\\policy\\agents.allowlist.json'
            $ScriptContent | Should -Match 'function Resolve-ConfigFilePath'
            $ScriptContent | Should -Match 'repository-fallback'
            $ScriptContent | Should -Match 'raíz de confianza protegida'
            $ScriptContent | Should -Not -Match '\[string\]\$ConfigFile = "\$PSScriptRoot\\agents\.allowlist\.json"'
        }
        
        It "Debe implementar modo Discover" {
            $ScriptContent | Should -Match "MODO DESCUBRIMIENTO"
        }
        
        It "Debe implementar creación de punto de restauración VSS" {
            $ScriptContent | Should -Match "Checkpoint-Computer"
        }
        
        It "Debe implementar respaldo de secretos" {
            $ScriptContent | Should -Match "BackupSecrets"
        }

        It "Debe exigir BackupPath y rechazar rutas Desktop o cloud-sync para secretos" {
            $ScriptContent | Should -Match 'BackupSecrets requiere -BackupPath'
            $ScriptContent | Should -Match 'function Test-UnsafeBackupPath'
            $ScriptContent | Should -Match 'function Get-CloudSyncRoots'
            $ScriptContent | Should -Match "GetFolderPath\('Desktop'\)"
            $ScriptContent | Should -Not -Match '\$HOME\\Desktop\\AI_Backup_'
            $ScriptContent | Should -Match 'Copy-Item .* -ErrorAction Stop'
        }

        It "Debe definir helpers de versionado para NPM" {
            $ScriptContent | Should -Match 'function Get-NpmInstalledPackageInfo'
            $ScriptContent | Should -Match 'function Get-NpmLatestVersion'
        }

        It "Debe definir helper de versionado para Winget" {
            $ScriptContent | Should -Match 'function Get-WingetInstalledPackageInfo'
            $ScriptContent | Should -Match 'winget list --id'
            $ScriptContent | Should -Match '--disable-interactivity'
            $ScriptContent | Should -Match 'patternWithAvailable'
            $ScriptContent | Should -Match 'patternWithoutAvailable'
        }

        It "Debe definir helper de versionado para UV" {
            $ScriptContent | Should -Match 'function Get-UvInstalledToolInfo'
            $ScriptContent | Should -Match 'uv tool list'
            $ScriptContent | Should -Match 'function Get-PypiLatestVersion'
            $ScriptContent | Should -Match 'https://pypi.org/pypi/'
            $ScriptContent | Should -Match 'function Normalize-VersionToken'
            $ScriptContent | Should -Match 'TrimStart\(''v'', ''V''\)'
        }

        It "Debe definir resultados estructurados y reporte JSON" {
            $ScriptContent | Should -Match 'function New-OperationResult'
            $ScriptContent | Should -Match 'function Write-RunReport'
            $ScriptContent | Should -Match 'AI_Sentinel_Report.json'
            $ScriptContent | Should -Match 'finalizó con errores al escribir el reporte JSON'
        }

        It "Debe definir resumen estructurado por estados" {
            $ScriptContent | Should -Match 'function Write-OperationSummary'
            $ScriptContent | Should -Match 'would-update'
            $ScriptContent | Should -Match 'already-current'
            $ScriptContent | Should -Match 'not-installed'
            $ScriptContent | Should -Match 'unknown'
            $ScriptContent | Should -Match "Manager 'uv'"
        }
        
        It "Debe usar --ignore-scripts en instalaciones NPM" {
            $ScriptContent | Should -Match "--ignore-scripts"
        }

        It "Debe instalar NPM con versión exacta y no con @latest" {
            $ScriptContent | Should -Match 'function Test-VersionToken'
            $ScriptContent | Should -Match '\$npmPinnedPackage = "\$AgentName@\$'
            $ScriptContent | Should -Match 'npm install -g \$npmPinnedPackage --ignore-scripts'
            $ScriptContent | Should -Not -Match '@latest'
        }

        It "Debe actualizar UV con requirement exacto y no con upgrade flotante" {
            $ScriptContent | Should -Match '\$uvPinnedRequirement = "\$ToolName==\$latestVersionNormalized"'
            $ScriptContent | Should -Match 'uv tool install --force \$uvPinnedRequirement'
            $ScriptContent | Should -Not -Match 'uv tool upgrade \$ToolName'
        }

        It "Debe actualizar Winget con versión exacta" {
            $ScriptContent | Should -Match 'winget upgrade --id \$AppId --exact --version \$installedInfo\.availableVersion'
        }

        It "No debe escribir el archivo de log durante -WhatIf" {
            $ScriptContent | Should -Match 'if \(\$WhatIfPreference\)'
        }

        It "Debe omitir el reporte JSON durante -WhatIf" {
            $ScriptContent | Should -Match 'Reporte JSON omitido en -WhatIf'
        }

        It "No debe usar --save-exact en instalación NPM global" {
            $ScriptContent | Should -Not -Match '--save-exact'
        }

        It "Debe usar comparación robusta para 0x80070005" {
            $ScriptContent | Should -Match '-imatch\s+''0x80070005'''
            $ScriptContent | Should -Match '\[System\.Environment\]::NewLine'
        }
    }
    
    Context "Validación de Sintaxis PowerShell" {
        It "No debe tener errores de sintaxis" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $ScriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
    }
}
