# Bot de práctica PvP

Primera IA de práctica, ejecutada por el dedicado. Usa los nueve presets y el balance aceptado; no añade PvE, cuentas, servicios externos ni aprendizaje automático. La conexión dorada/blanca integrada en Alpha por PR9 se conserva.

## Probar

1. GitHub Desktop: Fetch origin, elegir `work/arena-practice-bot` y Pull origin.
2. Cerrar el dedicado anterior y abrir `tools/Start-PrivateWebTest.cmd`. Cliente y servidor requieren la misma revisión: protocolo **9**.
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

- Movimiento continuo con pasos de 150 ms, algo más lento que los 120 ms del jugador. Magia cada 1150–1250 ms, golpe/arco cada 650–750 ms y pociones cada 350–390 ms; además conserva todos los límites autoritativos. Es una reducción moderada de presión, sin las pausas largas por casilla, congelación al apuntar ni recuperación excesivamente lenta de la versión de entrenamiento.
- Reacción inicial de 600–850 ms. La posición pública del rival se observa cada 90–150 ms; ataca usando esa observación, sin guardar una casilla otros 350–600 ms ni congelarse al apuntar. Un 6% de oportunidades puede desviarse una casilla; un clic fallado consume también la oportunidad ofensiva, para impedir reintentos gratis a gran velocidad.
- Mago, Clérigo, Bardo y Druida mantienen distancia y alternan daño principal, Misil y Apocalipsis ocasional. Paralizar tiene oportunidades espaciadas 8–12 segundos y no se repite sobre un rival que ya tiene una raíz visible. Guerrero, Paladín, Asesino y Bandido se acercan para golpear; los híbridos usan Remover/Curación permitidos. Cazador usa arco y munición reales con línea de tiro.
- El desplazamiento se decide en trayectos de 2–4 casillas durante 480–850 ms. Alterna desplazamientos laterales hacia ambos lados, acercarse o alejarse; hay pausas breves ocasionales de 150–260 ms. La búsqueda de caminos varía entre prácticas. Caminar, lanzar y beber funcionan de forma independiente: lanzar ya no detiene cada trayecto ni obliga a subir después.
- Bajo 45% de vida o, en lanzadores, 18% de maná, adopta una postura defensiva: intenta abrir distancia y recuperar recursos. Vuelve a presionar al alcanzar 65% de vida y 35% de maná. Los cuerpos a cuerpo dejan una ventana real para beber después de golpear; no se bloquean a sí mismos atacando justo antes de cada poción. La Curación permitida es una decisión ocasional, consume maná y ocupa su intervalo de magia.
- Al detectar una raíz espera 350–550 ms para intentar Remover. Respeta además el intervalo del último hechizo; no se remueve al instante ni obtiene maná gratis. Cada raíz nueva exige otra reacción. Una clase sin Remover conserva las restricciones normales.
- Considera roja bajo 78% de vida y azul bajo 65% de maná; reacciona en 160–260 ms a una necesidad nueva y repite cada 350–390 ms. Prioriza vida crítica, luego maná crítico; alterna colores si necesita ambos. Los rechazos por golpe→poción mantienen la decisión pendiente sin reiniciar una espera larga. Todas las pociones se validan en PlayerRegistry y la provisión de arena sigue siendo ilimitada para ambos.
- Con poco maná y distancia puede meditar, tomar pociones durante la meditación y volver al combate con recursos. Mantiene calentamiento y ticks existentes. Los tiempos se observan en los frames del dedicado; no acumula turnos atrasados.
- No lee el maná ni la vida rival para elegir un remate perfecto. La red oculta maná y costes del bot igual que los de otro jugador; la consola sólo informa combate que compete al humano. Las semillas fijas son una herramienta de pruebas; producción inicializa su propia aleatoriedad.

El ID negativo del bot es una **entidad**, no un peer de red. Las notificaciones RPC se envían únicamente a conexiones reales. Reiniciar manda un snapshot para recolocar ambos avatares sin recorrer la trayectoria anterior y aplica también el estado vivo del controlador de lanzamiento.

## Límites y siguiente trabajo

Es una IA básica de prueba; no replica la habilidad, anticipación ni macros de un jugador experto. No incorpora especialidades aún pendientes, talentos, backstab, dificultades, marcadores competitivos ni matchmaking. Las estadísticas, daño y velocidad del jugador conservan el balance aceptado. Los intervalos del jugador se reducen ligeramente por pedido explícito: 280 ms por vía de poción, 200 ms mínimo combinado clic/Usar, 950 ms hechizos, 550 ms golpes y 600 ms cruces; ver [ACTION_INTERVALS.md](ACTION_INTERVALS.md).

Todavía hay una arena compartida por dedicado. El siguiente sistema es el lobby de invitados con aislamiento de salas, elección/listo, cuenta regresiva, rondas y revancha; incorporará el bot como rival opcional de una sala. No se promete aislamiento de lobbies en esta versión.

## Validación

`practice_bot_smoke.gd`: 62 comprobaciones; movimiento continuo, lanzar mientras camina, presión sobre rival quieto y otro que se mueve y se remueve legalmente, cadencias reales, ambos colores de poción, recuperación cuerpo a cuerpo y enfrentamientos con daño real, además de propiedad, nonces, clases descartadas, límite de reinicios, los nueve presets, recursos/casillas, root/remover, pociones durante meditación, equipo requerido, victoria/derrota, desconexión y relevo entre humanos.

`practice_bot_client.gd`: 23 comprobaciones con dos clientes y PCK exportado: botones/clases, movimiento continuo replicado mientras el humano camina/bebe, movimiento/hechizos reales, muerte/reinicio, Lanzar contra bot móvil, privacidad, quitar, reconectar sin huérfanos y entrada de otro humano. Un segundo cliente verifica el rechazo de activación con dos humanos y la creación/remoción por el nuevo dueño al quedar solo. Se conservan regresiones de combate y de UI. Capturas nativas revisadas; navegador Windows pendiente de revisión manual.

La regresión gráfica `arena_network_client.gd` recorre los diez macros 1–0 con inventario abierto, bebe por clic y teclado sin perder el cursor y lanza sobre el rival desde ese mismo estado. Los flujos manuales de libro/Lanzar se conservan.

En ocho semillas y 24 segundos por escenario, la simulación informa aciertos contra rival quieto/móvil, oportunidades, pasos consecutivos y lanzamiento junto con movimiento. Cuatro intercambios adicionales usan flechas y pociones reales del jugador: verifican respuesta y recuperación del bot y que puede ser derrotado. Son escenarios reproducibles, no una medición de dificultad para todas las personas ni una tasa de victoria competitiva.

El bot utiliza una sola vía de poción y no obtiene el bono de clic + Usar del jugador. El ritmo del bot es independiente del ajuste general para poder calibrarlo sin volver lento al personaje humano.
