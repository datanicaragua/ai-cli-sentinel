# v2.0.0 - Fortalecimiento de Seguridad y Migración de la Raíz de Confianza

Esta versión introduce mejoras críticas de seguridad diseñadas para proteger entornos de desarrollo de IA contra ataques sofisticados a la cadena de suministro (ej. gusano Mini Shai-Hulud) observados hasta junio de 2026.

⚠️ **CAMBIOS IMPORTANTES (BREAKING CHANGES)**

Esta versión cambia drásticamente cómo se manejan los respaldos y las políticas de confianza para prevenir la exfiltración de credenciales.

1. **Rutas de Respaldo Estrictas:** El parámetro `-BackupSecrets` ya no copia archivos al Escritorio por defecto. DEBES proporcionar un destino explícito y seguro (que no se sincronice en la nube) usando `-BackupPath`.
2. **Raíz de Confianza Administrada:** El archivo `agents.allowlist.json` ya no se lee desde el directorio local del repositorio. Ahora debe residir en un directorio protegido del sistema operativo.

## 🚀 Guía de Migración y Primeros Pasos

Para asegurar que tu herramienta funcione correctamente sin emitir advertencias de seguridad, abre una consola de PowerShell **como Administrador** y ejecuta el siguiente comando para establecer tu política de seguridad:

```powershell
# 1. Crear el directorio protegido por el sistema
$PolicyDir = "$env:ProgramData\AI-CLI-Sentinel\policy"
New-Item -Path $PolicyDir -ItemType Directory -Force

# 2. Migrar la lista de agentes aprobados
Copy-Item ".\src\agents.allowlist.json" -Destination "$PolicyDir\agents.allowlist.json" -Force

Write-Host "Migración completada. La raíz de confianza está asegurada en: $PolicyDir" -ForegroundColor Green
```

## 🛡️ Actualizaciones Adicionales de Seguridad

- **Eliminación de Vulnerabilidades TOCTOU:** Las actualizaciones de paquetes (`npm`, `uv`, `winget`) ahora evalúan y fijan (pin) las versiones exactas, eliminando el riesgo de inyección al usar etiquetas móviles como `@latest`.
- **Cobertura de Pruebas (Pester):** 100% de éxito en la validación de los nuevos límites de seguridad.
