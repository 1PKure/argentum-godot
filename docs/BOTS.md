# Bot de práctica PvP

Primera IA de práctica, ejecutada por el dedicado. Usa los nueve presets y el balance aceptado; no añade PvE, cuentas, servicios externos ni aprendizaje automático. La conexión dorada/blanca integrada en Alpha por PR9 se conserva.

## Probar

1. GitHub Desktop: Fetch origin, elegir `work/arena-practice-bot` y Pull origin.
2. Cerrar el dedicado anterior y abrir `tools/Start-PrivateWebTest.cmd`. Cliente y servidor requieren la misma revisión: protocolo **6**.
3. Recargar la web privada con Ctrl+F5; WSS sigue precargado.
4. Con un único jugador humano conectado: **Bot**, elegir clase y **Activar bot**.
5. Jugar con Lanzar/macros, CTRL, pociones y meditación habituales. El rival se mueve, ataca y se recupera con las mismas funciones autoritativas.
6. **Bot → Reiniciar práctica** prepara ambos personajes con sus presets, recursos/estados limpios y posiciones iniciales. También permite cambiar la clase del bot. Reconstruye inventario/equipo del preset; los macros personalizados de cada clase se conservan.
7. **Quitar bot** lo retira. Si cualquiera muere, la IA se detiene y la consola comunica el resultado; reiniciar es explícito. Reaparecer o cambiar tu clase sigue siendo libre durante las pruebas, pero no inicia automáticamente una nueva práctica terminada.

El menú Bot bloquea entradas locales mientras está abierto, igual que Clases. El servidor y el rival siguen funcionando: no es una pausa global del combate online.

## Convivencia con jugadores

Hay como máximo un bot en esta arena de práctica. Se permite sólo con un humano, ligado a su conexión. La entrada de un segundo humano lo elimina **antes** de construir su snapshot; ambos quedan en la arena PvP existente. No se reactiva automáticamente cuando alguien sale. Una vez solo, el jugador restante puede activarlo.

Desconectar al dueño elimina el bot, sus efectos, recargas y propiedad. Una reconexión empieza sin bot. El emisor real del RPC determina al dueño; no se aceptan IDs de dueño elegidos por el cliente. Solicitudes con nonce repetido, clase descartada o varios humanos no crean entidades ni restablecen personajes. Los reinicios tienen un límite de frecuencia de 400 ms; quitarlo no espera ese intervalo.

## Comportamiento y reglas

- Movimiento cardinal con búsqueda de camino sobre las casillas transitables y ocupación real. Decisiones cada 150 ms, con 600 ms iniciales de reacción; no acumula turnos atrasados.
- Guerrero, Paladín, Asesino y Bandido se acercan para golpe frontal; los híbridos pueden usar control, remover y curación permitidos. Mago, Clérigo, Bardo y Druida mantienen distancia y eligen daño disponible. Cazador busca una posición con línea de tiro y dispara con arco/munición equipados.
- Los atacantes a distancia intentan conservar 4–6 casillas y alternan desplazamientos laterales; la selección de hechizos es una heurística pequeña, con Descarga/Misil y Apocalipsis al rematar cuando su clase/maná lo permiten.
- Root, equipo, daño, maná, pociones, meditación y recargas se resuelven en `PlayerRegistry`. La IA intenta Remover sólo si tiene ese hechizo y recursos. Las clases no mágicas permanecen inmovilizadas hasta que expira/remueven el estado.
- Las pociones son ilimitadas en esta práctica, para humanos y bot. Comparten el intervalo normal entre colores; respetan el bloqueo desde golpe. La meditación usa el runtime y calentamiento existentes; tomar pociones no la interrumpe.
- No lee el maná del rival ni mueve/daña desde el cliente. La red oculta maná y costes del bot igual que los de otro jugador; la consola muestra sólo combate que compete al humano.

El ID negativo del bot es una **entidad**, no un peer de red. Las notificaciones RPC se envían únicamente a conexiones reales. Reiniciar manda un snapshot para recolocar ambos avatares sin recorrer la trayectoria anterior y aplica también el estado vivo del controlador de lanzamiento.

## Límites y siguiente trabajo

Es una IA básica de prueba; no replica la habilidad, anticipación ni macros de un jugador experto. No incorpora especialidades aún pendientes, talentos, backstab, dificultades, marcadores competitivos ni matchmaking. No cambia el balance, tiempos de acciones ni velocidad del jugador.

Todavía hay una arena compartida por dedicado. El siguiente sistema es el lobby de invitados con aislamiento de salas, elección/listo, cuenta regresiva, rondas y revancha; incorporará el bot como rival opcional de una sala. No se promete aislamiento de lobbies en esta versión.

## Validación

`practice_bot_smoke.gd`: propiedad, nonces, clases descartadas, límite de reinicios, los nueve presets, recursos/casillas, root/remover, pociones durante meditación, equipo requerido, victoria/derrota, desconexión y relevo entre humanos.

`practice_bot_client.gd`: cliente gráfico con PCK exportado, botones/clases, movimiento/hechizos reales, muerte/reinicio, Lanzar contra bot móvil, privacidad, quitar, reconectar sin huérfanos y entrada de otro humano. Un segundo cliente verifica el rechazo de activación con dos humanos y la creación/remoción por el nuevo dueño al quedar solo. Se conservan regresiones de combate y de UI. Capturas nativas revisadas; navegador Windows pendiente de revisión manual.
