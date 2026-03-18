# Compatible con Pester 3.x y 5.x

Describe "AI-CLI-Sentinel Tests" {
    BeforeAll {
        # Configurar variables de entorno para tests
        $TestConfigPath = Join-Path $PSScriptRoot "..\src\agents.allowlist.json"
        $ScriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
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
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "function Write-Log"
        }
        
        It "Debe tener función Test-Admin definida" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "function Test-Admin"
        }
        
        It "Debe soportar ShouldProcess para WhatIf" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "SupportsShouldProcess"
        }
        
        It "Debe tener parámetro Discover" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$Discover'
        }
        
        It "Debe tener parámetro BackupSecrets" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match '\[switch\]\$BackupSecrets'
        }
        
        It "Debe tener parámetro ConfigFile" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match '\[string\]\$ConfigFile'
        }
        
        It "Debe implementar modo Discover" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "MODO DESCUBRIMIENTO"
        }
        
        It "Debe implementar creación de punto de restauración VSS" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "Checkpoint-Computer"
        }
        
        It "Debe implementar respaldo de secretos" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "BackupSecrets"
        }
        
        It "Debe usar --ignore-scripts en instalaciones NPM" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match "--ignore-scripts"
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
