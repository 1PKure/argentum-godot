# Ranking de la arena

`ArenaRankingStore` es el registro del servidor dedicado. Guarda estado privado
en `user://arena_ranking_v1.json`; no publica una web ni abre un endpoint HTTP.
Una instancia del servidor administra el archivo y todas sus salas.

## Identidad y apodos

La identidad de invitado contiene un identificador hexadecimal de 32 caracteres
y un secreto hexadecimal de 64 caracteres. El cliente conserva ambos en su
almacenamiento local. El servidor guarda sólo el SHA256 del secreto. El secreto
es necesario para recuperar o renombrar una identidad existente; cambiarlo no
permite apropiarse de sus resultados. No equivale a una cuenta recuperable:
perder la identidad local implica perder la prueba de propiedad del invitado.

Los apodos tienen entre 2 y 20 letras Unicode, números, espacios, guiones o
guiones bajos. Se recortan los extremos y se aplica casefold Unicode para impedir
duplicados por mayúsculas o variantes como `Straße`/`STRASSE`. `milusita` queda
reservado en cualquier combinación de mayúsculas.

## Puntuación y publicación futura

Cada victoria confirmada suma **100 puntos**, tanto en PvP como contra un bot.
Se mantienen `pvp_wins`, `bot_wins`, `wins` y `points`. `ServerMain` llama a
`record_victory` únicamente después de validar un ganador real. El store no
decide las condiciones del duelo ni concede recompensas por abandonos.

La fila honorífica `milusita` aparece siempre primera, con **9.999.999.999 puntos**,
`honorary: true` y cero victorias reales. No representa partidas inventadas.
Después se muestran como máximo 50 jugadores, ordenados por puntos y luego por
apodo. Los empates tienen orden determinista.

`snapshot()` devuelve `schema: 1`, `revision`, `updated_at` en segundos Unix,
`refresh_after_seconds: 30`, `total_players` y `entries`. Cada fila pública tiene
un `id` opaco, `nickname`, `rank`, contadores, puntos y `honorary`.
`export_public_json()` serializa exclusivamente ese snapshot. No incluye hashes,
secretos ni el historial privado de rondas. Es la base de una futura integración
web, sin publicar datos por sí misma.

## API

```gdscript
var ranking := ArenaRankingStore.new()
var registration := ranking.register(identity_id, secret, nickname)
# {ok, message, player} cuando se autentica/crea/renombra correctamente.

var award := ranking.record_victory(unique_round_id, identity_id, "pvp")
# {ok, message, player, awarded}. Repetir una ronda devuelve awarded=false.

var public_data := ranking.snapshot()
var future_web_json := ranking.export_public_json()
```

`get_player(identity_id)` devuelve los campos públicos del jugador. `revision` y
`updated_at` también están disponibles como propiedades para refrescos ligeros.
Un resultado negativo incluye `ok: false` y `message`.

Los identificadores de ronda admiten letras ASCII, números, `:`, `_`, `.`, `-`,
con longitud de 1 a 160 caracteres. Deben ser únicos entre ejecuciones del
servidor. La misma ronda no puede cambiar de ganador o modalidad al reintentarse.

## Persistencia

Registro, cambio de apodo y victoria se preparan como candidatos sin modificar el
estado confirmado. Se escriben y verifican archivos temporales; reemplazar el
principal constituye el commit. Si el guardado falla antes de ese punto, no se
modifican puntos, identidad, revisión ni ledger. El resultado se puede reintentar.

Después del commit se reemplaza `.bak` por la misma versión confirmada. Una
anomalía al refrescar ese respaldo queda en `last_backup_error`; no se informa
falsamente una victoria rechazada cuando el principal ya se guardó. Esta es una
implementación para un único proceso escritor, no una base distribuida.

El respaldo recupera un principal ausente, corrupto o incoherente con sus
contadores. La recuperación restaura también el ledger de rondas y repara el
principal. Si ambas copias están dañadas, `available` queda en `false` y se
rechazan escrituras: nunca se reinician puntuaciones silenciosamente.

El ledger se conserva completo para impedir duplicados después de reinicios.
Su compactación o migración futura debe preservar esa garantía.

## Validación

`tests/ranking_store_smoke.gd` comprueba identidades, alias Unicode, apodo
reservado, el homenaje, puntos PvP/bot, dos jugadores, reinicio, doble entrega,
reutilización conflictiva de una ronda, exportación pública, recuperación del
respaldo, corrupción doble, rollback ante fallo de guardado, obstrucción real del
archivo y el límite de 50 jugadores más homenaje.

## Lobby, red y futura página

El botón **Ranking** del directorio y de la sala muestra la tabla y permite elegir
apodo. El cliente se autentica automáticamente al conectar, consulta cada 30 s y
recibe actualizaciones al confirmarse una victoria. El protocolo es 23. Se captura
la identidad de los participantes al comenzar la ronda: reconexiones, resultados
repetidos, derrotas, abandonos o dos ventanas del mismo perfil no regalan puntos.
Los fallos de guardado se reintentan cada cinco segundos mientras sigue el servidor.

En web, `window.argentumRanking` contiene el snapshot público y el evento
`argentum:ranking` anuncia sus cambios. La futura página puede aprovechar este
contrato cuando el cliente está conectado; una clasificación pública independiente
del juego requerirá implementar su endpoint de lectura. No se abrió ningún puerto
HTTP ni se añadió servicio de pago, cuenta, proveedor externo o base de datos.

Para QA se puede usar `--ranking-path=/ruta/aislada.json` en el dedicado. En uso
normal hay que conservar el directorio de datos `user://` del servidor y su archivo
`.bak` entre actualizaciones; reemplazar el ejecutable/proyecto no exige borrarlos.

Crear y Unirse piden un nick y esperan confirmación del registro antes de entrar. La autenticación automática inicial sólo prepara la identidad; no obliga a abrir Ranking. El Ranking permite renombrar después y la sala muestra el nombre confirmado. Un nombre vacío, reservado o duplicado deja al usuario en el directorio con feedback, sin crear salas a medias.
