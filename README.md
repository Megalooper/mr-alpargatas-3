# Mr. Alpargatas

Videojuego de plataformas 3D creado con Godot. El jugador recorre un nivel con movimientos de salto y combate, enfrenta enemigos y puede reanudar desde checkpoints.

## Tecnologías

- Godot Engine 4.6
- GDScript
- Godot Physics con Jolt para física 3D

## Funcionalidades

- Movimiento 3D con saltos, deslizamiento y saltos en paredes, agacharse y distintas patadas.
- Enemigos, proyectiles, vida y HUD.
- Checkpoints y reaparición.
- Menú principal, pausa y opciones para remapear controles.
- Entrada por teclado, ratón y mando.

## Requisitos e instalación

Se requiere Godot Engine 4.6. No hay dependencias externas declaradas.

```sh
git clone https://github.com/Megalooper/mr-alpargatas-3.git
cd mr-alpargatas-3
```

Abre `project.godot` con Godot 4.6 para importar los recursos del proyecto.

## Ejecución

Desde la carpeta del proyecto, ejecuta:

```sh
godot --path .
```

También puedes abrir el proyecto en el editor Godot y ejecutar el proyecto con F5.

## Exportación

El proyecto incluye presets de exportación para Windows Desktop, Web y macOS. Exporta desde **Proyecto > Exportar** en Godot; necesitarás las plantillas de exportación correspondientes a tu instalación. Configura una ruta de salida válida para el equipo donde exportes: los presets no incluyen una ruta de salida portátil para todas las máquinas. No hay configuración de despliegue.

## Estructura

- `project.godot`: configuración, escena de inicio, controles y autoloads.
- `level.tscn`, `mapa.tscn` y demás archivos `.tscn`: nivel, menús y escenas de juego.
- Archivos `.gd`: lógica del jugador, enemigos, HUD, controles, checkpoints y elementos del nivel.
- Modelos, texturas, audio y fuentes: recursos visuales y de sonido en la raíz del proyecto.

## Capturas

Añadir capturas aquí
