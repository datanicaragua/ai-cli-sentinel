# Evaluación de Inclusión: Aider CLI

## Contexto

Se evaluó la incorporación de `aider` al flujo de actualización de AI-CLI-Sentinel.

Evidencia local observada:

- `aider --version` responde correctamente.
- `uv tool list` reporta `aider-chat v0.86.2`.
- El ejecutable resuelto está en `%USERPROFILE%\\.local\\bin\\aider.exe`.
- No se encontró canal oficial por `winget` para `aider` en este entorno.
- No existe paquete NPM oficial equivalente para el `aider` utilizado.

## Estándar Aplicado

Se aplicaron los criterios operativos del proyecto para decidir inclusión:

1. **Ajuste de alcance**: es un asistente de IA en terminal, coherente con los CLIs del repositorio.
2. **Canal de actualización confiable**: el canal válido aquí es `uv tool` con paquete `aider-chat`.
3. **Observabilidad de versión**: se puede leer versión instalada con `uv tool list`.
4. **Fuente de versión objetivo**: se consulta versión publicada en PyPI (`https://pypi.org/pypi/<name>/json`).
5. **Idempotencia**: solo se actualiza cuando versión instalada y objetivo difieren.
6. **Trazabilidad**: el resultado entra al reporte estructurado y al resumen por estados.

## Decisión

**Aprobado** incluir `aider` en AI-CLI-Sentinel bajo gestor `uv`.

Representación en allowlist:

- `uv`: `aider-chat`

## Implementación Derivada

Este PR añade:

- Nuevo manager `uv` en `agents.allowlist.json`.
- Lógica de actualización `uv tool` en `AI-CLI-Sentinel.ps1`.
- Consulta de versión objetivo desde PyPI para comparación previa.
- Estados del resumen alineados con el contrato existente (`updated`, `would-update`, `already-current`, `not-installed`, `failed`, `unknown`).
- Tests y documentación actualizados.

## Riesgos y Mitigaciones

- **Riesgo**: indisponibilidad de PyPI en tiempo de ejecución.
  - **Mitigación**: clasificar como `unknown` sin forzar actualización ciega.
- **Riesgo**: ausencia de `uv` en host destino.
  - **Mitigación**: prerequisito explícito en documentación.

## Resultado Esperado

Con `aider-chat` instalado por `uv tool`, el script debe:

- detectar versión instalada,
- comparar con versión objetivo de PyPI,
- decidir actualización o estado al día,
- registrar resultado en resumen y reporte JSON.
