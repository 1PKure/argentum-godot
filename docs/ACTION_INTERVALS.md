# Cadencia de la arena

Ajuste solicitado para que el combate sea ligeramente más rápido. Estos son valores propios del prototipo, aplicados por el servidor; no son una copia exacta del balance AO20 ni modifican los DAT/INI originales.

| Acción o cruce | Perfil anterior | Perfil actual |
| --- | ---: | ---: |
| Poción → poción, compartido entre roja/azul | 380 ms | 330 ms |
| Golpe → golpe | 750 ms | 650 ms |
| Hechizo → hechizo, intervalo global | 1230 ms | 1100 ms |
| Golpe → hechizo | 800 ms | 700 ms |
| Hechizo → golpe | 800 ms | 700 ms |
| Golpe → poción | 800 ms | 700 ms |

La reducción es de aproximadamente 10–13%. No agrega bloqueos nuevos de poción → golpe ni poción ↔ hechizo. Se conservan el daño, los costes, la cantidad recuperada, las recargas individuales de cada hechizo, la duración de estados y la meditación. El movimiento mantiene su cadencia de 120 ms.

Los valores viven en CombatRules, RecoveryRules y SpellCatalog. La validación y el gasto siguen en PlayerRegistry. El tiempo opcional de sus métodos internos permite probar los límites con precisión; el cliente no envía timestamps ni decide cuándo una acción se acepta. Las firmas RPC no cambian.

Se separan las claves de recarga por hechizo (`spell:ID`) de las claves de grupo compartido (`group:CdEffectId`). Antes Dardo Mágico, ID 1, podía bloquear accidentalmente Restauración, grupo 1. Las variantes que pertenecen realmente al mismo grupo siguen compartiendo sus 30 segundos; el intervalo global reducido no los saltea.

`tests/action_intervals_smoke.gd` verifica el milisegundo anterior y el límite exacto, ambos sentidos de golpe/magia, el cruce golpe/poción, cambio de color, solicitudes repetidas y recargas individuales. La prueba con servidor y dos clientes conserva la validación de clics, macros, CTRL y pociones mientras se medita. La sensación final se evalúa jugando esta revisión con el servidor actualizado.
