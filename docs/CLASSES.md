# Clases y presets de prueba

Esta tanda incorpora las 12 clases del enum público AO20: Mago, Clérigo, Guerrero, Asesino, Bardo, Druida, Paladín, Cazador, Trabajador, Pirata, Ladrón y Bandido. Son presets de arena con equipo fijo, atributos efectivos y permisos de magia; no representan la implementación completa de sus especialidades ni el balance final de AO20.

## Probar desde la interfaz

1. Actualizar servidor y clientes a la rama `work/arena-class-presets`. Reiniciar el dedicado con `tools/Start-PrivateWebTest.cmd`; el protocolo de combate ahora es 3.
2. Conectar con la URL WSS que ya viene preparada. El primer personaje entra como Mago.
3. Pulsar **Clases**, arriba a la derecha. Elegir una clase: se muestran el personaje equipado, objetos, vida/maná, golpe, alcance, defensa, resistencia y número de hechizos.
4. Pulsar **Usar este preset**. El cambio se aplica cuando responde el servidor; ambos clientes reciben el mismo ID de clase y reconstruyen su equipo. No cambia la posición.
5. Abrir Hechizos para ver el libro de la clase. Los macros se guardan por clase y dispositivo; las clases sin magia tienen diez accesos vacíos. El catálogo completo permite consultar entradas ajenas o pendientes, pero Lanzar permanece deshabilitado para ellas.

Cambiar de clase requiere estar vivo, con vida y maná completos, sin estados activos ni meditación, y 10 segundos sin combatir. Golpes, hechizos, daño recibido y efectos periódicos actualizan ese bloqueo. No se reinician los intervalos ni las recargas individuales al elegir un preset. Reaparecer conserva la clase. El selector de prueba se conectará al lobby para elegir antes de cada partida.

CTRL golpea la casilla frontal. El Cazador dispara en esa misma dirección hasta ocho casillas: impacta al primer rival vivo y los obstáculos cortan el alcance. No usa maná ni hechizos; las flechas del preset son ilimitadas, como las pociones actuales. El ataque a distancia se resuelve inmediatamente; la animación de proyectil queda para el pulido posterior.

## Datos originales y adaptación

- Recursos: [ao-org/Recursos](https://github.com/ao-org/Recursos/tree/89615f34162d9fa0bf0fae4242cd6639edbf772f), revisión `89615f34162d9fa0bf0fae4242cd6639edbf772f`.
- Enum de clases: [Declares.bas](https://github.com/ao-org/argentum-online-server/blob/9d381f280c10b680cf1f84be5372f8c1dce42840/Codigo/Declares.bas), revisión `9d381f280c10b680cf1f84be5372f8c1dce42840`.
- `Balance.dat`: modificadores originales de vida, maná y daño físico. `arena_equipment.ini`: 32 secciones completas extraídas de `Dat/obj.dat`, con nombres, gráficos, propiedades y exclusiones CP originales. Se eligieron piezas que no excluyen su clase y que cuentan con cuerpo/animación disponibles en el mismo paquete público. No hay elección de nivel, raza o sexo: se usa el cuerpo humano masculino para comparar presets.
- `armas.dat`, `escudos.dat`, `cascos.ini`: índices originales para renderizar arma, escudo y casco en cuatro direcciones. Los PNG conservan sus bytes originales. `class_sources.json` registra revisiones y hashes; los DAT/INI se leen como UTF-8.
- El icono GRH86206 de la Rodela no existe en el índice gráfico público: se muestra un fotograma de la propia animación del escudo como sustituto explícito. Nombre, defensa y animación de escudo siguen siendo los originales. No se modifica el archivo de objetos.

Las siguientes fórmulas son **adaptaciones del prototipo**, no el cálculo completo de AO20. `ClassCatalog` es la única fuente para servidor, UI y avatar:

- Vida máxima = redondear `500 × MODVIDA(clase) / 7.5`. Mantiene el Mago de pruebas en 500 y respeta las proporciones de vida originales.
- Maná máximo = redondear `3000 × MULT_MANA(clase) / 2.65`. Las cinco clases con multiplicador cero no reciben magia ni meditación.
- Golpe base = redondear `(30 + 2 × daño medio de arma y munición) × MODDANOARMAS`, usando `MODDANOPROYECTILES` para el Cazador. Por ahora el golpe usa el valor medio, sin tirada de acierto/evasión.
- Defensa física = suma de defensas medias de armadura, casco y escudo, interpretada como reducción porcentual y limitada al 60%. Daño recibido = redondear `golpe base × (1 − defensa / 100)`, mínimo 1.
- Resistencia mágica = 4% del perfil de habilidad 100 (`MagicResistanceSkillProtectionModifier=0.04`) más los valores `ResistenciaMagica` del equipo, máximo 60%.
- Daño mágico directo y periódico = tirada original del hechizo × bonificación `MagicDamageBonus` del equipo × resistencia del objetivo, redondeado y mínimo 1. Costes, curaciones e intervalos conservan sus reglas anteriores. Los efectos periódicos fijan sus modificadores al aplicarse; el bloqueo de clase impide cambiar equipo con un efecto activo.
- Los permisos de hechizos son una selección de pruebas propia: Mago conserva las 38 magias ejecutables para explorar el catálogo; Clérigo, Bardo y Druida tienen selecciones diferenciadas, y los híbridos una selección básica limitada por su maná máximo. No se presenta como la lista de aprendizaje oficial de AO20. La entrada 247 Disparo es de NPC; el arco se implementa mediante ataque físico y no se concede como magia.

Se conservan las licencias y atribuciones de recursos AO20 ya documentadas en el proyecto. El equipo del preset está fijo: se muestra en el personaje, en el selector y en el resumen Equipado del inventario. La grilla sigue siendo el orden local de provisiones; todavía no permite equipar/desequipar, comerciar o duplicar objetos de preset.

Quedan pendientes apuñalar/críticos específicos, evasión y bloqueo probabilísticos, invisibilidad/ocultación, mascotas, canciones/auras, profesiones, progresión y balance entre especialidades. Pirata y Ladrón usan un equipo básico compartido que respeta sus exclusiones; no se simulan todavía navegación, robo ni ocultación. Estas limitaciones se indican también en el selector.

## Validación

`class_presets_smoke.gd` verifica perfiles, recursos gráficos e iconos de las 12 clases, render de cuatro direcciones, diferencias de daño/defensa/maná, selección autoritativa, rechazo de magia del Cazador, alcance físico, snapshots, duplicados, bloqueo de cambio, recargas, reaparecer y macros por clase. `arena_network_client.gd` prueba el selector con eventos reales de interfaz y observa el cambio de equipo y estadísticas desde otro cliente, además de las regresiones de combate, recuperación, cámara e inventario.

La inspección gráfica se realiza con Godot nativo y el PCK exportado. La prueba final en navegador/Windows corresponde a la misma rama y al dedicado reiniciado; no se ejecutó un navegador automatizado en este entorno.
