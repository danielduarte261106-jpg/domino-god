# CombiFrutas

Prototipo de dominó doble-seis para Godot 4 y pantallas táctiles.

## Estructura

- `scenes/MainMenu.tscn`: menú principal e instrucciones.
- `scenes/Game.tscn`: cámara, plano de tablero y gestor de partida.
- `scenes/FruitTile.tscn`: ficha interactiva, usada tanto en la mano como en el tablero.
- `scenes/TriviaPopup.tscn`: pregunta modal con opciones.
- `scripts/GameManager.gd`: genera y baraja las 28 fichas, maneja la partida y el comodín.
- `scripts/UIManager.gd`: HUD en `CanvasLayer`, tema, feedback, animaciones y partículas.
- `scripts/DominoPiece.gd`: dibujado, texturas y arrastre mouse/táctil.
- `scripts/TriviaManager.gd`: preguntas, fórmulas combinatorias y recompensa de trivia.
- `scripts/GameEconomy.gd`: vidas, monedas, estrellas y premios como Autoload.

## Árbol de nodos recomendado

La interfaz se crea desde los scripts para adaptarse al tamaño de pantalla; este es el árbol lógico de cada escena:

```text
MainMenu (Control, MainMenu.gd)
├── Fondo (ColorRect)
└── CenterContainer
    └── VBoxContainer
        ├── Título y subtítulo (Label)
        └── Botones: Jugar / Instrucciones / Salir

Game (Control, GameManager.gd)
├── Camera2D (activa; apunta al tren del tablero)
├── BoardWorld (Node2D; fichas de mesa bajo la cámara)
├── BackgroundLayer (CanvasLayer, layer = -1)
│   └── Fondos cruzados Huerto / Pizarrón
├── GameUILayer (CanvasLayer, layer = 1)
│   └── MarginContainer / VBoxContainer
│       ├── Modo y extremos (Labels / botones)
│       ├── Mano (ScrollContainer / HBoxContainer de DominoPiece)
│       └── Acciones y navegación
└── UIManager (CanvasLayer, layer = 10)
    ├── HUD superior, estado y textos flotantes
    ├── CPUParticles2D (confeti)
    └── TriviaPopup (Control, modal, rebote y temporizador)

FruitTile.tscn (Button, DominoPiece.gd)
└── Mitades dibujadas por el script (textura o nombre de fruta)

Autoloads: GameEconomy y TriviaManager
```

### Orden de configuración de `Game.tscn`

1. Mantén la raíz `Game` como `Control` con `GameManager.gd`.
2. Añade `Camera2D` y `BoardWorld (Node2D)` como hijos directos de `Game`. La cámara debe estar habilitada; el gestor centra y anima posición/zoom sobre los límites reales de las fichas.
3. El gestor crea las capas de fondo y UI automáticamente. La capa del fondo usa `layer = -1`, el HUD y controles usan `layer = 1`, y `UIManager` usa `layer = 10` para que menús, partículas y trivia se dibujen encima del tablero.
4. No pongas las fichas de la cadena en un `CanvasLayer`: deben ser hijas de `BoardWorld` para que la cámara las panee y aplique zoom. Las fichas de la mano sí están en la capa de UI.
5. `CPUParticles2D` se crea desde `UIManager.gd` dentro de su `CanvasLayer`; no hace falta instanciar un emisor adicional en el editor.
6. `TriviaPopup.tscn` se instancia como hijo de `UIManager`, así que el oscurecimiento, la tarjeta, las opciones y la barra temporal permanecen sobre el HUD y no se mueven con la cámara.

El arrastre usa el umbral de 12 píxeles para distinguir un toque de una acción de drag. En el evento táctil se convierte la posición de pantalla a coordenadas del lienzo invertido de la cámara; el zoom/paneo del tablero no cambia la zona de destino. Para jugar con botones, todavía están disponibles «Colocar izquierda» y «Colocar derecha».

## Imágenes de frutas

El juego intenta primero cargar imágenes desde `Escritorio/frutas` (la carpeta `frutas` dentro del Escritorio del usuario del sistema). Acepta `.png`, `.jpg`, `.jpeg` y `.webp`. Se recomienda nombrarlas `Manzana.png`, `Banana.png`, `Cereza.png`, `Fresa.png`, `Naranja.png`, `Pera.png` y `Uva.png`; las imágenes cuyo nombre no coincide con una fruta se asignan por orden alfabético.

Android no puede acceder a una carpeta arbitraria del Escritorio del equipo donde se desarrolló el juego. Para APK, copia las imágenes a `res://assets/frutas/` y expórtalas junto al proyecto. Si no hay imágenes, las fichas muestran los nombres de las frutas.

## Proyecto y exportación Android

Valores iniciales en **Project > Project Settings > Display > Window**:

- **Size > Viewport Width:** `720`
- **Size > Viewport Height:** `1280`
- **Size > Window Width Override / Height Override:** `720` / `1280`
- **Handheld > Orientation:** `Portrait` (valor de configuración `1`). Para horizontal usa `Landscape` (valor `0`) y un viewport, por ejemplo, `1280 × 720`.
- **Stretch > Mode:** `canvas_items`
- **Stretch > Aspect:** `expand`

Para generar un APK, instala las plantillas de exportación de la misma versión de Godot y configura en **Editor > Manage Export Templates**. En **Project > Export**, agrega el preset **Android**, establece un nombre de paquete único (por ejemplo, `com.tuestudio.combifrutas`), elige arquitectura y firma la versión de distribución con una clave de release. En **Editor > Editor Settings > Export > Android**, configura las rutas del Android SDK y Java SDK requeridos por esa versión de Godot. Exporta un APK para instalación directa o un AAB para Google Play; prueba ambos en un dispositivo real y comprueba los permisos de almacenamiento si posteriormente agregas selección de imágenes del usuario.

La trivia incluye probabilidad, estadística, cultura general y una pregunta dinámica de permutaciones/variaciones basada en los tipos de fruta distintos en la mano. Toda respuesta correcta recupera una vida y da 5 monedas; acertar la pregunta combinatoria también suma una estrella y un premio. Como el temario concreto de «Unidad III» depende de la materia, las preguntas de esa unidad son ejemplos editables en `scripts/TriviaManager.gd`.
