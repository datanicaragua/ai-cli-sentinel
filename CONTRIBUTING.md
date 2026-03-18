# Guía de Contribución

¡Gracias por tu interés en contribuir a AI-CLI-Sentinel! Esta guía te ayudará a entender cómo puedes colaborar efectivamente.

## Código de Conducta

Al participar en este proyecto, te comprometes a mantener un ambiente respetuoso y colaborativo.

## Configuración del Entorno de Desarrollo

### Requisitos Previos

- **PowerShell 5.1+** (recomendado: PowerShell 7.4+)
- **Windows 10/11** o Windows Server 2016+
- **Git** instalado
- **Node.js y npm** (para pruebas con agentes NPM)
- **Winget** (para pruebas con aplicaciones Windows)

### Configuración Inicial

1. **Fork y clonar el repositorio**
   * Ve a [https://github.com/datanicaragua/ai-cli-sentinel](https://github.com/datanicaragua/ai-cli-sentinel) y haz clic en **"Fork"** (arriba a la derecha).
   * Clona **tu fork** (reemplaza `tu-usuario`):
   
   ```bash
   git clone https://github.com/tu-usuario/ai-cli-sentinel.git
   cd ai-cli-sentinel
   ```
   
   * Agrega el remoto original (upstream) para mantenerte actualizado:
   
   ```bash
   git remote add upstream https://github.com/datanicaragua/ai-cli-sentinel.git
   ```

2. **Instalar herramientas de desarrollo**
   ```powershell
   # Instalar Pester para tests
   Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
   
   # Instalar PSScriptAnalyzer para linting
   Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope CurrentUser
   ```

3. **Verificar instalación**
   ```powershell
   # Verificar sintaxis del script
   $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content src\AI-CLI-Sentinel.ps1 -Raw), [ref]$errors)
   $errors.Count  # Debe ser 0
   
   # Ejecutar tests (runner robusto, compatible con Pester 3/5)
   .\scripts\run-tests.ps1 -InstallPester5
   ```

## Cómo Contribuir

### Reportar Bugs

1. Verifica que el bug no haya sido reportado ya en los [Issues](https://github.com/datanicaragua/ai-cli-sentinel/issues)
2. Usa la plantilla de [Bug Report](.github/ISSUE_TEMPLATE/bug_report.md)
3. Proporciona información detallada para reproducir el problema:
   - Versión de PowerShell
   - Sistema operativo
   - Pasos exactos para reproducir
   - Logs relevantes (sin información sensible)

### Sugerir Funcionalidades

1. Revisa las [solicitudes existentes](https://github.com/datanicaragua/ai-cli-sentinel/issues)
2. Usa la plantilla de [Feature Request](.github/ISSUE_TEMPLATE/feature_request.md)
3. Explica claramente:
   - El problema que resuelve
   - Cómo lo resuelve
   - Impacto esperado

### Contribuir Código

#### Proceso de Desarrollo

1. **Crear una rama**
   ```bash
   git checkout -b feature/nombre-de-tu-funcionalidad
   # o
   git checkout -b fix/descripcion-del-bug
   ```

2. **Hacer cambios**
   - Sigue las convenciones de código existentes
   - Agrega tests para nuevas funcionalidades
   - Actualiza documentación cuando sea necesario
   - Mantén el principio de "Safe Defaults" (lista blanca estricta)

3. **Ejecutar tests localmente**
   ```powershell
   # Tests unitarios
   .\scripts\run-tests.ps1 -InstallPester5 -FailOnError
   
   # Validación de sintaxis
   Invoke-ScriptAnalyzer -Path src/ -Recurse -Severity Warning,Error
   
   # Validar JSON
   Get-Content src\agents.allowlist.json | ConvertFrom-Json | Out-Null
   ```

   **Cuándo ejecutar tests en terminal:**
   - Antes de crear o actualizar tu Pull Request.
   - Después de modificar `src/AI-CLI-Sentinel.ps1`.
   - Después de cambios en reglas de seguridad, salida/errores o documentación técnica asociada.

4. **Probar el script (modo seguro)**
   ```powershell
   # Modo simulación (WhatIf)
   .\src\AI-CLI-Sentinel.ps1 -WhatIf
   
   # Modo descubrimiento (solo reporte)
   .\src\AI-CLI-Sentinel.ps1 -Discover
   ```

5. **Commit con mensaje descriptivo**
   ```bash
   git add .
   git commit -m "feat: Descripción clara del cambio"
   ```

6. **Push y crear Pull Request**
   ```bash
   git push origin feature/nombre-de-tu-funcionalidad
   ```

#### Estándares de Código

- **PowerShell**: Seguir [PowerShell Best Practices](https://github.com/PoshCode/PowerShellPracticeAndStyle)
- **Nombres**: Usar verbos apropiados (Get-, Set-, New-, etc.)
- **Comentarios**: Documentar funciones complejas y decisiones de seguridad
- **Formato**: Usar formato consistente (2 espacios de indentación)
- **Seguridad**: 
  - Nunca ejecutar scripts sin `--ignore-scripts` en npm
  - Siempre crear punto de restauración VSS antes de cambios
  - Validar entrada del usuario antes de procesar

#### Estructura de Commits

Usa mensajes descriptivos siguiendo [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: Agregar nueva funcionalidad X`
- `fix: Corregir bug en Y`
- `docs: Actualizar documentación`
- `test: Agregar tests para Z`
- `refactor: Refactorizar módulo W`
- `security: Mejorar seguridad en V`

#### Escribir Tests

Los tests deben:
- Cubrir casos de éxito y error
- Validar comportamiento con lista blanca vacía
- Probar modo Discover sin realizar cambios
- Verificar manejo de errores

Ejemplo:
```powershell
Describe "Nueva Funcionalidad" {
    It "Debe hacer X cuando Y" {
        # Arrange
        # Act
        # Assert
    }
}
```

### Documentación

- Mantén la documentación actualizada con tus cambios
- Usa Markdown para formato consistente
- Incluye ejemplos cuando sea posible
- Documenta decisiones de seguridad importantes

## Proceso de Revisión

1. Todos los Pull Requests serán revisados por al menos un mantenedor
2. Los revisores pueden solicitar cambios
3. El CI debe pasar (linting y tests)
4. Una vez aprobado, el PR será mergeado

### Checklist para Pull Requests

- [ ] Código sigue los estándares del proyecto
- [ ] Tests agregados/actualizados y pasando
- [ ] Documentación actualizada
- [ ] Linting pasa sin errores
- [ ] Probado localmente con `-WhatIf` y `-Discover`
- [ ] Mensaje de commit sigue convenciones
- [ ] No contiene información sensible

## Reportar Vulnerabilidades

**NO** uses issues públicos para vulnerabilidades de seguridad. En su lugar:

1. Usa el [formulario de seguridad](.github/ISSUE_TEMPLATE/security_report.md)
2. O consulta [SECURITY.md](SECURITY.md) para contacto directo

## Preguntas

Si tienes preguntas, puedes:
- Abrir un issue con la etiqueta `question`
- Contactar a los mantenedores del proyecto

## Agradecimientos

¡Gracias por contribuir a hacer AI-CLI-Sentinel más seguro y robusto para todos!
