# Ajustes de tácticas y clics de interfaz

Las semimágicas usan Paralizar→golpe→Descarga. Se retiran Flecha Eléctrica y
Misiles de ambos caminos alternativos. Solo después de tres remates de
Descarga tras golpe se habilita Fuego Mágico/Tormenta si no alcanza el maná
para Descarga y la clase puede lanzarlos. Usar esa alternativa reinicia el
contador. La presión de magia a distancia aparece tras dos combos y tiene
20% de decisión por oportunidad. Al iniciar otra práctica se borra el contador.
El paso semimágico pasa124→140ms; Mago/Druida/Cazador mantienen124ms.

El mago conserva su apertura doble Apocalipsis. Al reconstruir maná puede
iniciar ofensiva con un presupuesto real Apocalipsis+Descarga (1460MP), en
vez de esperar siempre2000MP. Si para el segundo lanzamiento puede pagar
otro Apocalipsis lo prioriza; si no, busca Descarga. Primer compromiso450–650ms
tras la cuenta (antes600–850); error de puntero deliberado4% (antes6%).
Costos, percepción, intervalo mágico1250ms y recuperación permanecen iguales.

UIClickAudio registra BaseButton y PopupMenu existentes y futuros desde el
inicio del cliente. Genera una vez un PCM mono16bit/44100Hz de45ms, sin
assets externos; un reproductor compartido con3voces y guarda25ms evita
notificaciones duplicadas de una misma acción. No reproduce por hover,
refrescos o botones deshabilitados. El registro ocurre al entrar al árbol, sin diferir referencias a controles
que pueden destruirse al reconstruir menús. Se omite
el dedicado --server. El audio usa ArenaAudioMix/Efectos y por lo tanto
General/Efectos del menú, incluso en web Sample/Master. No se agregan buses
web ni se modifican los sonidos de combate/pisos.

La GUI nativa comprueba clics reales desde Crear sala y Menú de combate.
La prueba de audio comprueba conexiones únicas, controles transitorios,
deshabilitados, listas, PCM y margen de amplitud. La reproducción audible
final en el navegador requiere feedback del usuario; no se asume por tests
con salida Dummy. Gráficos/HUD permanecen aprobados.

## Cierre de gameplay alpha: presión y recuperación

Ajuste posterior al feedback de dificultad: magia del bot1150–1250ms
(antes1250–1350), remover con reacción520–700ms (antes650–850), siempre
esperando también su reloj mágico compartido. Pociones: decisión100–150ms;
cadencia250ms alternando los canales clic/Usar legales del jugador. Cada
canal conserva280ms y el mínimo compartido200ms; no se cambia la curación,
el maná recuperado ni los intervalos del jugador. Si un golpe bloquea una
poción se conserva la decisión pendiente.

Las semimágicas buscan Paralizar cada5–6,5s cuando el rival no está ya
inmovilizado; conservan140ms por paso. Estar defendiendo con una poción
pendiente ya no cancela indefinidamente el golpe si tienen al menos30%HP.
El remate sigue siendo Descarga, con los600ms reales entre acciones. Los
fallbacks de fuego siguen reservados para después de varios combos.
El Mago conserva124ms por paso y sus pares de Apocalipsis/Descarga; con
55%HP o más intercala azules durante la recuperación. Una curación no
interrumpe un combo ya iniciado salvo que la vida caiga por debajo de35%.
No se aumentan daño, precisión, recursos ni velocidad de movimiento.

El clic de interfaz baja2dB. Los botones de pociones omiten ese clic según
su contenido actual, también después de moverlos; la acción de beber y su
feedback propio se conservan. Equipar objetos y los demás menús mantienen
el clic. La prueba GUI usa un clic real sobre una azul para comprobar ambos
resultados: recuperar maná y no disparar UIClickAudio.


Preparación web: las cuatro casillas decorativas de cada mapa quedan abiertas, conservando sus gráficos y límites exteriores. Pisadas suben3dB en el emisor (−8→−5), sin modificar WAV ni preferencias guardadas. El Mago reevalúa un presupuesto de combo vacío cada120ms en lugar de esperar1150ms, sin adelantar lanzamientos reales. Detalles de conexión/ranking opcional en WEB_DEPLOYMENT.md.


## Persecución semimágica, Asesino y cierre para web

Semimágicas: Paralizar cada3–4s al tener objetivo no enraizado en alcance,
con maná para Paralizar+Remover en vez de exigir además Descarga. Pueden
reemplazar una persecución fallida por otra raíz; conservan el remate de un
golpe real. Si el rival huye sin raíz, ahorran la oportunidad de combo al aire
para volver a controlarlo. Costos, puntería retrasada y reloj mágico se mantienen.

Asesino:8% de apuñalada sobre impacto físico con arma,28% pegando desde la
casilla detrás del objetivo según su orientación autoritativa. Daño×1,35. No
aplica a arco/hechizos, no ignora evasión/escudo ni permite repetir el golpe
antes de1200ms. La consola de los participantes diferencia apuñalada de golpe.

Pociones para TODOS:320ms por vía y240ms de mínimo combinado clic/Usar,
antes280/200; se conservan27HP,5%MP y600ms tras golpe. Máximos teóricos de
curación con rojas:84,4HP/s en una vía y112,5HP/s alternando, antes96,4/135.
El bot decide cada280ms (antes250) alternando las mismas vías legales. Cambiar
de color o alternar Q/E/Espacio no crea otra vía.

Ranking nuevo por etapa en archivo separado; homenaje intacto y anterior
archivado, sin borrado en cada reinicio. Ver RANKING.md. La web sigue privada y
el dedicado local hasta resolver hosting gratuito/persistencia remota.
