# Arquitectura de AI-CLI-Sentinel

## Visión General

AI-CLI-Sentinel es un sistema de seguridad diseñado para monitorear y proteger interfaces de línea de comandos mediante el uso de listas de permitidos (allowlists) y análisis de comportamiento.

## Componentes Principales

### 1. Script Principal (`AI-CLI-Sentinel.ps1`)

El script principal contiene la lógica de seguridad y proporciona las siguientes funcionalidades:

- **Monitoreo**: Observación pasiva de actividad de agentes CLI
- **Bloqueo**: Prevención de ejecución de agentes no autorizados
- **Permitir**: Gestión de excepciones y listas de permitidos

### 2. Configuración (`agents.allowlist.json`)

Archivo JSON que contiene:

- Lista de agentes permitidos
- Políticas de seguridad por defecto
- Configuración de logging y monitoreo

### 3. Sistema de Logging

Todos los eventos son registrados en archivos de log con:

- Timestamp
- Nivel de severidad (INFO, WARNING, ERROR)
- Mensaje descriptivo
- Contexto adicional cuando aplica

## Aislamiento y Seguridad

### Volume Shadow Copy Service (VSS)

**VSS (Volume Shadow Copy Service)** es un servicio de Windows que permite crear instantáneas (snapshots) del sistema de archivos antes de realizar cambios críticos. En AI-CLI-Sentinel, VSS se utiliza para crear puntos de restauración del sistema antes de actualizar agentes de IA.

#### ¿Por qué usar VSS?

- **Resiliencia**: Permite restaurar el sistema a un estado anterior si una actualización causa problemas
- **Seguridad**: Protege contra cambios no deseados o maliciosos durante actualizaciones
- **Confianza**: Permite realizar actualizaciones con mayor seguridad

#### Implementación en AI-CLI-Sentinel

El script utiliza el cmdlet `Checkpoint-Computer` de PowerShell para crear puntos de restauración:

```powershell
Checkpoint-Computer -Description "AI-Sentinel-Update" -RestorePointType APPLICATION_INSTALL
```

**Nota importante**: La creación de puntos de restauración VSS requiere privilegios de Administrador y puede fallar en algunos entornos. El script maneja estos casos permitiendo al usuario decidir si continuar sin VSS.

#### Restauración desde VSS

Si necesitas restaurar el sistema después de una actualización problemática, puedes usar:

```powershell
# Ver puntos de restauración disponibles
Get-ComputerRestorePoint

# Restaurar a un punto específico
Restore-Computer -RestorePoint <ID>
```

Para más detalles sobre recuperación, consulta [recovery.md](recovery.md).

### Otras Medidas de Aislamiento

- **Espacios de nombres aislados**: Cada agente opera en su propio contexto
- **Control de acceso**: Validación de permisos antes de ejecución
- **Sandboxing**: Ejecución controlada de comandos

### Medidas de Seguridad

1. **Validación de entrada**: Todos los parámetros son validados antes de procesamiento
2. **Principio de menor privilegio**: El script opera con permisos mínimos necesarios
3. **Logging completo**: Todas las acciones son registradas para auditoría
4. **Política por defecto**: Denegar por defecto, permitir explícitamente

## Flujo de Ejecución

```
[Inicio] → [Cargar Configuración] → [Validar Parámetros] → [Ejecutar Acción] → [Registrar Log] → [Fin]
```

## Extensibilidad

El sistema está diseñado para ser extensible:

- Nuevos tipos de acciones pueden agregarse fácilmente
- Múltiples formatos de configuración pueden ser soportados
- Integración con sistemas externos mediante APIs

## Consideraciones de Rendimiento

- Carga de configuración: Lazy loading cuando es posible
- Logging asíncrono: No bloquea la ejecución principal
- Caché de configuración: Reduce accesos a disco
