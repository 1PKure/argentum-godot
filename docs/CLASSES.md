# Clases, presets e inventario de la arena

El PR8 contiene nueve clases: **Mago, Clérigo, Guerrero, Asesino, Bardo, Druida, Paladín, Cazador y Bandido**. Trabajador, Pirata y Ladrón quedan fuera del catálogo seleccionable y el servidor rechaza sus IDs. Son perfiles de prueba; el balance y las especialidades avanzadas siguen pendientes.

## Probar en Windows

1. En GitHub Desktop: Fetch origin, seleccionar `work/arena-class-presets` y Pull si corresponde.
2. Reiniciar el dedicado con `tools/Start-PrivateWebTest.cmd`. Cliente y servidor necesitan la misma revisión; protocolo 4.
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

**Cazador: CTRL o 3 → cursor → clic sobre un rival.** Preparar o cancelar no dispara ni consume recursos. Esc/clic derecho cancela; WASD permite moverse apuntando. El servidor comprueba rival vivo, arco y flechas equipados, alcance de ocho casillas en cualquier dirección, obstáculos y el intervalo físico de 650 ms. Un cliente no puede reutilizar el golpe frontal para disparar sin objetivo. Cada confirmación crea una flecha visual usando el recurso original de munición. Las flechas son ilimitadas durante estas pruebas. Guerrero y las otras clases conservan el golpe frontal con CTRL.

El inventario de 42 casilleros contiene las dos provisiones y todos los objetos del preset: armadura, arma, casco, escudo, accesorio y munición cuando correspondan.

- Arrastrar mueve o intercambia objetos. Mover una pieza equipada no la desequipa, no consume pociones ni duplica objetos.
- Clic en una pieza equipa/desequipa. La marca **E** indica su estado. Las piezas permanecen en la grilla cuando están equipadas, como referencias al mismo objeto.
- El avatar y el daño/defensa/resistencia/bonificación mágica usan únicamente el equipo confirmado. Sin arco o flechas equipados no se puede disparar.
- Clic en pociones o Q/E conserva su uso anterior. M conserva meditación para las clases mágicas.
- El servidor valida propietario implícito de la conexión, casilleros, ID de objeto, revisión de inventario y nonce. Un arrastre iniciado antes de cambiar de preset no puede traer el equipo anterior ni duplicarlo.

Inventario, equipamiento y posición de objetos duran esta sesión del dedicado. Cambiar/reiniciar preset reconstruye sus objetos. No hay comercio, drops, creación de objetos ni persistencia de propiedad entre conexiones.

## Renderizado

Los PNG originales están importados sin reducción de tamaño y sin compresión con pérdida; las texturas de juego usan filtro nearest. Se retiró el filtrado lineal heredado de la interfaz. El control **Píxel 2× / 1×** ajusta el zoom del mundo para que cada píxel fuente ocupe un número entero de píxeles de pantalla, incluso cuando el HUD o la ventana tienen escala fraccionaria. La cámara y el apuntado convierten las coordenadas usando ese zoom; no cambian los tiempos de movimiento ni las distancias del servidor.

La escala entera evita parte del suavizado y el tamaño desigual de píxeles de la escala anterior de 1.5×. No convierte el arte original en HD ni agrega detalle que no existe. La revisión visual se realizó con Godot nativo; queda comprobar el resultado en el navegador/Windows y su escala de pantalla.

## Fuentes y fórmulas de prueba

Recursos AO20: [ao-org/Recursos](https://github.com/ao-org/Recursos/tree/89615f34162d9fa0bf0fae4242cd6639edbf772f), revisión `89615f34162d9fa0bf0fae4242cd6639edbf772f`. Referencia de clases: [Declares.bas](https://github.com/ao-org/argentum-online-server/blob/9d381f280c10b680cf1f84be5372f8c1dce42840/Codigo/Declares.bas). `class_sources.json` conserva la procedencia y hashes del paquete importado; incluye también recursos históricos de clases retiradas, sin volver a habilitarlas.

`arena_equipment.ini` conserva las 32 secciones de objetos importadas y sus exclusiones CP. `armas.dat`, `escudos.dat` y `cascos.ini` permiten dibujar cuatro direcciones. Para la Espada Zafiro (icono GRH86206 ausente) y la Rodela (GRH9633 que apunta a un gráfico incorrecto en la tabla pública), se usa un fotograma de la propia arma/escudo. No se alteran los PNG originales ni los valores de los objetos. Se mantienen las atribuciones y licencias AO20 del proyecto.

Las fórmulas son adaptaciones de arena, no el cálculo completo de progresión de AO20:

- Vida = redondear `500 × MODVIDA / 7.5`; maná = redondear `3000 × MULT_MANA / 2.65`.
- Golpe = redondear `(30 + 2 × daño medio del arma y munición equipadas) × modificador de daño de la clase`. Para Cazador se usa el modificador de proyectiles; para otros, armas.
- Defensa = suma de defensa media del equipo actual, interpretada como porcentaje con tope 60%. Resistencia mágica = 4% base más los valores del equipo, con tope 60%.
- Daño físico = golpe × `(1 − defensa / 100)`; daño mágico = tirada original × `(1 + bonificación / 100)` × `(1 − resistencia / 100)`. Se redondea con mínimo 1. Curaciones y costes conservan sus reglas. El daño periódico fija estos modificadores al aplicarse.

El Mago permite explorar las 38 magias concedibles; otros presets restringen sus listas y costes al maná de la clase. La entrada 247 Disparo de NPC no se concede como magia: el arco tiene su propia acción física.

La identidad de clases se trabaja después: **Asesino con apuñalada por la espalda**, seguida de especialidades a definir y validar para las otras clases. Todavía no hay apuñalada, invisibilidad, mascotas, profesiones ni tiradas específicas de evasión/bloqueo. Esta tanda prepara controles, equipo y datos para esas mecánicas; no simula sus resultados.

## Validación

`class_presets_smoke.gd`: nueve perfiles, gráficos, macros, serialización, cambio libre desde estados agotados/muertos, arco dirigido, paredes, alcance, cooldown, deduplicación, inventario, equipo y daño real. `preset_interactions_client.gd`: eventos reales de UI en dos clientes para cursor/cancelación/clic del arco, arrastre, equipar/desequipar, cambio libre, sincronización remota y escalas 1×/2× tras redimensionar. Las pruebas anteriores de combate, recuperación, movimiento, cámara y WSS se mantienen como regresión.
