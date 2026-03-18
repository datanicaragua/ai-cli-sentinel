# Diseño: Actualización con Conciencia de Versión y Reporte de Cambios

## Objetivo

Corregir la semántica actual del flujo de actualización para que AI-CLI-Sentinel:

- no intente actualizar ciegamente cualquier CLI permitido solo porque está instalado,
- determine si el artefacto ya está al día antes de ejecutar cambios,
- registre con precisión si hubo actualización real o solo verificación,
- emita un reporte claro de versión previa y versión final por cada agente procesado.

## Problema Actual

Hoy el flujo principal solo verifica si un paquete está instalado y, si lo está, intenta actualizarlo:

- NPM: `npm list -g <package> --depth=0 --json` seguido de `npm install -g <package>@latest --ignore-scripts`
- Winget: `winget upgrade --id <id> --silent --accept-source-agreements --accept-package-agreements`

Esto tiene tres limitaciones:

1. No distingue entre "actualizado" y "ya estaba en la versión más reciente".
2. El resumen final puede sobrecontar actualizaciones reales.
3. No deja una evidencia explícita del cambio de versión `antes -> después`.

## Principios de Diseño

1. Idempotencia: ejecutar el script varias veces el mismo día no debe producir "actualizaciones" ficticias.
2. Fuente de verdad actual: la decisión debe basarse en versión instalada vs versión disponible, no en una marca temporal local.
3. Trazabilidad: cada agente debe dejar evidencia de versión previa, versión objetivo y resultado final.
4. Compatibilidad operativa: mantener `-WhatIf`, `-BackupSecrets`, allowlist y manejo robusto de errores ya incorporado.
5. Mínimo cambio de superficie: mejorar semántica y reporte sin reescribir el flujo completo.

## Alcance del PR

### Incluye

- Detección de versión instalada y versión disponible para NPM.
- Detección del estado disponible para Winget y captura de versión previa/posterior cuando sea posible.
- Clasificación formal del resultado por agente.
- Resumen final basado en estados reales, no solo en exit codes.
- Reporte legible en consola.
- Reporte estructurado en JSON para auditoría.
- Tests para los nuevos estados y documentación asociada.

### No incluye

- Persistencia histórica avanzada o base de datos de ejecuciones.
- Dashboard externo.
- Soporte para gestores adicionales fuera de NPM y Winget.
- Políticas automáticas de downgrade/rollback.

## Resultado Esperado por Agente

Cada agente procesado debe terminar en exactamente uno de estos estados:

- `updated`: había una versión más reciente y se instaló correctamente.
- `already-current`: ya estaba en la versión disponible más reciente.
- `not-installed`: estaba en allowlist, pero no estaba instalado localmente.
- `failed`: el flujo de consulta o actualización falló.
- `unknown`: no se pudo determinar versión o estado con certeza, aunque no necesariamente falló la ejecución completa.

## Propuesta de Modelo de Reporte

### Estructura en memoria

Cada operación agregará un objeto con esta forma:

```json
{
  "name": "@github/copilot",
  "manager": "npm",
  "status": "updated",
  "installedVersionBefore": "1.2.3",
  "availableVersionBefore": "1.2.5",
  "installedVersionAfter": "1.2.5",
  "changed": true,
  "timestamp": "2026-03-18T00:00:00.0000000Z",
  "notes": []
}
```

### Archivo de salida

Nuevo parámetro propuesto:

```powershell
-ReportPath
```

Valor por defecto propuesto:

```powershell
$HOME\Desktop\AI_Sentinel_Report.json
```

El reporte JSON contendrá:

- metadatos de ejecución,
- lista completa de resultados por agente,
- contadores agregados por estado,
- código de salida final,
- timestamp de inicio y fin.

## Estrategia para NPM

### Detección de versión instalada

Usar la salida de:

```powershell
npm list -g <package> --depth=0 --json
```

Extraer:

- presencia del paquete,
- versión instalada actual.

### Detección de versión disponible

Usar:

```powershell
npm view <package> version
```

Reglas:

- si la versión instalada es igual a la disponible: `already-current`
- si la versión disponible es mayor/distinta: intentar actualización
- tras actualizar, releer versión instalada y verificar cambio real
- si `npm install` devuelve `0` pero la versión final no cambia: clasificar como `already-current` o `unknown` según evidencia disponible

## Estrategia para Winget

Winget es más irregular que NPM para automatización silenciosa, por lo que el diseño debe ser defensivo.

### Opción propuesta

1. Consultar estado previo con:

```powershell
winget list --id <id>
```

2. Consultar si existe upgrade disponible con:

```powershell
winget upgrade --id <id>
```

3. Si no hay upgrade disponible: `already-current`
4. Si hay upgrade disponible: ejecutar actualización
5. Tras actualizar, releer `winget list --id <id>` y registrar versión final

### Nota operativa

La salida de Winget no siempre es perfectamente parseable. El PR debe priorizar:

- capturar estado útil antes/después,
- evitar falsos positivos de actualización,
- marcar `unknown` cuando la salida no permita concluir con certeza.

## Cambios Propuestos en el Resumen Final

El resumen actual:

```text
Resumen: actualizados=X, omitidos=Y, fallidos=Z
```

Debe evolucionar hacia algo como:

```text
Resumen: updated=2, already-current=3, not-installed=1, failed=0, unknown=0
```

Y además, por cada agente:

```text
NPM | @github/copilot | 1.2.3 -> 1.2.5 | updated
NPM | @openai/codex   | 0.9.1 -> 0.9.1 | already-current
Winget | GitHub.cli   | 2.68.1 -> 2.69.0 | updated
```

## Comportamiento de Exit Code

Mantener la política actual con una semántica más precisa:

- `0` si no hubo fallos operativos, aunque no haya actualizaciones reales.
- `1` si una o más operaciones terminan en `failed`.

`already-current`, `not-installed` y `unknown` no deben marcar fallo por sí solos, salvo que el proyecto decida endurecer `unknown` en el futuro.

## Parámetros Nuevos Propuestos

- `-ReportPath`: ruta del reporte JSON.
- `-NoReport`: opcional, para desactivar escritura del reporte estructurado.

No es necesario introducir un flag tipo `-SkipIfUpdatedToday`, porque ese enfoque no es la decisión más robusta ni la tendencia dominante en la industria.

## Cambios de Implementación Propuestos

### Nuevas funciones

- `Get-NpmInstalledPackageInfo`
- `Get-NpmLatestVersion`
- `Get-WingetInstalledPackageInfo`
- `Get-WingetUpgradeInfo`
- `New-OperationResult`
- `Write-RunReport`
- `Write-OperationSummary`

### Refactor mínimo del flujo principal

Sustituir arreglos string como:

- `$FailedOperations`
- `$UpdatedOperations`
- `$SkippedOperations`

por una colección de resultados estructurados, desde la cual se calculen los contadores agregados.

## Estrategia de Testing

Agregar pruebas que verifiquen al menos:

1. El script define helpers para consulta de versión.
2. El script expone `-ReportPath`.
3. El resumen final distingue `updated` y `already-current`.
4. La lógica sigue usando `--ignore-scripts` para NPM.
5. El reporte JSON se escribe fuera de `-WhatIf`, o se omite explícitamente en simulación según la política que se adopte.

## Riesgos y Decisiones

### Riesgo 1: Parseo frágil de Winget

Mitigación:

- encapsular el parseo en funciones dedicadas,
- tolerar formatos variables,
- usar estado `unknown` en vez de inventar certeza.

### Riesgo 2: Aumento del tiempo de ejecución

Mitigación:

- aceptar más consultas por agente como costo razonable a cambio de precisión,
- documentar que `-WhatIf` sigue haciendo lecturas/consultas pero no cambios.

### Riesgo 3: Complejidad excesiva en un solo PR

Mitigación:

- mantener alcance restringido a detección de versión + reporte,
- no introducir almacenamiento histórico ni analítica avanzada.

## Criterios de Aceptación

1. Si un agente ya está en la última versión, no se ejecuta la actualización para ese agente.
2. El resumen final no llama "actualizado" a un agente que ya estaba al día.
3. La salida muestra `antes -> después` cuando hay evidencia suficiente.
4. Se genera un reporte JSON estructurado por ejecución.
5. `-WhatIf` no realiza cambios ni escritura de log/reporte destructivo.
6. Los tests siguen pasando en el runner del proyecto.

## Rama y Título Propuestos

- Rama: `feat/version-aware-update-reporting`
- PR: `feat: add version-aware updates and structured change reporting`