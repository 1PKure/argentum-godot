# Piloto remoto gratuito

El contenedor ejecuta Godot dedicado y un gateway Node sin dependencias de producción. Render termina TLS: `/game` acepta WSS y `/api/ranking` entrega solamente la tabla pública. Godot y la API de persistencia escuchan detrás del gateway; esta última únicamente en loopback.

## Configuración

- Dockerfile: `hosting/Dockerfile`; contexto: raíz del repositorio.
- Render: Web Service, Free, Virginia, despliegue automático desactivado. `render.yaml` describe la configuración. El puerto público se toma de `PORT`.
- `SUPABASE_URL`: origen HTTPS del proyecto.
- `AO_STORE_KEY`: credencial aleatoria de servidor, al menos 32 caracteres. Se guarda exclusivamente como variable de Render. La función `ao-ranking-store` contiene únicamente su SHA-256, reemplazando `__AO_STORE_KEY_SHA256__` al desplegar `hosting/supabase/index.ts`. La función autentica cada petición y permite solo las dos operaciones de ranking. Usa las credenciales internas de Supabase, sin enviarlas al dedicado ni al navegador.
- Alternativa sin Edge Function: omitir `AO_STORE_KEY` y configurar `SUPABASE_SERVICE_ROLE_KEY` para acceso directo a las mismas RPC.
- `AO_PILOT_KEY`: otra credencial aleatoria independiente, usada como invitación del piloto. Nunca reutilizar la credencial de persistencia.
- `AO_PUBLIC_ACCESS=false`, `AO_CAPACITY=8`, `AO_ALLOWED_ORIGINS`: origen exacto de la web autorizada.
- Configuración de la web privada: `server_url=wss://HOST/game?ticket=INVITACION` y `ranking_url=https://HOST/api/ranking?ticket=INVITACION`.

Aplicar primero `hosting/sql/001_ranking_store.sql` a una base nueva. Revoca acceso a anon/authenticated y mantiene RLS sin políticas de acceso de jugadores: es deliberado, el ranking solo lo escribe la autoridad del juego. El aviso informativo de Supabase por ausencia de políticas corresponde a esta decisión.

## Persistencia y recuperación

El dedicado carga la base antes de aceptar jugadores. Serializa registros y recompensas sin bloquear el bucle del juego. Confirma puntos únicamente después de persistirlos. La revisión y el identificador de operación evitan sobrescrituras y duplicados al reintentar. Las victorias conservan además su identificador de ronda. Los secretos de identidad y el registro de premios nunca se incluyen en el endpoint público.

La tabla conserva el estado anterior (`previous_payload`) para recuperación puntual. Antes de abrir al público, exportar una copia desde Supabase y verificar una restauración en una base de prueba. Esa columna no reemplaza un backup externo. Un resultado todavía no confirmado puede perderse si el proceso muere durante una caída de almacenamiento; no se presentan esos puntos como guardados. El ranking incluye automáticamente el homenaje a milusita, sin modificar sus puntos mediante los premios ordinarios.

## Verificación

```
npm --prefix hosting ci
npm --prefix hosting test
python3 tests/run_remote_persistence.py --godot RUTA_GODOT
python3 tests/run_gateway_lobby.py --godot RUTA_GODOT
```

Las pruebas cubren SQL real con PostgreSQL WASM, permisos, conflictos, reintentos, reinicio con caché nueva, fallo de almacenamiento, respuesta perdida, progreso de frames durante escrituras y cinco clientes conectados por el gateway en dos salas más práctica con bot. Las pruebas locales no certifican TLS, latencia de internet, audio o rendimiento del navegador.

## Condiciones para abrir la alpha

Validar el contenedor real, HTTPS/WSS, conexión desde dos redes externas, dos salas simultáneas, reconexión, apodos, chat, rondas, ranking tras reiniciar el servicio y una sesión sostenida con hasta ocho conexiones. Medir latencia, memoria y CPU con jugadores de Argentina. Probar sonido y FPS en navegadores reales. Si estos controles fallan, mantener el piloto y corregir la causa antes de ampliar el acceso.

Free no equivale a disponibilidad continua: Render puede suspender el servicio por inactividad y aplicar límites de uso; Supabase también tiene cuotas y políticas de pausa. Verificar los paneles y condiciones vigentes antes de abrir invitaciones. No crear recursos pagos ni escalar automáticamente. La capacidad de ocho conexiones es un límite inicial de prueba, no una capacidad certificada.

## Resultado del piloto — 23 de octubre de 2026

Render construyó y desplegó el contenedor Free en Virginia. HTTPS respondió correctamente y cinco clientes nativos de Godot completaron las 121 comprobaciones de salas y combate contra el WSS público. Para salir desde el entorno Work se usó su proxy HTTPS mediante un puente WebSocket de prueba; el recorrido remoto sí atravesó TLS y el gateway real. No equivale a una prueba de renderizado o audio en navegador.

Supabase real confirmó una victoria, rechazó su duplicación y restauró 100 puntos en otro proceso con caché local vacía. Las 105 comprobaciones locales anteriores de ranking, reinicio y pausa también pasaron, al igual que las 21 pruebas de la web. Quedan pendientes la prueba humana desde dos redes, la sesión sostenida con ocho clientes y la medición desde Argentina.
