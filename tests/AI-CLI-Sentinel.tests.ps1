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
                ($config.npm -is [System.Array]) | Should -Be $true
                ($config.winget -is [System.Array]) | Should -Be $true
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

        It "Debe tener parámetro ReportPath" {
            $ScriptContent | Should -Match '\[string\]\$ReportPath'
        }

        It "Debe tener parámetro NoReport" {
            $ScriptContent | Should -Match '\[switch\]\$NoReport'
        }
        
        It "Debe tener parámetro ConfigFile" {
            $ScriptContent | Should -Match '\[string\]\$ConfigFile'
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
        }
        
        It "Debe usar --ignore-scripts en instalaciones NPM" {
            $ScriptContent | Should -Match "--ignore-scripts"
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
