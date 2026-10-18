# Cadencia de la arena

Perfil de prueba con pociones seleccionadas y combinación clic + Usar. Los ajustes de daño de arena se describen en [CLASSES.md](CLASSES.md); los DAT/INI originales se conservan.

| Acción del jugador | Intervalo actual |
| --- | ---: |
| Poción por clic | 280 ms |
| Poción por Usar / Espacio / Q/E | 280 ms |
| Alternar clic + Usar | Mínimo común 200 ms |
| Hechizo → hechizo | 950 ms |
| Golpe → golpe | 550 ms |
| Flecha → flecha | 1200 ms |
| Golpe → hechizo | 600 ms |
| Hechizo → golpe/arco | 600 ms |
| Golpe/arco → poción, por cualquier vía | 600 ms |

El arco usa **1200 ms** de `IntervaloFlechasCazadores` del INI AO20, con un límite propio en PlayerRegistry. Antes compartía los 550 ms del golpe, lo que permitía encadenar demasiado rápido sus impactos de 181–200 contra el Mago equipado. El servidor comprueba este límite para humanos y bots: repetir CTRL, macro 3, clic o nonces nuevos no aumenta la cadencia. El golpe frontal no dispara flechas. El resto de golpes mantiene 550 ms.

Clic y Usar tienen tiempos propios, compartidos entre roja/azul. El mínimo común de 200 ms se aplica además de ambos: dos acciones simultáneas no producen dos pociones instantáneas. Q/E comparte Usar. Cambiar de color, alternar teclas, repetir solicitudes o inventar otra vía no añade capacidad. El límite teórico es 3,57 pociones/s por una sola vía y 5/s al alternar, sujeto a recursos, bloqueo tras golpe, conexión y ejecución.

La provisión sigue siendo ilimitada. Las clases sin maná reciben sólo rojas; al cambiar desde una azul seleccionada se selecciona la roja. Seleccionar una poción llena no la bebe ni cambia el recurso de otro color. La selección sigue al objeto al arrastrarlo; ver [RECOVERY.md](RECOVERY.md).

No se agregan bloqueos de poción → golpe ni poción ↔ hechizo. Se conservan costes, cantidad recuperada, recargas individuales y de grupo, estados y meditación. El movimiento del jugador sigue a 120 ms. Servidor/cliente requieren protocolo **10** y la misma revisión.

## Bot

| Acción | Cadencia del bot |
| --- | ---: |
| Paso, también en la interpolación visual | 180 ms |
| Magia ofensiva, Curación y Remover | 1400–1550 ms |
| Golpe | 650–750 ms |
| Arco | 1200–1350 ms |
| Poción, una sola vía | 280–300 ms |
| Reacción inicial a una raíz | 800–1100 ms |

La reacción a una raíz se suma a las restricciones vigentes: Remover no saltea la pausa de magia del bot. Se conservan recargas, maná y validaciones del servidor. El bot no usa clic + Usar. Empieza a beber cuando faltan 27 HP, reacciona en 120–180 ms y prioriza rojas bajo 65% de vida, manteniendo movimiento y recuperación en paralelo. Ver [BOTS.md](BOTS.md).

## Validación

`action_intervals_smoke.gd` prueba fronteras exactas y spam de 2400 solicitudes nuevas de flecha, con actor humano y bot, además de las vías de poción, cruces y recargas. `class_presets_smoke.gd` comprueba provisiones por clase y arco dirigido. `practice_bot_smoke.gd` valida la espera común de daño/Remover y rojas tras un combo. `movement_smoke.gd` mide interpolación humana de 120 ms y bot de 180 ms.

`preset_interactions_client.gd` repite CTRL/macro 3 y clics durante el intervalo de arco con dos clientes y dedicado reales. `potion_use_client.gd` recorre selección, Espacio sostenido, combinación, arrastre, botón Usar, macros, cancelaciones y cambio a una clase sin maná. La dificultad subjetiva se evalúa jugando esta revisión.
