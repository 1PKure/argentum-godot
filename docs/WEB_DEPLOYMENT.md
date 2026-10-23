# Preparación de la página de AO Mini

La web permanece privada. No se contrata hosting, no se abren accesos y no se
crean cuentas de jugadores en esta entrega. El dedicado continúa siendo local.

## Configuración sin reexportar el juego

El sitio conserva su propio repositorio en Sites. `dist/arena-config.json` es
la configuración pública de despliegue; el cliente la lee antes de iniciar:

```json
{
  "server_url": "wss://127.0.0.1:7777",
  "ranking_url": null,
  "ranking_refresh_seconds": 30
}
```

Al disponer de un dedicado remoto, reemplazar `server_url` por su WSS real y
volver a desplegar el sitio. El pack no necesita recompilarse para ese cambio.
`runtime-config.js` valida protocolo, credenciales embebidas y fragmentos. El
arranque pasa `--server-url=...` como argumento de usuario a Godot; la pantalla
de conexión lo usa como valor inicial. Nativo conserva su configuración local.
La validación no comprueba disponibilidad del host: el cliente conserva el
flujo de conexión/error/cancelación. No se aceptan overrides desde querystring.
La configuración se sirve sin caché y no debe contener secretos o identidades.

## Ranking independiente preparado

Mientras `ranking_url` sea null no se consulta ninguna API adicional. La tabla
actual sigue recibiendo el ranking del cliente conectado. No se presenta como
un ranking autónomo online. La fila honorífica no representa partidas reales.

Cuando exista un endpoint HTTPS con el snapshot público schema1 de
ArenaRankingStore, configurar su URL (mismo origen o CORS para el origen privado).
La página podrá actualizarlo sin iniciar Godot: intervalo30s, sin consultas
solapadas, timeout8s, pausa en pestañas ocultas, cancelación al salir. Fetch sólo envía credenciales al mismo origen y rechaza redirecciones. Se validan datos antes de sustituir
la tabla; un fallo conserva la última tabla, marcada como no disponible. Nunca
exponer el archivo privado de identidades/rondas, hashes o secretos.

**Todavía falta** implementar/alojar ese endpoint y su almacenamiento durable;
esta entrega no aprovisiona una API, base de datos ni servidor remoto. Las skins
siguen siendo locales. No hacen falta cuentas para la primera prueba online.

## Orden de la prueba remota

1. Conservar la versión aprobada del gameplay y el presupuesto cero.
2. Elegir/provisionar un proceso Godot gratuito con WSS; verificar que no requiera
   cobros. La web estática y el dedicado son componentes distintos.
3. Resolver persistencia y respaldos antes de usar un disco efímero.
4. Configurar el WSS y, al estar disponible, la URL pública del ranking.
5. Probar dos navegadores en redes distintas: conexión, nick, sala, duelo,
   reconexión, chat, resultado/revancha y ranking tras reiniciar el dedicado.
6. Medir FPS/audio, RAM/CPU/egreso y estabilidad prolongada en el host real.
   Las pruebas locales y del contrato de API no demuestran esa capacidad.

La portada mantiene la identidad y tipografías aprobadas. Se añade ayuda de
controles orientada al jugador; no contiene instrucciones de desarrollo.
