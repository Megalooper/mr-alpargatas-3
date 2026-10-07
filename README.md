# Mr. Alpargatas

Videojuego de plataformas 3D desarrollado con Godot 4.6. Acompaña a Mr. Alpargatas en un nivel de saltos, combate y obstáculos, con checkpoints para retomar el recorrido tras caer.

## Tecnologías

- Godot Engine 4.6 y GDScript.
- Física 3D con Jolt.
- Escenas 3D, modelos, texturas, animaciones y audio importados por Godot.

## Características

- Movimiento de plataformas con salto, salto largo, salto en pared, deslizamiento por pared, agacharse y golpe contra el suelo.
- Combate cuerpo a cuerpo con patadas, combos y kickspin.
- Enemigos sapo y un mago que dispara proyectiles; las bolas de fuego se pueden devolver con un golpe.
- Vida, HUD, objetos de corazón, muerte y reaparición desde checkpoints.
- Plataformas móviles, trampas y plataformas activadas por botones.
- Menú principal y de pausa, opciones y reasignación persistente de controles.
- Entrada para teclado, ratón y mando; controles del mando adaptados a Xbox, PlayStation o Nintendo.

## Requisitos

- Godot Engine 4.6.
- No hay dependencias externas declaradas ni pasos de instalación adicionales.

## Obtener y abrir el proyecto

```sh
git clone https://github.com/Megalooper/mr-alpargatas-3.git
cd mr-alpargatas-3
```

En Godot, importa o abre el archivo `project.godot`. El editor importará los recursos del proyecto al abrirlo por primera vez.

## Ejecutar

Desde la carpeta del proyecto, ejecuta el juego con:

```sh
godot --path .
```

También puedes abrir el proyecto en Godot y ejecutarlo con **F5**.

## Controles predeterminados

| Acción | Teclado / ratón | Mando |
| --- | --- | --- |
| Moverse | WASD o flechas | Cruceta o stick izquierdo |
| Saltar | Espacio o clic izquierdo | A |
| Agacharse | Ctrl o botón central del ratón | Hombro derecho |
| Patear | J o clic derecho | X |
| Kickspin | K o E | Y |
| Pausa | Enter o P | Start |
| Centrar cámara | V o C | Stick derecho |
| Reiniciar escena actual | R | — |

La cámara también se controla con el movimiento del ratón o el stick derecho. Las opciones del juego permiten reasignar controles.

## Exportación

`export_presets.cfg` contiene presets para Windows Desktop, Web y macOS. Para exportar, abre **Proyecto > Exportar** en Godot, instala las plantillas de exportación que solicite el editor y elige una ruta de salida válida para tu equipo. Los presets no proporcionan rutas portátiles comunes y el proyecto no incluye configuración de despliegue.

## Estructura del proyecto

- `project.godot`: configuración del proyecto, escena de inicio, acciones de entrada y autoloads.
- `level.tscn`, `mapa.tscn` y otros archivos `.tscn`: nivel y escenas reutilizables de personajes, enemigos, interfaz y plataformas.
- Archivos `.gd`: lógica de movimiento, combate, enemigos, cámara, menús, controles y checkpoints.
- Modelos, texturas, audio y fuentes: recursos del juego ubicados en la raíz del proyecto.

## Capturas

Añadir capturas aquí
