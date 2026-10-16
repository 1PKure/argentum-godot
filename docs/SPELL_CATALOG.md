# Catálogo AO20 y alcance implementado

Se importaron las 213 entradas del Hechizos.dat original. 39 están habilitadas para el combate de la arena. El libro muestra primero las habilitadas; Ver catálogo completo permite consultar todas, con búsqueda por nombre o ID y un motivo para cada entrada pendiente.

Un hechizo pendiente no puede armarse, asignarse a un acceso ni gastar recursos. Los hechizos de NPC, recetas y administración no forman parte del PvP de jugadores. No se presenta el catálogo como un port completo de los 213 hechizos.

Los habilitados incluyen daño/curación directa, parálisis/inmovilización, remover/limpieza y restauración/daño periódico. Los intervalos individuales del DAT se respetan además de los 1230 ms globales. Las duraciones de raíces y los valores/ticks de EffectsOverTime.dat se resuelven en el servidor; parálisis impide caminar, pero permite removerse, curarse y beber.

El perfil de prueba omite requisitos de clase, skill, estamina y equipo. No implementa fórmulas de resistencia ni multiplicadores de equipo. Los hechizos que dependen del efecto de esos sistemas —atributos, invisibilidad en red, invocaciones, armas, transformaciones, etc.— quedan pendientes, con su motivo. El siguiente paso de port debe abordar esos sistemas, no habilitarlos cambiando únicamente una lista.

Iconos, FX y audio conservan los recursos de origen. Siete IDs de sonido referenciados por el DAT no existen en el repositorio público de la misma revisión; se usa el sonido 16 como sustituto explícito. Se registra en spells_sources.json, junto con hashes y archivos.

| ID | Hechizo | Estado |
| --- | --- | --- |
| 1 | Dardo Mágico | Habilitado |
| 2 | Flecha Mágica (PVP) | Habilitado |
| 12 | Curar Heridas Leves | Habilitado |
| 13 | Curar Heridas Graves | Habilitado |
| 3 | Misil Mágico (PVP) | Habilitado |
| 4 | Aliento de Dragón | Habilitado |
| 5 | Rugido Salvaje (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 6 | Petrificar (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 7 | Invocar Lobo | Requiere el sistema de invocaciones y mascotas. |
| 8 | Invocar Esqueleto Guerrero | Requiere el sistema de invocaciones y mascotas. |
| 9 | Invocar Mascotas Domadas | Requiere el sistema de invocaciones y mascotas. |
| 10 | Mimetizar | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 11 | Curar Veneno | Habilitado |
| 14 | Resucitar | Resurrección requiere portar sus reglas de energía y clase. En la arena podés Reaparecer. |
| 15 | Detectar Invisibilidad | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 16 | Invocar Elemental de Fuego | Requiere el sistema de invocaciones y mascotas. |
| 17 | Invocar Elemental de Agua | Requiere el sistema de invocaciones y mascotas. |
| 18 | Invocar Elemental de Tierra | Requiere el sistema de invocaciones y mascotas. |
| 19 | Invocar Elemental de Viento | Requiere el sistema de invocaciones y mascotas. |
| 20 | Invocar Verraco | Requiere el sistema de invocaciones y mascotas. |
| 21 | Celeridad | Requiere atributos, equipo y sus fórmulas de combate. |
| 22 | Fuerza | Requiere atributos, equipo y sus fórmulas de combate. |
| 23 | Partitura de la Armonía | Requiere atributos, equipo y sus fórmulas de combate. |
| 24 | Invisibilidad Menor | Requiere visibilidad por jugador y ocultación en la red. |
| 25 | Paralizar | Habilitado |
| 26 | Inmovilizar | Habilitado |
| 27 | Remover Parálisis | Habilitado |
| 28 | Aturdir | Habilitado |
| 29 | Devolver Movilidad | Habilitado |
| 30 | Invisibilidad Menor | Requiere visibilidad por jugador y ocultación en la red. |
| 31 | Curar Heridas Criticas | Habilitado |
| 32 | Incinerar | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 33 | Invocar Momia | Requiere el sistema de invocaciones y mascotas. |
| 34 | Celeridad Mayor | Requiere atributos, equipo y sus fórmulas de combate. |
| 35 | Fuerza Mayor | Requiere atributos, equipo y sus fórmulas de combate. |
| 36 | Invocar Gorila | Requiere el sistema de invocaciones y mascotas. |
| 37 | Celeridad Menor | Requiere atributos, equipo y sus fórmulas de combate. |
| 38 | Fuerza Menor | Requiere atributos, equipo y sus fórmulas de combate. |
| 39 | Ascua Fugaz (PVP) | Habilitado |
| 40 | Resplandor Igneo | Habilitado |
| 41 | Tormenta de Fuego | Habilitado |
| 42 | Invocar Zombie | Requiere el sistema de invocaciones y mascotas. |
| 43 | Flecha Eléctrica (PVP) | Habilitado |
| 44 | Materializar: Bebida | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 45 | Materializar: Comida | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 46 | Portal Planar | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 47 | Invocar Pixie Sagrada | Requiere el sistema de invocaciones y mascotas. |
| 48 | Invocar Goblin | Requiere el sistema de invocaciones y mascotas. |
| 49 | Testeo Descarga Semimagicas | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 50 | Impacto Eléctrico | Habilitado |
| 51 | Descarga Eléctrica | Habilitado |
| 52 | Fulgor Ígneo (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 53 | Apocalipsis | Habilitado |
| 54 | Implosión | Habilitado |
| 55 | Lamento de la Banshee | Habilitado |
| 56 | Juicio Final | Habilitado |
| 57 | Ralentizar (PVP) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 58 | TESTEO GRHS | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 59 | Rayo Elemental | Habilitado |
| 60 | Magia de Humana No-Muerta | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 61 | Eco Ígneo (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 62 | Destello Malva (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 63 | Fractura Glacial (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 64 | Aliento Carmesí (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 65 | Energía Ancestral (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 66 | Invocar Huargo | Requiere el sistema de invocaciones y mascotas. |
| 67 | Invocar Oso Pardo | Requiere el sistema de invocaciones y mascotas. |
| 68 | Invocar Lobo Huargo | Requiere el sistema de invocaciones y mascotas. |
| 69 | Invocar Ursidae | Requiere el sistema de invocaciones y mascotas. |
| 70 | Invocar Orco | Requiere el sistema de invocaciones y mascotas. |
| 71 | Invocar Mascotas | Requiere el sistema de invocaciones y mascotas. |
| 100 | Maldición de Kraken | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 101 | Heroísmo | Requiere atributos, equipo y sus fórmulas de combate. |
| 111 | Muro de Espinas | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 112 | Disipar Magia | Habilitado |
| 113 | Rafaga de Espinas | Habilitado |
| 121 | Partitura Maldita | Requiere atributos, equipo y sus fórmulas de combate. |
| 122 | Palabra Mortal | Habilitado |
| 131 | Destierro | Habilitado |
| 132 | Oración Divina | Habilitado |
| 133 | Plegaria | Habilitado |
| 141 | Vacío Abisal | Habilitado |
| 142 | Puntazo Incapacitador (PVP) | Requiere atributos, equipo y sus fórmulas de combate. |
| 151 | Grito Sanador | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 152 | Frenesí Berserker | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 153 | Invocar Piraña | Requiere el sistema de invocaciones y mascotas. |
| 154 | Invisibilidad | Requiere visibilidad por jugador y ocultación en la red. |
| 155 | Invocar Scylla | Requiere el sistema de invocaciones y mascotas. |
| 201 | Maldición del Bufón | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 202 | Gloria del Bufón | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 203 | Remover Parálisis (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 204 | Ira de ReyarB | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 205 | Flecha (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 206 | Incinerar (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 207 | Apocalipsis (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 208 | Partículas Tóxicas (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 209 | Flecha Scramer (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 210 | Colmillo Venenoso (Araña Roja) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 211 | Colmillo Filoso (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 212 | Entrada 212 sin definición | Entrada sin definición de hechizo en el archivo original. |
| 213 | Muro de Espinas (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 214 | Apocalipsis (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 215 | Aliento de Dragón (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 216 | Incinerar (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 217 | Descarga Eléctrica (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 218 | Partitura Maldita (Area) | Requiere atributos, equipo y sus fórmulas de combate. |
| 219 | Destierro (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 220 | Partitura Maldita (Area) | Requiere atributos, equipo y sus fórmulas de combate. |
| 221 | Ira de Chicken (AreaGMs) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 222 | Magia del Mago Malvado | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 223 | Tormenta de Fuego (Área) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 226 | Invocar Scylla Leviatán | Requiere el sistema de invocaciones y mascotas. |
| 227 | Invocar Medusas (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 228 | Invocar Elemental Infernal (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 229 | Devorador del Inframundo (NPCs) (Área) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 230 | Invocar Galeón Fantasmal (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 231 | Explosión de Fuego (ÁREA) (NPCs) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 232 | Invocar Arquero Capturado (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 233 | Flecha de Arquero Capturado (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 234 | Lluvia de flechas de Arquero Capturado (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 235 | Entrada 235 sin definición | Entrada sin definición de hechizo en el archivo original. |
| 236 | Implosión (NPCs) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 237 | Grito del Guerrero | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 238 | Honor del Bandido | Requiere atributos, equipo y sus fórmulas de combate. |
| 239 | Ataque de Veneno Inferior (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 240 | Invisibilidad | Requiere visibilidad por jugador y ocultación en la red. |
| 241 | Invisibilidad | Requiere visibilidad por jugador y ocultación en la red. |
| 242 | Restauración mayor | Habilitado |
| 243 | Putrefacción | Habilitado |
| 244 | Provocar | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 245 | Corte Extendido | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 246 | Provocar | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 247 | Disparo | Habilitado |
| 248 | Flecha Cargada | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 249 | Aullido Ensordecedor (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 250 | Danza de Flechas | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 251 | Partitura de Regeneración | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 252 | Eco Veloz | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 253 | Golpes Rápidos | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 254 | Serenata Esquiva | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 255 | Precisión Armónica | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 256 | Cañonazo | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 257 | Protección Divina 3 | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 258 | Forma de Lobo | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 259 | Forma de Oso | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 260 | Penitencia | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 261 | Rejuvenecimiento | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 262 | Forma de Espíritu del Bosque | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 263 | Bendición | Habilitado |
| 264 | Robar Magia | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 265 | Desplazamiento Veloz | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 266 | Desgarro | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 267 | Ataque de Veneno (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 268 | Restauración menor | Habilitado |
| 269 | Restauración | Habilitado |
| 270 | Protección Divina 1 | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 271 | Protección Divina 2 | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 272 | Acelerar Mascotas | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 273 | Mejorar Ataque de Mascotas | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 274 | Afilar | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 275 | Afilar Avanzado | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 276 | Afilar Superior | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 277 | Refuerzo | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 278 | Refuerzo Avanzado | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 279 | Refuerzo Superior | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 280 | Protección de Tute | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 281 | Filo de Toxina | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 282 | Veneno 2 | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 283 | Veneno 3 | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 284 | Veneno de mana | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 285 | Receta Poción de Vida | Receta de fabricación; requiere inventario y profesiones. |
| 286 | Receta Poción de Maná | Receta de fabricación; requiere inventario y profesiones. |
| 287 | Receta Poción de Fuerza | Receta de fabricación; requiere inventario y profesiones. |
| 288 | Receta Poción de Agilidad | Receta de fabricación; requiere inventario y profesiones. |
| 289 | Receta Poción de Energía | Receta de fabricación; requiere inventario y profesiones. |
| 290 | Receta Antídotos | Receta de fabricación; requiere inventario y profesiones. |
| 291 | Onda Mágica | Habilitado |
| 292 | Invocar Murcielago Gigante (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 293 | Invocar Dragón (NPCS) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 294 | Eco Ígneo (Elemental) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 320 | Mago Zephyr | Requiere el sistema de invocaciones y mascotas. |
| 321 | Druida Lyra | Requiere el sistema de invocaciones y mascotas. |
| 322 | Barda Kaelith | Requiere el sistema de invocaciones y mascotas. |
| 323 | Clerigo Branok | Requiere el sistema de invocaciones y mascotas. |
| 324 | Asesino Roderic | Requiere el sistema de invocaciones y mascotas. |
| 325 | BandidA Draven | Requiere el sistema de invocaciones y mascotas. |
| 326 | Paladin Elarion | Requiere el sistema de invocaciones y mascotas. |
| 327 | Guerrero Thorin | Requiere el sistema de invocaciones y mascotas. |
| 328 | Cazadora Thalindra | Requiere el sistema de invocaciones y mascotas. |
| 329 | Grito Sanador (BRANOK) | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 330 | Magia de Branok | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 331 | Magia de Kaelith | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 332 | Magia de Kaelith | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 333 | Magia de Kaelith | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 334 | Magia de Lyra | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 335 | Magia de Lyra | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 336 | Magia de Zephyr | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 337 | Magia de Zephyr | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 338 | Magia de Zephyr | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 339 | Slow Octavius | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 340 | Receta Runa de Fuego | Receta de fabricación; requiere inventario y profesiones. |
| 341 | Receta Runa de Agua | Receta de fabricación; requiere inventario y profesiones. |
| 342 | Receta Runa de Tierra | Receta de fabricación; requiere inventario y profesiones. |
| 343 | Receta Runa de Viento | Receta de fabricación; requiere inventario y profesiones. |
| 344 | Receta Poción de Veneno | Receta de fabricación; requiere inventario y profesiones. |
| 345 | Sangre Divina | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 346 | Receta del Exoesqueleto Enano | Receta de fabricación; requiere inventario y profesiones. |
| 347 | Activar Nucleo Enano | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 348 | Rugido Arcano (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 349 | Latido Ígneo (NPC) | Hechizo de NPC o de administración; fuera de esta arena PvP. |
| 350 | Enredar | Habilitado |
| 351 | Fervor del Paladín | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |
| 352 | Orbe de Luz | Requiere portar sus reglas específicas de AO20; todavía no está habilitado. |

La animación de Implosión se resuelve por FX4, cuyo GRH coincide con el12834 guardado directamente en el DAT. WAV113 se convirtió de ADPCM a PCM conservando el original; estas adaptaciones no alteran reglas de combate.
