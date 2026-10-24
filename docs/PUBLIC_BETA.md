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
