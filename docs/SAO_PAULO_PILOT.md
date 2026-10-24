> Plan inicial de ubicación. El usuario eligió y desplegó Santiago de Chile; el estado real y la validación están en [CHILE_PILOT.md](CHILE_PILOT.md). No se creó una instancia en São Paulo.

# Prueba del dedicado en São Paulo

El usuario autorizó un servidor Vultr High Frequency de 1 vCPU / 1 GB en São Paulo por US$9 mensuales de cómputo. La prueba busca comparar los 167–178 ms de RTT observados desde Argentina con el mismo juego en otra ubicación. La disponibilidad de stock y el total final deben comprobarse en el panel antes de contratar; no agregar backups automáticos, discos, IP adicionales u otros complementos pagos sin aprobación.

## Estado y alcance

La rama `work/remote-hosting` contiene el dedicado portable y las mismas métricas del piloto de Render. `hosting/vps/compose.yaml` prepara Godot+gateway y Caddy para HTTPS/WSS. Solo Caddy publica puertos 80 y 443; el dedicado, el gateway y la API interna no publican puertos directamente en el VPS. La API de persistencia y Godot conservan además el bind a loopback dentro de su contenedor.

La web permanece privada. El gateway exige la invitación existente; su clave de almacenamiento es distinta y nunca se incluye en el navegador. La capacidad sigue limitada a ocho conexiones como límite de prueba, sin capacidad de carga certificada. El ranking continúa en Supabase y no se reinicia.

## Preparación del host

1. Iniciar sesión o crear la cuenta Vultr y completar sus requisitos de cuenta/facturación. Confirmar el precio de São Paulo para `vhf-1c-1gb` y seleccionar una imagen Linux compatible con Docker Compose v2. Configurar el acceso administrativo de forma explícita antes de provisionar.
2. Registrar la IP asignada y disponer de un hostname que resuelva a esa IP. Para una prueba puede evaluarse un subdominio de `sslip.io` que incluya la IP pública, sin comprar dominio; se debe validar DNS y emisión del certificado antes de cambiar la web. Un dominio propio puede reemplazarlo más adelante.
3. Instalar Docker Engine y Compose desde fuentes oficiales. Habilitar en el firewall únicamente HTTPS/HTTP y el acceso administrativo necesario, restringiendo este último al administrador. No publicar 7777, 7778 ni 10000.
4. Clonar el repositorio y fijar el commit que se pruebe. En `hosting/vps`, copiar `.env.example` a `.env` y completar el hostname, SHA exacto, URL Supabase y las dos claves existentes. Restringir ese archivo al administrador con permisos 600. Transferir las claves por un canal autorizado y cifrado; no pegarlas en chats, logs ni archivos versionados.
5. Ejecutar `docker compose up -d --build --wait`. Caddy obtiene y renueva TLS; sus volúmenes conservan los certificados. Si el proveedor no permite salida o DNS/ACME falla, resolverlo antes de conectar usuarios. El contenedor de arena debe estar saludable y `/healthz` devolver 200.

## Cambio controlado y comparación

- Programar el cambio con las salas vacías. Durante la transición debe haber **un solo dedicado aceptando jugadores y escribiendo ranking**: los contadores/identificadores de ronda no constituyen una arquitectura activa/activa de dos servidores.
- Mantener inicialmente el gateway de São Paulo inaccesible para jugadores hasta verificar TLS y la persistencia cargada. Para el corte, detener el anterior, iniciar el nuevo con una lectura fresca de Supabase y cambiar únicamente `server_url` y `ranking_url` en la configuración de la web privada. Se conserva un despliegue de retorno con la configuración anterior.
- Verificar WebSocket real, crear sala, bot, duelo, reinicio y lectura de ranking. Comparar desde la misma conexión del jugador durante 30–60 segundos: RTT p50/p95, confirmación de movimiento, tiempo del manejador y cola visual. Repetir cambios de dirección y combates. Medir en Argentina; una medición desde Work no representa esa ruta.
- Si no mejora, devolver la web al endpoint anterior y reactivar un único dedicado. Detener el VPS no necesariamente detiene la facturación: revisar y eliminar el recurso de prueba cuando el usuario decida descartarlo. No eliminarlo ni destruir datos sin la autorización correspondiente.

La configuración está preparada; la provisión, el certificado, el despliegue y la reducción de latencia solo se consideran completados después de verificarlos en el host real. Una ubicación más cercana puede mejorar el RTT; no garantiza reproducir la respuesta de un servidor local.
