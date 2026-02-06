# Guía de Recuperación ante Desastres

## Escenarios de Recuperación

### 1. Pérdida del Archivo de Configuración

**Síntomas:**
- Error al cargar `agents.allowlist.json`
- El script no puede iniciar

**Solución:**
1. Restaurar desde backup (si existe)
2. Si no hay backup, crear nuevo archivo desde plantilla:
   ```powershell
   Copy-Item "src\agents.allowlist.json.example" "src\agents.allowlist.json"
   ```
3. Reconfigurar agentes permitidos según necesidades

### 2. Bloqueo Accidental de Agente Crítico

**Síntomas:**
- Un agente legítimo no puede ejecutarse
- Errores de permisos en operaciones normales

**Solución:**
1. Editar `agents.allowlist.json` manualmente
2. Agregar el agente a la lista de permitidos:
   ```json
   {
     "name": "nombre-del-agente",
     "allowed": true,
     "reason": "Agente crítico del sistema",
     "addedDate": "2026-02-06"
   }
   ```
3. Reiniciar el servicio o reejecutar el script

### 3. Corrupción de Logs

**Síntomas:**
- Archivos de log no se pueden leer
- Errores al escribir logs

**Solución:**
1. Detener el script
2. Eliminar o renombrar archivos de log corruptos:
   ```powershell
   Remove-Item "logs\sentinel.log" -Force
   ```
3. Reiniciar el script (creará nuevos logs)

### 4. Restauración Completa del Sistema

**Procedimiento:**
1. **Backup de configuración actual:**
   ```powershell
   Copy-Item "src\agents.allowlist.json" "backup\agents.allowlist.json.$(Get-Date -Format 'yyyyMMdd')"
   ```

2. **Restaurar desde backup:**
   ```powershell
   Copy-Item "backup\agents.allowlist.json.YYYYMMDD" "src\agents.allowlist.json" -Force
   ```

3. **Verificar integridad:**
   ```powershell
   Get-Content "src\agents.allowlist.json" | ConvertFrom-Json
   ```

4. **Reiniciar servicios**

## Procedimientos de Backup

### Backup Automático (Recomendado)

Configurar tarea programada para backups diarios:

```powershell
# Script de backup
$backupDir = "backup"
$date = Get-Date -Format "yyyyMMdd"
New-Item -ItemType Directory -Path $backupDir -Force
Copy-Item "src\agents.allowlist.json" "$backupDir\agents.allowlist.json.$date"
```

### Backup Manual

Ejecutar antes de cambios importantes:

```powershell
.\scripts\backup-config.ps1
```

## Verificación Post-Recuperación

Después de cualquier recuperación, verificar:

1. ✅ El script inicia sin errores
2. ✅ La configuración se carga correctamente
3. ✅ Los logs se escriben correctamente
4. ✅ Los agentes permitidos funcionan normalmente
5. ✅ Los agentes bloqueados están correctamente identificados

## Contacto de Emergencia

Para situaciones críticas que no pueden resolverse con esta guía:

- Crear un issue con etiqueta `[SECURITY]` en GitHub
- Contactar a los mantenedores del proyecto

## Prevención

Para evitar la necesidad de recuperación:

1. **Backups regulares**: Automatizar backups diarios
2. **Validación antes de cambios**: Probar cambios en entorno de desarrollo
3. **Documentación**: Mantener documentación actualizada
4. **Monitoreo**: Revisar logs regularmente para detectar problemas temprano
