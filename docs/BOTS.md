# Bot de práctica PvP

Primera IA de práctica, ejecutada por el dedicado. Usa los nueve presets y el balance aceptado; no añade PvE, cuentas, servicios externos ni aprendizaje automático. La conexión dorada/blanca integrada en Alpha por PR9 se conserva.

## Probar

1. GitHub Desktop: Fetch origin, elegir `work/arena-practice-bot` y Pull origin.
2. Cerrar el dedicado anterior y abrir `tools/Start-PrivateWebTest.cmd`. Cliente y servidor requieren la misma revisión: protocolo **18**.
3. Recargar la web privada con Ctrl+F5; WSS sigue precargado.
4. Con un único jugador humano conectado: **Bot**, elegir clase y **Activar bot**.
5. Esperar **3 → 2 → 1 → ¡YA!**, con tonos y tween visual. Durante esos tres segundos el servidor bloquea movimiento, ataques, magia y recuperación para ambos personajes. Luego jugar con Lanzar/macros, CTRL, pociones y meditación habituales. El rival se mueve, ataca y se recupera con las mismas funciones autoritativas.
6. **Bot → Reiniciar práctica** prepara ambos personajes con sus presets, recursos/estados limpios y posiciones iniciales. También permite cambiar la clase del bot. Reconstruye inventario/equipo del preset; los macros personalizados de cada clase se conservan.
7. **Quitar bot** lo retira. Si cualquiera muere, la IA se detiene y la consola comunica el resultado; reiniciar es explícito. Reaparecer o cambiar tu clase sigue siendo libre y prepara de nuevo ambos presets, con otra cuenta de tres segundos. Una ronda interrumpida no da recompensas; cada clase recupera su propia skin equipada.

El menú Bot bloquea entradas locales mientras está abierto, igual que Clases. El servidor y el rival siguen funcionando: no es una pausa global del combate online.

## Convivencia con jugadores

Hay como máximo un bot en esta arena de práctica. Se permite sólo con un humano, ligado a su conexión. La entrada de un segundo humano lo elimina **antes** de construir su snapshot; ambos quedan en la arena PvP existente. No se reactiva automáticamente cuando alguien sale. Una vez solo, el jugador restante puede activarlo.

Desconectar al dueño elimina el bot, sus efectos, recargas y propiedad. Una reconexión empieza sin bot. El emisor real del RPC determina al dueño; no se aceptan IDs de dueño elegidos por el cliente. Solicitudes con nonce repetido, clase descartada o varios humanos no crean entidades ni restablecen personajes. Los reinicios tienen un límite de frecuencia de 400 ms; quitarlo no espera ese intervalo.

## Comportamiento y reglas

- Movimiento continuo: pasos semimágicos de140ms y de124ms para las demás clases; la interpolación visual usa la misma velocidad. Magia cada 1150–1250 ms, golpe cada 1200–1300 ms, arco cada 1200–1300 ms y pociones cada250ms alternando clic/Usar con los límites reales de ambas vías; además conserva todos los límites autoritativos. Es una reducción moderada de presión, sin las pausas largas por casilla, congelación al apuntar ni recuperación excesivamente lenta de la versión de entrenamiento.
- Reacción inicial de 600–850 ms después de ¡YA!. La posición pública del rival se observa cada 90–150 ms; ataca usando esa observación, sin guardar una casilla otros 350–600 ms ni congelarse al apuntar. Un 6% de oportunidades puede desviarse una casilla; un clic fallado consume también la oportunidad ofensiva, para impedir reintentos gratis a gran velocidad.
- Mago, Clérigo y Bardo priorizan Apocalipsis → Descarga; sólo después de impactos confirmados sobre un rival que sigue vivo pasan a una magia de seguimiento barata. El Mago usa Tormenta de Fuego; Clérigo/Bardo usan Misil porque sus presets no conceden Tormenta. Druida usa Rayo Elemental y Misil. No se concede ningún hechizo ajeno al preset y se conserva el coste real. Un fallo no avanza la secuencia; seis segundos de interrupción la reinician. La fuente AO20 no contiene una entrada llamada Fuego Mágico: se usan los nombres originales y magias disponibles. Paralizar tiene una primera oportunidad a los 10–14 segundos y luego oportunidades espaciadas 14–18 segundos y no se repite sobre un rival que ya tiene una raíz visible. Guerrero, Paladín, Asesino y Bandido se acercan para golpear; los híbridos usan Remover/Curación permitidos. Cazador usa arco y munición reales con línea de tiro.
- El desplazamiento se decide en trayectos de 2–4 casillas durante 450–800 ms. Pondera ambos ejes, penaliza regresar inmediatamente y las casillas recientes, y corta la repetición del mismo eje después de cuatro pasos cuando hay una alternativa legal; puede necesitar más al reposicionarse por rango/obstáculos. Alterna desplazamientos laterales hacia ambos lados, acercarse o alejarse; hay pausas breves ocasionales de 150–260 ms. La búsqueda de caminos varía entre prácticas. Caminar, lanzar y beber funcionan de forma independiente: lanzar ya no detiene cada trayecto ni obliga a subir después.
- Bajo 55% de vida o, en lanzadores, 18% de maná, adopta una postura defensiva: intenta abrir distancia y recuperar recursos. Vuelve a presionar al alcanzar 75% de vida y 35% de maná. Los cuerpos a cuerpo dejan una ventana real para beber después de golpear; no se bloquean a sí mismos atacando justo antes de cada poción. La Curación permitida es una decisión ocasional, consume maná y ocupa su intervalo de magia.
- Al detectar una raíz espera 520–700 ms para intentar Remover. Remover, Curación y daño comparten el mismo intervalo propio del bot de 1150–1250 ms, además del límite del servidor; no se remueve al instante ni obtiene maná gratis. Cada raíz nueva exige otra reacción. Una clase sin Remover conserva las restricciones normales.
- Considera roja cuando faltan al menos 27 HP y azul bajo 65% de maná; reacciona en100–150ms a una necesidad nueva y repite cada250ms. Prioriza rojas consecutivas bajo55% de vida en Mago/Druida y65% en semimágicas; por encima alterna colores si necesita ambos. Los rechazos por golpe→poción mantienen la decisión pendiente sin reiniciar una espera larga. Todas las pociones se validan en PlayerRegistry y la provisión de arena sigue siendo ilimitada para ambos.
- Con poco maná y distancia puede meditar, tomar pociones durante la meditación y volver al combate con recursos. Mantiene calentamiento y ticks existentes. Los tiempos se observan en los frames del dedicado; no acumula turnos atrasados.
- No lee el maná ni la vida rival para elegir un remate perfecto. La red oculta maná y costes del bot igual que los de otro jugador; la consola sólo informa combate que compete al humano. Las semillas fijas son una herramienta de pruebas; producción inicializa su propia aleatoriedad.

El ID negativo del bot es una **entidad**, no un peer de red. Las notificaciones RPC se envían únicamente a conexiones reales. Reiniciar manda un snapshot para recolocar ambos avatares sin recorrer la trayectoria anterior y aplica también el estado vivo del controlador de lanzamiento.

## Límites y siguiente trabajo

Es una IA básica de prueba; no replica la habilidad, anticipación ni macros de un jugador experto. No incorpora especialidades aún pendientes, talentos, backstab, dificultades, marcadores competitivos ni matchmaking. Las estadísticas y velocidad del jugador conservan el balance aceptado. Apocalipsis y Descarga bajan 8% para ambos actores y el arco usa un intervalo propio de 1200 ms. Los intervalos del jugador se reducen ligeramente por pedido explícito: 280 ms por vía de poción, 200 ms mínimo combinado clic/Usar, 950 ms hechizos, 1200 ms golpes y 600 ms cruces; ver [ACTION_INTERVALS.md](ACTION_INTERVALS.md).

Todavía hay una arena compartida por dedicado. El siguiente sistema es el lobby de invitados con aislamiento de salas, elección/listo, cuenta regresiva, rondas y revancha; incorporará el bot como rival opcional de una sala. No se promete aislamiento de lobbies en esta versión.

## Validación

`practice_bot_smoke.gd`: 72 comprobaciones; movimiento continuo, lanzar mientras camina, presión sobre rival quieto y otro que se mueve y se remueve legalmente, cadencia compartida de daño/Remover, rojas prioritarias después de combos, ambos colores de poción, recuperación cuerpo a cuerpo y enfrentamientos con daño real, además de propiedad, nonces, clases descartadas, límite de reinicios, los nueve presets, recursos/casillas, root/remover, pociones durante meditación, equipo requerido, victoria/derrota, desconexión y relevo entre humanos.

`practice_bot_client.gd`: 25 comprobaciones con dos clientes y PCK exportado: botones/clases, igualdad de velocidades lógica/visual y movimiento continuo replicado mientras el humano camina/bebe, movimiento/hechizos reales, muerte/reinicio, Lanzar contra bot móvil, privacidad, quitar, reconectar sin huérfanos y entrada de otro humano. Un segundo cliente verifica el rechazo de activación con dos humanos y la creación/remoción por el nuevo dueño al quedar solo. Se conservan regresiones de combate y de UI. Capturas nativas revisadas; navegador Windows pendiente de revisión manual.

La regresión gráfica `arena_network_client.gd` recorre los diez macros 1–0 con inventario abierto, bebe por clic y teclado sin perder el cursor y lanza sobre el rival desde ese mismo estado. Los flujos manuales de libro/Lanzar se conservan.

En ocho semillas y 24 segundos por escenario, la simulación informa aciertos contra rival quieto/móvil, oportunidades, pasos consecutivos y lanzamiento junto con movimiento. Cuatro intercambios adicionales usan flechas y pociones reales del jugador: verifican respuesta y recuperación del bot y que puede ser derrotado. Son escenarios reproducibles, no una medición de dificultad para todas las personas ni una tasa de victoria competitiva.

El bot utiliza una sola vía de poción y no obtiene el bono de clic + Usar del jugador. El ritmo del bot es independiente del ajuste general para poder calibrarlo sin volver lento al personaje humano.

La regresión de combos prueba los primeros impactos confirmados en ocho semillas contra un rival superviviente y las alternativas legales de Clérigo/Bardo/Druida. La variación de rutas mide ambos ejes, trayectorias distintas y la ruptura de subidas/bajadas prolongadas. Son comprobaciones de comportamiento, no una garantía de dificultad subjetiva.

## Skins y recompensas

Las victorias confirmadas por el dedicado suman **1 victoria por ronda**. Un ID aleatorio de ronda evita contar dos veces estados terminales repetidos. Perder, quitar el bot, cambiar de preset, desconectar o la entrada de otro humano no premian una ronda sin terminar.

**Skins**, en la cabecera, muestra el atuendo del preset y recompensas a **1, 3 y 5 victorias de la clase actual**. Cada clase guarda su contador y atuendo equipado; ganar con Mago no desbloquea Cazador. Cambiar de clase recupera su propia selección y una clase nueva empieza con el preset y las tres recompensas bloqueadas. El servidor reinicia la apariencia al cambiar de clase y sólo acepta solicitudes cosméticas dirigidas a la clase actual; una solicitud antigua no se aplica a la clase nueva.

Las **27 recompensas usan cuerpos y píxeles de animación distintos entre sí**, además de diferir del preset de su clase. Mago usa variantes del corte de la Legendaria; Druida conserva temática natural, y cada colección de armaduras/atuendos tiene opciones propias. Son apariencias AO20 de las familias visuales de referencia en `112.png`; no se conceden los objetos originales ni se cambian equipo, restricciones, HP/maná, defensas, daño, intervalos o balance.

Después de completar las tres skins, **la siguiente victoria** abre una invitación a probar una clase con la colección pendiente. **Probar otra clase** abre el selector con esa sugerencia; cambiar exige aplicar el preset. Se puede volver o seguir con la clase actual. Al completar las nueve colecciones se muestra la felicitación correspondiente, sin sugerir una clase ya completa.

El guardado local mantiene `user://arena_skins_v1.cfg` y usa formato interno **v2**, con secciones por clase y una lista común de rondas cobradas. El formato global anterior no registraba la clase ganadora: se migra **una sola vez al Mago**, conservando victorias, selección e IDs cobrados; las demás clases comienzan su progreso independiente. Una victoria recibida con retraso se acredita a la clase ganadora confirmada por el dedicado, sin cambiar la clase activa. No se premian rondas sin terminar ni se duplica una ronda al cambiar de clase.

El progreso corresponde al mismo navegador/dispositivo/origen; borrar sus datos lo elimina. No se comparte entre dispositivos ni es un inventario protegido contra manipulación: sigue siendo persistencia local gratuita. No hay DB, cuentas ni servicio pago. Un fallo de guardado se avisa en Skins. Catálogo y procedencia: `arena_skins.json` y `skin_sources.json`.

La flecha usa el archivo adjunto **Arrow hit 2.wav**, copiado sin conversión a `assets/argentum/custom/audio/arrow_hit.wav`, a los 180 ms del impacto visual confirmado. Conserva el volumen existente y sólo suena al acertar. Procedencia y hash en `assets/argentum/custom/audio/sources.json`.

`arena_rewards_smoke.gd` cubre frontera de inicio 2999/3000 ms, intentos tempranos, resultados únicos, guardado/recarga, hitos, selección cosmética y limpieza. `arena_rewards_client.gd` recorre activación, cuenta y bloqueo por RPC real, victoria mediante hechizos, desbloqueo/equipado, reconexión y réplica a un segundo cliente desde el PCK exportado.


### Recompensas por clase

| Clase | 1 victoria | 3 victorias | 5 victorias |
| --- | --- | --- | --- |
| Mago | Legendaria gris | Roja especial | Azul |
| Clérigo | Iluminación | De la Luz | Clérigo imperial |
| Guerrero | Legendaria | Placas completas | Dragón rojo |
| Asesino | Escarlata | De las Sombras | Asesino imperial |
| Bardo | Aventurera | Theramore | Bardo imperial |
| Druida | Verde | Druida superior | Enraigada |
| Paladín | Dorada | Bruñida | Dragón dorado |
| Cazador | Cuero azul | Dragón verde | Cazador imperial |
| Bandido | Combinada | Del Desfalco | Bandido imperial |

La flecha confirmada con daño añade doce gotas de sangre y una salpicadura inicial durante **500 ms**, al mismo instante visual que su sonido (180 ms de recorrido). Siguen al objetivo interpolado, incluso en el impacto letal, y se eliminan al terminar/desconectar; no generan daño, sonido adicional ni manchas permanentes. Preparar, cancelar o rechazar un disparo no crea sangre.

`class_skin_smoke.gd`: valida los 27 atuendos, restricciones del catálogo, cuerpos y píxeles distintos por clase, estadísticas intactas y migración única del guardado global anterior al Mago. `class_progress_smoke.gd`: valida contadores/selecciones por clase, hitos, sexto triunfo, deduplicación, resultados retrasados y guardado/migración. `class_skin_client.gd`: recorre las nueve colecciones con el PCK, comprueba que empiezan bloqueadas, equipa sus premios y verifica réplica a otro cliente. `arena_rewards_client.gd`: gana duelos reales, muestra la invitación y abre/aplica la clase sugerida, sin compartir sus desbloqueos. La prueba de efectos cubre comienzo, seguimiento y fin de la sangre sin repetir audio. Las rondas aprobadas se conservan.

La revisión visual del impacto compara capturas idénticas con/sin sangre a escala real **1x** sobre túnicas oscuras y una armadura roja: exige contraste y una extensión mínima en píxeles, además del seguimiento del objetivo. Se conserva el sonido aprobado.

Última revisión y análisis de cierre: [detalles](FINAL_COMBAT_DETAILS.md#cierre-de-gameplay-alpha-presión-y-recuperación) · [siguiente etapa web](ALPHA_READINESS.md).
