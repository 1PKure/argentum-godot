# Interfaz de combate AO20

Esta iteración parte de `work/web-export-alpha`, sin incorporar la prueba retirada de `work/pvp-spells`.

La interfaz usa los recursos originales de AO20: marco de 1024×768, consola superior, paneles Inventario/Hechizos y barras de vida/maná. Se adapta al espacio disponible conservando proporciones y toda la arena se presenta dentro del área de juego. El minimapa muestra posiciones reales y obstáculos.

Los botones y la barra de desplazamiento no toman foco de teclado. WASD y CTRL conservan sus acciones anteriores al cambiar de pestaña o seleccionar un casillero. Inventario y accesos numéricos se presentan vacíos. Lanzar permanece deshabilitado porque la base estable aún no tiene un libro de hechizos ni su resolución; esta entrega no incorpora reglas nuevas de hechizos, ni el modo de combate descartado.

La consola recibe los eventos ya existentes de PlayerNetwork. Muestra entradas/salidas y diferencias confirmadas de vida/maná, además de muerte. No imprime cambios por movimiento ni presenta los valores iniciales del snapshot como daño. Separa Todo/Combate/Sistema, limita el historial a 200 mensajes y trata nombres como texto, sin ejecutar BBCode.

El protocolo existente sólo informa cambios de estado: la consola no atribuye el atacante, un hechizo ni el motivo de un rechazo que el servidor no haya comunicado. Estos eventos podrán incorporarse con el port de combate. No se cambió la tabla de RPC; este cliente es compatible con el servidor de `work/web-export-alpha`.

## Prueba desde Windows

1. En GitHub Desktop: Fetch origin y elegir `work/ao20-combat-ui` en Current branch.
2. Abrir el proyecto una vez en Godot para importar los nuevos PNG y registrar las clases. Ejecutar `tools/Start-PrivateWebTest.cmd` si se prueba desde la web privada.
3. Conectar dos clientes. Moverse con WASD, alternar Inventario/Hechizos y desplazarse por la consola. Comprobar que el movimiento sigue respondiendo después de esos clics.
4. Acercarse al otro jugador, orientarse hacia su casilla y pulsar CTRL. La pérdida de vida confirmada debe aparecer en ambas consolas; el golpe físico no gasta maná.
5. Probar filtros y desconexión desde Menú. Al reconectar se reinician el historial y las barras de la sesión anterior.

Los botones y atributos de AO20 para sistemas aún ausentes no producen estadísticas ni acciones ficticias. Esta iteración se limita a PvP; lobbies, bot y hechizos quedan para las siguientes entregas.
