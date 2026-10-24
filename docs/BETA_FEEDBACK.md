# Primera calibración con feedback de jugadores

Esta actualización conserva el combate rápido de AO Mini y da un poco más de tiempo para reaccionar. Los daños, recursos de clase y recuperación del jugador quedan iguales para no mezclar otro balance completo con el cambio de ritmo.

| Parámetro | Publicado anteriormente | Nuevo |
| --- | ---: | ---: |
| Paso del jugador | 140 ms | 155 ms |
| Lanzamiento del jugador | 950 ms | 1050 ms |
| Paso del bot mago/druida/cazador | 124 ms | 160 ms |
| Paso del bot semimágico | 140 ms | 170 ms |
| Lanzamiento del bot | 1150 ms | 1300 ms |
| Intervalo propio de poción del bot | 280 ms | 340 ms |
| Reacción a parálisis, si el lanzamiento está disponible | 520–700 ms | 650–850 ms |

El bot mantiene sus combos y usa las mismas validaciones del servidor. Un reloj de última poción evita que la desaparición momentánea de la necesidad de curarse acorte el intervalo propio. Los tests de persecución ahora comprueban que siga pudiendo acertar un paralizar a un rival que corre más rápido; no exigen la frecuencia de aciertos del bot anterior. Los tests de decisión siguen verificando que intente volver a paralizar cuando corresponde y que conserve el maná mientras persigue.

Aliento de Dragón (ID 4) queda retirado del libro y de la autoridad del servidor; peticiones de un cliente anterior se rechazan sin gastar maná ni hacer daño. Los accesos guardados se filtran con la validación existente.

## Modo clásico

En el lobby: **Controles / Jugar clásico**. En combate: **Jugar clásico** y **Controles** son accesibles directamente sobre la consola y la configuración sigue disponible en el menú.

El modo clásico desactiva el apuntado desde macros, oculta su barra y presenta objetos y hechizos simultáneamente: elegir hechizo, pulsar Lanzar o su tecla configurable, y seleccionar el objetivo. Las pociones siguen disponibles con clic y Usar. No borra accesos personalizados ni cambia las reglas de combate. La elección se guarda por perfil local; se puede volver a macros en cualquier momento. La lista de objetos conserva desplazamiento para acceder al equipo completo.

## Validación

Godot 4.7.2: 14 suites de lógica/UI con 401 comprobaciones, incluido guardado del modo, perfiles separados, regreso a macros sin perder asignaciones, bloqueo de macros en clásico, Lanzar, geometría del HUD en tres tamaños, retiro del hechizo en servidor y reglas/decisiones del bot. Prueba WebSocket real con cinco clientes y 124 comprobaciones: cuatro clientes en dos salas aisladas, luego práctica con bot. Tres tests del mantenimiento con comandos simulados: éxito, fallo de construcción y fallo de salud con restauración de configuración. Export web release exitoso. La importación ETC2/ASTC se explicita en el proyecto para que el preset existente con opción móvil se pueda exportar de forma reproducible.

El ZIP conserva el motor web, JavaScript, audio, página y configuración pública del paquete anterior; sustituye el PCK, actualiza su tamaño en el loader y añade `release.json` con SHA de código y hash del PCK. El formato y versión Godot del PCK coinciden con el anterior (4.7.2). No se incluyen credenciales. La sensación y el audio deben probarse en navegadores de jugadores después del despliegue; las pruebas headless no certifican esos aspectos.

## Aplicación en el VPS existente

Avisar una ventana de mantenimiento y pedir cerrar el juego. Publicar el ZIP completo en el Worker existente de Cloudflare, sin crear otro dominio. Aplicar el mismo commit del juego en el único dedicado de Chile:

```bash
cd /opt/ao-mini &&
git fetch origin <SHA_COMPLETO> &&
git show FETCH_HEAD:hosting/vps/update-game.sh > /tmp/ao-mini-update-game.sh &&
bash /tmp/ao-mini-update-game.sh <SHA_COMPLETO>
```

La rutina no cambia el checkout de trabajo: construye desde `git archive` del commit exacto en un directorio nuevo y privado. Respalda `.env` con permisos 0600, detiene el juego para dejar memoria disponible, construye y espera salud de la nueva imagen. Ante fallos intenta restaurar automáticamente la configuración e imagen anteriores y conserva el error para revisión. La construcción puede tardar varios minutos con el juego sin servicio. Render permanece suspendido; no hay segundo escritor ni cambios de esquema, ranking, credenciales u orígenes públicos. No se requiere fusionar un PR para aplicar una imagen por SHA.

Después verificar salud HTTPS, ranking conservado y una partida real desde la web tras cerrar y recargar. Probar ambos modos, cambio de teclas, pociones y bot. Si el problema es visual del cliente, volver al ZIP anterior en Cloudflare. Para revertir el dedicado, respaldar la configuración vigente y restaurar el archivo `before-update-...env` de este mantenimiento, luego ejecutar el `up -d --no-build --wait` con los archivos compose base y public-beta; conservar siempre un solo escritor. No eliminar volúmenes ni la base de datos.

Estado: implementación y paquete preparados; el servidor público no se actualiza hasta ejecutar el mantenimiento. No se configura un despliegue automático al publicar cambios en GitHub.
