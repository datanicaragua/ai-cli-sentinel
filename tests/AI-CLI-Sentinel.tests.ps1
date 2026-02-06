# Requiere Pester 5.0+
# Install-Module -Name Pester -Force -SkipPublisherCheck

BeforeAll {
    # Configurar variables de entorno para tests
    $TestConfigPath = Join-Path $PSScriptRoot "..\src\agents.allowlist.json"
    $TestLogPath = "$env:TEMP\AI_Sentinel_Test_Log_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
}

Describe "AI-CLI-Sentinel Tests" {
    
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
                $config | Should -HaveMember "npm"
                $config | Should -HaveMember "winget"
                $config.npm | Should -BeOfType [System.Array]
                $config.winget | Should -BeOfType [System.Array]
            }
        }
    }
    
    Context "Estructura del Script Principal" {
        It "Debe existir el script AI-CLI-Sentinel.ps1" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            Test-Path $scriptPath | Should -Be $true
        }
        
        It "Debe tener función Write-Log definida" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "function Write-Log"
        }
        
        It "Debe tener función Test-Admin definida" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "function Test-Admin"
        }
        
        It "Debe soportar ShouldProcess para WhatIf" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "SupportsShouldProcess"
        }
        
        It "Debe tener parámetro Discover" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "\[switch\]\$Discover"
        }
        
        It "Debe tener parámetro BackupSecrets" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "\[switch\]\$BackupSecrets"
        }
        
        It "Debe tener parámetro ConfigFile" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "\[string\]\$ConfigFile"
        }
        
        It "Debe implementar modo Discover" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "MODO DESCUBRIMIENTO"
        }
        
        It "Debe implementar creación de punto de restauración VSS" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "Checkpoint-Computer"
        }
        
        It "Debe implementar respaldo de secretos" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "BackupSecrets"
        }
        
        It "Debe usar --ignore-scripts en instalaciones NPM" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "--ignore-scripts"
        }
    }
    
    Context "Validación de Sintaxis PowerShell" {
        It "No debe tener errores de sintaxis" {
            $scriptPath = Join-Path $PSScriptRoot "..\src\AI-CLI-Sentinel.ps1"
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $scriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
    }
}
