# Cadencia de la arena

Perfil solicitado para probar combate algo más ágil y clic + Usar. Valores propios de la arena; los DAT/INI originales y las estadísticas/daño de clases se conservan.

| Acción | Antes | Actual |
| --- | ---: | ---: |
| Poción por clic | 300 ms | 280 ms |
| Poción por Usar / Espacio / Q/E | 300 ms | 280 ms |
| Alternar clic + Usar | Un único intervalo | Mínimo común 200 ms |
| Hechizo → hechizo | 1000 ms | 950 ms |
| Golpe/arco → golpe/arco | 600 ms | 550 ms |
| Golpe → hechizo | 650 ms | 600 ms |
| Hechizo → golpe | 650 ms | 600 ms |
| Golpe → poción, por cualquier vía | 650 ms | 600 ms |

Clic y Usar tienen tiempos propios, compartidos entre roja/azul. El mínimo común de 200 ms se aplica además de ambos tiempos: dos acciones simultáneas no producen dos pociones instantáneas. Q/E comparte la vía de Usar. Cambiar de color, alternar teclas, repetir solicitudes o inventar otra vía no añade capacidad. El límite teórico es 3,57 pociones/s por una sola vía y 5/s al alternar: hasta un 40% más, sujeto a recursos, bloqueo tras golpe, conexión y ejecución.

El cliente conserva brevemente un clic o toque de Usar mientras espera el intervalo y coordina la repetición al mantener Espacio. El servidor decide cuándo se acepta y cuánto restaura. Un rechazo temprano no gasta ni duplica recursos. Los límites se aplican a todos los colores y vías; el cliente no envía timestamps de validación. Abrir un modal, morir, desconectar o perder foco cancela repetición y entradas pendientes. Escribir Espacio en un campo de texto no bebe.

La provisión sigue siendo ilimitada en esta arena. Seleccionar una poción llena no la bebe ni cambia el recurso de otro color. La selección sigue al objeto si se arrastra; el flujo se describe en [RECOVERY.md](RECOVERY.md).

No se agregan bloqueos de poción → golpe ni poción ↔ hechizo. Se conservan costes, cantidad recuperada, recargas individuales y de grupo, estados y meditación. El movimiento del jugador sigue a 120 ms. Los intervalos viven en CombatRules, SpellCatalog y RecoveryRules; PlayerRegistry valida las dos vías, el mínimo común y los nonces. Servidor/cliente requieren protocolo **9**.

## Bot

El bot conserva movimiento continuo por trayectos variados, con pasos de **150 ms**. Magia cada **1150–1250 ms**, golpe/arco cada **650–750 ms** y pociones cada **350–390 ms**, siempre sujetos a los límites reales del servidor. No usa la combinación clic + Usar. Se conservan percepción, errores ocasionales, reacción de Remover, prioridad de recursos y defensa, sin volver a congelarlo al lanzar. Así se reduce moderadamente su presión mientras el jugador prueba las cadencias nuevas.

## Validación

`action_intervals_smoke.gd` verifica límites exactos y el milisegundo anterior, ambos cruces, colores, alias Q/E, mínimo común, no repetición y una ventana comparable donde clic + Usar admite más pociones. `potion_use_client.gd` recorre selección, Espacio sostenido, combinación, arrastre, botón Usar, macros y cancelación por menú/foco/desconexión con un cliente gráfico y dedicado reales. `hud_layout_client.gd` revisa Usar y Meditar en cuatro resoluciones. El ajuste subjetivo se evalúa jugando esta revisión.
