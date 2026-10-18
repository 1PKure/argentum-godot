# Clases, presets e inventario de la arena

El PR8 contiene nueve clases: **Mago, Clérigo, Guerrero, Asesino, Bardo, Druida, Paladín, Cazador y Bandido**. Trabajador, Pirata y Ladrón quedan fuera del catálogo seleccionable y el servidor rechaza sus IDs. El balance base fue aceptado el 17/10/2026 para esta etapa. Las especialidades avanzadas siguen pendientes.

## Probar en Windows

1. En GitHub Desktop: Fetch origin, seleccionar `work/arena-practice-bot` y Pull si corresponde.
2. Reiniciar el dedicado con `tools/Start-PrivateWebTest.cmd`. Cliente y servidor necesitan la misma revisión; protocolo 14.
3. Recargar la web privada con Ctrl+F5. El WSS local sigue precargado.
4. Abrir **Clases**, elegir un preset y **Usar este preset**. También se puede reiniciar el preset actual.

La selección es libre: no exige recursos completos, ausencia de estados o segundos sin combatir. Prepara al personaje vivo con vida/maná completos, detiene meditación, limpia sus estados, restablece equipo/inventario y recargas de prueba. Conserva la posición. No existe todavía una ronda competitiva: el futuro lobby incorporará selección, cuenta regresiva e inicio/reinicio de ronda. No se presenta este reseteo libre como una regla de un duelo final.

## Macros iniciales

| Acceso | Categoría | Preset mágico |
| --- | --- | --- |
| 1 | Control | Paralizar |
| 2 | Remover | Remover Parálisis |
| 3 | Daño | Descarga Eléctrica; Misil Mágico para híbridos que no la tienen |
| 4 | Curación | Curar Heridas Críticas |
| 5 | Daño fuerte | Apocalipsis, cuando está permitido |
| 6 | Control alternativo | Inmovilizar |
| 7 | Limpieza | Curar Veneno |
| 8 | Recuperación | Restauración o Restauración menor |
| 9 | Curación menor | Curar Heridas Leves |
| 0 | Libre | Sin asignación inicial |

Una categoría no disponible queda vacía. Guerrero y Cazador tienen ataque físico en 3; el resto de accesos no simula magia. Los macros siguen siendo personalizables y se guardan por clase y dispositivo. La versión 2 del esquema inicializa este orden al actualizar desde los presets anteriores; las personalizaciones realizadas después se conservan.

## Arco y equipo

**Cazador: CTRL o 3 → cursor → clic sobre un rival.** Preparar o cancelar no dispara ni consume recursos. Esc/clic derecho cancela; WASD permite moverse apuntando. El servidor comprueba rival vivo, arco y flechas equipados, alcance de ocho casillas en cualquier dirección, obstáculos y el intervalo propio de flechas de 1200 ms (AO20 `IntervaloFlechasCazadores`), separado del golpe de 550 ms. Un cliente no puede reutilizar el golpe frontal para disparar sin objetivo. Cada confirmación crea una flecha visual usando el recurso original de munición y reproduce `assets/argentum/custom/audio/arrow_hit.wav` al llegar al objetivo; un disparo rechazado no genera audio de impacto. Las flechas son ilimitadas durante estas pruebas. Guerrero y las otras clases conservan el golpe frontal con CTRL.

El inventario de 42 casilleros contiene provisión roja, azul sólo para clases con maná y todos los objetos del preset: armadura, arma, casco, escudo, accesorio y munición cuando correspondan.

- Arrastrar con el botón derecho mueve o intercambia objetos. El arrastre izquierdo no reorganiza el inventario; queda reservado a usar/equipar. Mover una pieza equipada no la desequipa, no consume pociones ni duplica objetos.
- Clic en una pieza equipa/desequipa. La marca **E** indica su estado. Las piezas permanecen en la grilla cuando están equipadas, como referencias al mismo objeto. El resumen permanente de clase/equipo dentro del inventario se retiró; los nombres siguen en tooltips y en Clases.
- El avatar y el daño/defensa/resistencia/bonificación mágica usan únicamente el equipo confirmado. Sin arco o flechas equipados no se puede disparar.
- Clic en pociones o Q/E conserva su uso anterior. M conserva meditación para las clases mágicas.
- El servidor valida propietario implícito de la conexión, casilleros, ID de objeto, revisión de inventario y nonce. Un arrastre iniciado antes de cambiar de preset no puede traer el equipo anterior ni duplicarlo.

Inventario, equipamiento y posición de objetos duran esta sesión del dedicado. Cambiar/reiniciar preset reconstruye sus objetos. No hay comercio, drops, creación de objetos ni persistencia de propiedad entre conexiones.

## Renderizado

Los PNG originales están importados sin reducción de tamaño y sin compresión con pérdida; las texturas de juego usan filtro nearest. Se retiró el filtrado lineal heredado de la interfaz. El control **Zoom 1× / 2×** ajusta el zoom del mundo para que cada píxel fuente ocupe un número entero de píxeles de pantalla, incluso cuando el HUD o la ventana tienen escala fraccionaria. La cámara y el apuntado convierten las coordenadas usando ese zoom; no cambian los tiempos de movimiento ni las distancias del servidor.

La vista inicial es **1×**, con personajes y casillas a tamaño fuente y el doble de campo visible por eje respecto del 2× anterior. El acercamiento 2× sigue siendo opcional. La escala entera evita parte del suavizado y el tamaño desigual de píxeles de la escala anterior de 1.5×. No convierte el arte original en HD ni agrega detalle que no existe. La revisión visual se realizó con Godot nativo; queda comprobar el resultado en el navegador/Windows y su escala de pantalla.

## Fuentes y fórmulas de prueba

Recursos AO20: [ao-org/Recursos](https://github.com/ao-org/Recursos/tree/89615f34162d9fa0bf0fae4242cd6639edbf772f), revisión `89615f34162d9fa0bf0fae4242cd6639edbf772f`. Referencia de clases: [Declares.bas](https://github.com/ao-org/argentum-online-server/blob/9d381f280c10b680cf1f84be5372f8c1dce42840/Codigo/Declares.bas). `class_sources.json` conserva la procedencia y hashes del paquete importado; incluye también recursos históricos de clases retiradas, sin volver a habilitarlas.

`arena_equipment.ini` conserva las 32 secciones de objetos importadas y sus exclusiones CP. `armas.dat`, `escudos.dat` y `cascos.ini` permiten dibujar cuatro direcciones. Para la Espada Zafiro (icono GRH86206 ausente) y la Rodela (GRH9633 que apunta a un gráfico incorrecto en la tabla pública), se usa un fotograma de la propia arma/escudo. No se alteran los PNG originales ni los valores de los objetos. Se mantienen las atribuciones y licencias AO20 del proyecto.

La vida, el maná y el daño por nivel se basan en [UserMod.GetMaxHp / GetMaxMana / GetHitModifier](https://github.com/ao-org/argentum-online-server/blob/9d381f280c10b680cf1f84be5372f8c1dce42840/Codigo/Modulo_UsUaRiOs.bas); el daño de arma en [SistemaCombate.GetUserDamageWithItem / UserDamageToUser](https://github.com/ao-org/argentum-online-server/blob/9d381f280c10b680cf1f84be5372f8c1dce42840/Codigo/SistemaCombate.bas). Se fija la revisión de AO20 anterior; no se atribuyen fórmulas al servidor privado de United.

Referencia de los nueve presets: **humano, nivel 50, constitución 20, inteligencia 18**. La **fuerza preparada 28 es un ajuste explícito de la arena**, no la fuerza racial base de AO20 ni una poción implementada. Se aplica igual a todas las clases. No hay progresión, elección de raza ni variación aleatoria de vida al subir nivel: se usa la vida promedio y redondeo de Godot.

| Clase | Vida | Maná |
| --- | ---: | ---: |
| Mago | 363 | 2487 |
| Clérigo | 412 | 1809 |
| Guerrero | 510 | 0 |
| Asesino | 437 | 927 |
| Bardo | 412 | 1809 |
| Druida | 412 | 1809 |
| Paladín | 486 | 927 |
| Cazador | 486 | 0 |
| Bandido | 437 | 698 |

- Vida promedio = `(MODVIDA − (21 − constitución) × 0.5) × (nivel − 1) + constitución`.
- Maná = `inteligencia × MANA_INICIAL + MULT_MANA × inteligencia × (nivel − 1)`.
- Golpe por nivel = `35 × GOLPE_PRE_36 + (nivel − 36) × GOLPE_POST_36`, más el intervalo original 1–2.
- Daño de arma = `(3 × daño del arma y munición + máximo del arma y munición × 0.2 × max(0, fuerza − 15) + golpe por nivel) × modificador de clase`. Sin arma y con nudillos se usa `MODDANOWRESTLING`; Cazador con arco usa `MODDANOPROYECTILES`.
- Defensa corporal = defensa media de **armadura + escudo**, restada en puntos; el casco no se suma al torso. La arena usa torso y defensa media, sin sorteo de zona/absorción por impacto todavía. Se sortea uniformemente el daño final entre los extremos calculados, con mínimo 1. Es una simplificación de las tiradas independientes de AO20.
- Cazador con Arco de Cazador y Flecha Élfica contra Mago con Túnica Legendaria: **181–200** por disparo normal; contra el mismo Mago sin túnica: **211–230**. Estos rangos corresponden a ese equipo y fuerza. No se aplica un multiplicador oculto contra Mago.
- Magia directa sigue [modHechizos.HechizoPropUsuario](https://github.com/ao-org/argentum-online-server/blob/9d381f280c10b680cf1f84be5372f8c1dce42840/Codigo/modHechizos.bas): tirada original × `(1 + 0.03 × nivel)` × `(1 + bonificación de equipo / 100)` × `(1 − resistencia / 100)`. Se respeta AntiRm. Después de la fórmula se aplica un ajuste explícito de arena de **−8% a Apocalipsis (53) y Descarga Eléctrica (51)**. Mago contra Mago equipado: Apocalipsis **205–219** (antes 223–238), Descarga **156–169** (antes 170–184). Conservan sus costes de 1000 y 460 maná. El ajuste está en SpellCatalog y no modifica los DAT importados ni los demás hechizos.
- Resistencia del preset: skill 100, protección por skill habilitada (100 × 0.04 = 4%), modificador de clase y equipo según `UserMod.GetUserMR`; tope de arena 60%. Redondeo final y mínimo 1 son decisiones de esta implementación; no se simulan talentos, facciones, cartas, penetración ni modificadores que estos presets no tienen.
- Las curaciones conservan sus valores del DAT sin bonificación de daño por nivel. Los efectos periódicos usan su propio TickPower, ajustan equipo/resistencia al aplicarse y no reciben el bono de impacto directo. Los costes se conservan.

## Consola y datos de combate

La consola muestra hechizos lanzados por vos o dirigidos a vos, golpes en los que participás, muerte propia y recuperación propia. No registra curaciones, pociones, cambio de preset o gasto de maná de terceros. El resultado confirmado del hechizo/golpe reemplaza los mensajes repetidos por cada cambio de barra. Los controles están en Menú y tooltips; no ocupan permanentemente el HUD.

El servidor omite **current_mana** del rival en snapshots, movimiento y estadísticas, y omite **mana_cost** de los eventos enviados a otros jugadores. El rival no dibuja barra de maná. Las confirmaciones de recuperación se envían sólo al dueño; la meditación visible sigue sincronizada mediante estado público. Vida, clase y equipo visible siguen siendo públicos para las pruebas. Se requiere protocolo **14** y reinicio del dedicado.

El Mago permite explorar las 38 magias concedibles; otros presets restringen sus listas y costes al maná de la clase. La entrada 247 Disparo de NPC no se concede como magia: el arco tiene su propia acción física.

La identidad de clases se trabaja después: **Asesino con apuñalada por la espalda**, seguida de especialidades a definir y validar para las otras clases. Todavía no hay apuñalada, invisibilidad, mascotas, profesiones ni tiradas específicas de evasión/bloqueo. Esta tanda prepara controles, equipo y datos para esas mecánicas; no simula sus resultados.

## Validación

`arena_balance_privacy_smoke.gd`: recursos de las nueve clases, daño con/sin túnica, serialización por destinatario y consola local. `class_presets_smoke.gd`: nueve perfiles, gráficos, macros, serialización, cambio libre desde estados agotados/muertos, arco dirigido, paredes, alcance, cooldown, deduplicación, inventario, equipo y daño real. `preset_interactions_client.gd`: eventos reales de UI en dos clientes para cursor/cancelación/clic del arco, arrastre, equipar/desequipar, cambio libre, sincronización remota y escalas 1×/2× tras redimensionar. Las pruebas anteriores de combate, recuperación, movimiento, cámara y WSS se mantienen como regresión.

## Limpieza final del HUD

El menú se abre como modal centrado, por encima del HUD tanto al dibujar como al recibir clics. Controles, créditos y acciones se distribuyen con contenedores; Volver, Esc o clic en el fondo lo cierran. Mientras está abierto cancela el apuntado, bloquea atajos de combate/recuperación y pausa el envío de movimiento. Al cerrar se recuperan los controles; Desconectarse cierra el modal y limpia la sesión. El panel de clases comparte el bloqueo de entrada.

El nombre ocupa su propia línea; clase y ubicación van debajo. Los estados están en una fila reservada junto a los recursos; Fantasma aparece una vez y Reaparecer sólo aparece al morir. Los avisos largos de hechizos tienen dos líneas y tooltip completo, separados de Lanzar. El contenido de inventario/hechizos queda recortado a su panel.

`hud_layout_client.gd` comprueba clics y teclas contra un dedicado real con PCK exportado, estado de fantasma, bloqueo de clics detrás del menú y layout a 1280×800, 1280×720, 1920×1080 y 800×600. Se revisan capturas nativas; la comprobación en navegador Windows corresponde a la revisión del usuario. Esta limpieza conserva el balance y el zoom aceptados.
