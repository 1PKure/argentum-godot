# Entrada pública de AO Mini

El usuario publicó la copia estática en Cloudflare Workers Static Assets y la renombró a `ao-mini`. La URL comunicada es `https://ao-mini.pulidomatias.workers.dev`. El sitio ya responde en un navegador real. Esto reemplaza la propuesta de `pages.dev`; no requiere recrear la web en Pages.

El ZIP público elimina la invitación privada de `arena-config.json`: conecta a `/game` y consulta `/api/ranking` sin ticket. El servidor continúa privado hasta aplicar explícitamente `hosting/vps/public-beta.yaml`. Este archivo es una superposición optativa; no modifica el valor privado predeterminado del despliegue base.

## Cambio preparado

- Habilitar acceso público del juego y la tabla pública del ranking.
- Autorizar exactamente el origen de Cloudflare y conservar el origen de la antigua web privada para retorno. Sin comodines de CORS ni WebSocket.
- Mantener ocho conexiones, el mismo juego, imagen Docker, TLS y persistencia en Supabase. No exponer la API de almacenamiento ni sus credenciales.
- Mantener Render Virginia suspendido y un único dedicado escritor en Chile.

Antes de activar: recuperar el acceso administrativo a Vultr, confirmar la apertura pública y comprobar salas vacías. Aplicar cuando el archivo esté presente en el VPS:

```text
docker compose --env-file hosting/vps/.env -p ao-mini -f hosting/vps/compose.yaml -f hosting/vps/public-beta.yaml config --quiet
docker compose --env-file hosting/vps/.env -p ao-mini -f hosting/vps/compose.yaml -f hosting/vps/public-beta.yaml up -d --no-build
```

No reconstruir ni cambiar el commit de la imagen durante este ajuste. La superposición no contiene secretos. Compose debe detener el contenedor anterior antes de arrancar el nuevo.

Después: comprobar salud, ranking por HTTPS sin ticket, CORS exacto, rechazo de origen incorrecto, WSS público desde el origen real y una partida desde la web. Probar descarga del PCK y WASM comprimido y sonido en navegador. La prueba del modo público del gateway verifica la tabla saneada, el origen permitido y la protección de la API interna; no sustituye la verificación del despliegue real.

## Retorno a privado

Ejecutar el mismo `up -d --no-build` usando únicamente el archivo base `hosting/vps/compose.yaml`. La página estática de Cloudflare seguirá publicada, pero el gateway volverá a exigir la invitación privada. No elimina ni reinicia el ranking y no reactiva Render.

## Estado de esta preparación

La entrada pública todavía no se considera activa hasta verificarla en el VPS. La primera recuperación del acceso administrativo devolvió `Invalid username/password`; no se cambió la configuración remota ni se asumió que el ingreso hubiera funcionado.

El usuario aplicó después la superposición desde su consola. Se verificaron salud 200/capacidad ocho, ranking público 200 con CORS del origen real, WSS sin ticket y paquete inicial de Godot, rechazo WSS 403 para otro origen y API interna no expuesta (404). La prueba de renderizado de Work está limitada por la falta de WebGL2 en ese navegador; el juego requiere verificación final en el navegador del usuario.

## Limpieza de perfiles de prueba

El usuario pidió conservar solo el homenaje a milusita y eligió explícitamente `1kurep` (200 puntos, dos victorias de bot) frente a `1kurelol` (100 puntos). La revisión observada antes del mantenimiento era 19; no se fija esa revisión en el comando: se carga y verifica la vigente cuando el dedicado está detenido.

`bash hosting/vps/clean-ranking.sh` detiene el único escritor, conserva su imagen y usa un contenedor administrativo efímero para ejecutar `hosting/gateway/clean-ranking.mjs`. Antes de guardar, crea un respaldo exclusivo con permisos 0600 en el directorio local `hosting/vps/ranking-backups` (0700, excluido de Git y de la imagen Docker). Mantiene intactos el identificador, hash de propiedad, victorias e historial de premios del perfil elegido. Retira los otros perfiles y solo sus premios, actualiza coherentemente la revisión y la tabla pública, guarda mediante CAS y verifica la respuesta completa.

El bloque EXIT reinicia la misma configuración pública incluso si falla el mantenimiento. Repetir la limpieza cuando ya quedan solo esas dos entradas no vuelve a modificar la revisión. No hay un endpoint público de administración ni credenciales en el comando. Los jugadores descartados pueden registrarse nuevamente al reconectar: esto limpia la clasificación, no constituye un bloqueo de usuarios.

La limpieza queda pendiente hasta que se ejecute el comando en el VPS y se verifique el ranking servido tras el reinicio.
