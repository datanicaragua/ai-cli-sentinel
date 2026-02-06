# Política de Seguridad

## Versiones Soportadas

Actualmente mantenemos seguridad para las siguientes versiones:

| Versión | Soportada          |
| ------- | ------------------ |
| 1.0.0-rc1 | :white_check_mark: |
| < 1.0.0-rc1 | :x:                |

## Reportar una Vulnerabilidad

Tomamos la seguridad de AI-CLI-Sentinel muy en serio. Si descubres una vulnerabilidad de seguridad, agradecemos tu ayuda para divulgarla de manera responsable.

### Proceso de Divulgación Responsable

1. **NO** divulgues la vulnerabilidad públicamente
2. **NO** crees un issue público en GitHub
3. En su lugar, usa el [formulario de seguridad](.github/ISSUE_TEMPLATE/security_report.md) que crea un issue privado
4. Proporciona detalles suficientes para reproducir el problema
5. Espera nuestra respuesta antes de hacer pública la vulnerabilidad

### Qué Incluir en tu Reporte

- Descripción detallada de la vulnerabilidad
- Pasos para reproducir el problema
- Impacto potencial de la vulnerabilidad
- Versión afectada del software
- Cualquier solución o mitigación que hayas identificado

### Qué Esperar

- **Confirmación**: Recibirás confirmación de que recibimos tu reporte dentro de 48 horas
- **Evaluación**: Evaluaremos la vulnerabilidad y te mantendremos informado del progreso
- **Resolución**: Trabajaremos en una solución y te notificaremos cuando esté disponible
- **Divulgación**: Coordinaremos la divulgación pública después de que se haya aplicado un parche

### Recompensas

Actualmente no ofrecemos un programa de recompensas por errores, pero agradecemos enormemente tu contribución a la seguridad del proyecto.

## Mejores Prácticas de Seguridad

### Para Usuarios

1. **Mantén actualizado**: Siempre usa la última versión del script
2. **Revisa configuración**: Verifica regularmente tu `agents.allowlist.json`
3. **Monitorea logs**: Revisa los logs regularmente para actividad sospechosa
4. **Principio de menor privilegio**: Ejecuta el script con permisos mínimos necesarios
5. **Backups**: Mantén backups regulares de tu configuración

### Para Desarrolladores

1. **Validación de entrada**: Siempre valida y sanitiza la entrada del usuario
2. **Principio de menor privilegio**: El código debe operar con permisos mínimos
3. **Logging seguro**: No registres información sensible en logs
4. **Dependencias**: Mantén las dependencias actualizadas
5. **Revisión de código**: Todas las contribuciones son revisadas por seguridad

## Historial de Seguridad

Las vulnerabilidades corregidas se documentarán aquí después de que se haya publicado un parche.

## Contacto

Para preguntas sobre seguridad que no sean vulnerabilidades, puedes:

- Abrir un issue regular con la etiqueta `security-question`
- Contactar a los mantenedores del proyecto

---

**Gracias por ayudar a mantener AI-CLI-Sentinel seguro para todos.**
