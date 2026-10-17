# Bot de práctica PvP

Primera IA de práctica, ejecutada por el dedicado. Usa los nueve presets y el balance aceptado; no añade PvE, cuentas, servicios externos ni aprendizaje automático. La conexión dorada/blanca integrada en Alpha por PR9 se conserva.

## Probar

1. GitHub Desktop: Fetch origin, elegir `work/arena-practice-bot` y Pull origin.
2. Cerrar el dedicado anterior y abrir `tools/Start-PrivateWebTest.cmd`. Cliente y servidor requieren la misma revisión: protocolo **7**.
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

- Movimiento cardinal sobre casillas transitables y ocupación real. Ciclo de 150 ms, con 900–1200 ms iniciales de reacción. Cada paso tiene una espera adicional de 220–340 ms. La búsqueda varía el orden de exploración; no acumula turnos atrasados.
- Guerrero, Paladín, Asesino y Bandido se acercan para golpe frontal; los híbridos pueden usar remover y curación permitidos. Mago, Clérigo, Bardo y Druida mantienen distancia y eligen daño disponible. Cazador busca una posición con línea de tiro y dispara con arco/munición equipados.
- En distancia de combate, elige entre quedarse quieto, desplazarse lateralmente a ambos lados, acercarse o retirarse; conserva cada decisión 800–1500 ms. Sale de alcance o pierde línea de tiro: vuelve a buscar una posición de 4–6 casillas. Al apuntar se detiene. Ya no encadena siempre acercarse, lanzar y subir.
- Decide ataques mágicos cada 1450–1900 ms y físicos cada 900–1250 ms; el golpe frontal puede perder una oportunidad. Magia/arco recuerdan la casilla del rival y esperan 350–600 ms para disparar, con un 20% de desviación de una casilla. Si el rival se movió, no reajusta el objetivo al último instante. El servidor sigue rechazando objetivos inválidos sin daño ni gasto.
- Alterna daño principal y Misil; Apocalipsis es ocasional cuando puede pagarlo, sin leer la vida rival para rematar de forma perfecta. Paralizar se intenta espaciadamente, con oportunidades separadas 10–15 segundos. Curación propia es una decisión ocasional bajo 35% de vida, no una respuesta perfecta a cada golpe.
- Root, equipo, daño, maná, pociones, meditación y recargas se resuelven en `PlayerRegistry`. La IA espera 650–1050 ms desde que detecta una raíz antes de intentar Remover, sólo si tiene ese hechizo y recursos; respeta también la recarga real. Cada raíz nueva exige otra reacción. Las clases no mágicas permanecen inmovilizadas hasta que expira/remueven el estado.
- Las pociones son ilimitadas para humanos y bot. El bot las considera bajo 55% de vida o 35% de maná, espera 400–700 ms al detectar la necesidad e intenta repetir cada 750–1050 ms, con una única espera compartida para ambos colores. Es más lento que los 300 ms del humano. Además respeta el bloqueo desde golpe y la validación normal. La meditación conserva runtime y calentamiento; beber no la interrumpe.
- Los tiempos de decisión se observan en el ciclo de 150 ms y pueden tardar hasta un ciclo adicional. La aleatoriedad se inicializa en servidor; las pruebas pueden inyectar semillas fijas para reproducir escenarios.
- No lee el maná del rival ni mueve/daña desde el cliente. La red oculta maná y costes del bot igual que los de otro jugador; la consola muestra sólo combate que compete al humano.

El ID negativo del bot es una **entidad**, no un peer de red. Las notificaciones RPC se envían únicamente a conexiones reales. Reiniciar manda un snapshot para recolocar ambos avatares sin recorrer la trayectoria anterior y aplica también el estado vivo del controlador de lanzamiento.

## Límites y siguiente trabajo

Es una IA básica de prueba; no replica la habilidad, anticipación ni macros de un jugador experto. No incorpora especialidades aún pendientes, talentos, backstab, dificultades, marcadores competitivos ni matchmaking. Las estadísticas, daño y velocidad del jugador conservan el balance aceptado. Los intervalos del jugador se reducen ligeramente por pedido explícito: 300 ms pociones, 1000 ms hechizos, 600 ms golpes y 650 ms cruces; ver [ACTION_INTERVALS.md](ACTION_INTERVALS.md).

Todavía hay una arena compartida por dedicado. El siguiente sistema es el lobby de invitados con aislamiento de salas, elección/listo, cuenta regresiva, rondas y revancha; incorporará el bot como rival opcional de una sala. No se promete aislamiento de lobbies en esta versión.

## Validación

`practice_bot_smoke.gd`: 57 comprobaciones; reacción de remover, apuntado recordado/esquivable, diversidad con ocho semillas fijas, presión de ataques y ritmo de pociones, además de propiedad, nonces, clases descartadas, límite de reinicios, los nueve presets, recursos/casillas, root/remover, pociones durante meditación, equipo requerido, victoria/derrota, desconexión y relevo entre humanos.

`practice_bot_client.gd`: cliente gráfico con PCK exportado, botones/clases, movimiento/hechizos reales, muerte/reinicio, Lanzar contra bot móvil, privacidad, quitar, reconectar sin huérfanos y entrada de otro humano. Un segundo cliente verifica el rechazo de activación con dos humanos y la creación/remoción por el nuevo dueño al quedar solo. Se conservan regresiones de combate y de UI. Capturas nativas revisadas; navegador Windows pendiente de revisión manual.

La regresión gráfica `arena_network_client.gd` recorre los diez macros 1–0 con inventario abierto, bebe por clic y teclado sin perder el cursor y lanza sobre el rival desde ese mismo estado. Los flujos manuales de libro/Lanzar se conservan.
