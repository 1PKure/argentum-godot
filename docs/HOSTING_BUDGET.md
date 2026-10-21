# AO Mini · hosting y costo cero

Evaluación: 21 de octubre de 2026. No se contrataron servicios, añadieron tarjetas ni habilitaron cobros. La web conserva su audiencia privada. El presupuesto autorizado sigue siendo cero; un servicio que requiere pagar se descarta.

## Qué funciona ahora

La web privada aloja la portada AO Mini / PvP Arena y el cliente Godot real, cargado sólo al pulsar Jugar. Ofrece presentación, clases, vistas reales de las cuatro arenas y ranking recibido del dedicado mientras el cliente está conectado. El homenaje a milusita se identifica como tal; no se inventan jugadores, actividad o victorias.

El dedicado sigue siendo local mediante `tools/Start-PrivateWebTest.cmd`. WSS precargado: `wss://127.0.0.1:7777`. Localhost es la PC del visitante: compartir el enlace no conecta otras PCs al dedicado del desarrollador. La página y el proceso Godot son dos componentes de hosting distintos. No se desplegó un servidor remoto ni un endpoint HTTP de ranking. La tabla web no refresca independientemente del cliente conectado.

## Capacidad medida, no prometida

Runner reproducible: `python tests/run_hosting_load.py --godot <Godot4.7.2> --clients 32 --seconds 20 --output <carpeta-nueva>` desde la raíz. Ejecutar importación headless del proyecto antes del runner. Requiere Linux/procfs. El runner crea perfiles aislados y un ranking temporal, sin tocar el ranking real.

| Clientes / salas | Duración activa | Pico RAM del dedicado | CPU media de un núcleo | RTT chat p50 / p95 | Fallos |
|---|---:|---:|---:|---:|---:|
| 8 / 4 | 12 s | 150,24 MiB | 7,19% | 7 / 14 ms | 0 |
| 32 / 16 | 20 s | 150,12 MiB | 11,01% | 7 / 10 ms | 0 |

JSON originales en `docs/hosting/`. Un proceso dedicado y clientes Godot headless reales, WebSocket loopback, sin TLS, sin render, sin latencia ni pérdida artificial. Cada cliente pide movimiento cada150ms, curación propia cada1050ms, poción cada300ms y chat cada1500ms. No equivale a duelos completos con bot/daño/ranking/escrituras, una prueba prolongada ni a usuarios reales por Internet. No se midieron bytes de salida ni capacidad de un proveedor. Los 64 clientes/32 salas configurados siguen siendo un techo de software sin validación de carga completa. CPU/RAM dependen del host; no dimensionar un plan usando sólo esta muestra.

## Opciones gratuitas verificadas

| Componente / opción | Costo de plan | Condiciones relevantes | Decisión |
|---|---|---|---|
| Web privada actual | Sin nueva contratación | Acceso privado existente; no se modificó audiencia | Mantener para estas pruebas |
| Web estática Cloudflare Pages Free | US$0 | 500 builds/mes, 20.000 archivos, máximo25MiB por archivo. Assets estáticos sin Functions: solicitudes gratuitas ilimitadas | Alternativa técnica; no se migró ni publicó allí |
| Dedicado Render Free Web Service | US$0 dentro de cuotas | WSS soportado; duerme tras15min sin tráfico entrante y despertar~1min. 750h gratuitas/workspace/mes. Disco efímero; sin disco persistente gratis. Puede suspenderse al agotar cuotas sin medio de pago | Piloto descartable posible, todavía no desplegado; ranking actual en archivo se perdería al reiniciar/dormir/redeploy |

El pack y el WASM comprimido de esta web caben individualmente bajo25MiB; los tests recorren todos los assets. Este control no mide ancho de banda mensual. Subdominio del proveedor evita comprar dominio. No se presupone que todos los proveedores ofrezcan privacidad gratuita equivalente a la actual.

Render puede cobrar excedentes de ancho de banda/build si hay medio de pago; sin él suspende en lugar de cobrar. Por la política del proyecto no se añadirán tarjetas, planes de pago ni autoescalado con cargos. El PostgreSQL Free de Render caduca a30días: no resuelve persistencia permanente gratis. No se adoptó un servicio de base de datos.

## Próxima prueba antes de invitar jugadores

1. Elegir una cuenta/proveedor gratuito disponible con WSS y proceso Godot, sin cobros ni exposición adicional no autorizada. No hay ninguna cuenta de hosting remoto aprovisionada en este trabajo.
2. Resolver almacenamiento durable y respaldo del ranking si el host es efímero. No presentar el ranking en archivo como persistente en ese host.
3. Desplegar, configurar URL WSS real/certificado, conectar dos navegadores desde redes diferentes y comprobar salas, chat, bot, ranking, reconexión y reinicio. Conservar privacidad de la web.
4. Ejecutar prueba prolongada en ese host, midiendo CPU/RAM/egreso y latencia real, con carga representativa de bots y combate. Recién entonces fijar un aforo inicial y supervisar cuotas.

## Fuentes oficiales

Consultadas para esta evaluación; cuotas/precios pueden cambiar.

- https://developers.cloudflare.com/pages/platform/limits/
- https://developers.cloudflare.com/pages/functions/pricing/
- https://render.com/docs/free
- https://render.com/docs/websocket

## Identidad y datos conservados

El juego se llama AO Mini, subtítulo PvP Arena; eslogan: «Entrá a la arena. Que hable tu habilidad.». Cambia títulos, conexión, lobby, HUD, menú y ranking. La carpeta de datos conserva el identificador histórico ArgentumGodot mediante un directorio personalizado (y override Linux), para conservar preferencias/progreso/ranking. Se verificó que Linux resuelve el mismo `user://` antes y después. Protocolo24 sin cambios de red; los clientes existentes requieren actualizar para ver el nombre nuevo.

Validación de esta entrega:111 comprobaciones GUI nativas sobre el pack exportado (80host/17guest/14solo),14 tests del sitio (incluye DOM simulado, contrato seguro de ranking, carga/cierre del cliente, tabs, origen de mensajes, fallback fullscreen e integridad del motor/PCK). Capturas nativas revisadas. No se ejecutó navegador automatizado: el diseño responsive, sonido y flujo completo del iframe en navegador requieren prueba manual; no se afirma un E2E web remoto.
