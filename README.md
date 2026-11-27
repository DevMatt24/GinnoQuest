# Ginno Quest

Plataformero 2D en pixel art hecho con **Godot 4.7**. Controlás a un caballero que recorre islas flotantes, derrota enemigos, junta monedas, compra mejoras a un vendedor, activa checkpoints y se enfrenta a un dragón final para abrir el portal de fin de nivel.


## Índice

1. [Características](#características)
2. [Cómo ejecutarlo](#cómo-ejecutarlo)
3. [Controles](#controles)
4. [Estructura del proyecto](#estructura-del-proyecto)
5. [Configuración del proyecto](#configuración-del-proyecto)
6. [Sistemas del juego](#sistemas-del-juego)
7. [Capas de colisión y grupos](#capas-de-colisión-y-grupos)
8. [Cómo agregar contenido nuevo](#cómo-agregar-contenido-nuevo)
9. [Estado del proyecto y pendientes](#estado-del-proyecto-y-pendientes)
10. [Créditos y licencia](#créditos-y-licencia)

---

## Características

- Movimiento con caminar, salto, ataque y defensa con escudo.
- Animaciones: idle, walk, jump, attack, defend, hurt y death.
- Partículas de salto y aterrizaje, y sonido de pasos.
- Daño por caída desde gran altura y reaparición al caer al vacío.
- Sistema de vida con 3 corazones (6 puntos, medio corazón por punto) y HUD animado.
- Enemigos reutilizables con patrulla, persecución y ataque, y un enemigo lanzador de TNT.
- Monedas, popup "+N" al recogerlas y contador en el HUD.
- Vendedor con tienda: pociones, mejora de arma y mejora de escudo.
- Checkpoints con estandarte y efectos visuales.
- Plataformas móviles configurables (horizontal o vertical).
- Fondo con Parallax2D de nubes con autoscroll.
- Pelea contra un jefe final en una arena que limita la cámara y al jugador.
- Portal de fin de nivel y pantalla de resultados con puntaje.
- Menú principal con logo animado, opciones (volumen, pantalla completa) y cursor personalizado.

---

## Cómo ejecutarlo

1. Instalá **Godot 4.7** (versión estándar, no .NET).
2. Cloná el repositorio:
   ```bash
   git clone https://github.com/DevMatt24/GinnoQuest.git
   ```
3. Abrí Godot, elegí **Importar** y seleccioná el archivo `project.godot`.
4. Presioná **F5** para ejecutar. La escena principal es `main_menu.tscn`.

Para probar solo el nivel, abrí `nivel_1.tscn` y presioná **F6**.

---

## Controles

| Acción | Nombre en el Mapa de entrada | Tecla sugerida |
|---|---|---|
| Mover izquierda / derecha | `left` / `right` | A / D o flechas |
| Saltar | `jump` | Espacio |
| Atacar | `attack` | J (o la que hayas asignado) |
| Defender (mantener) | `defend` | K (o la que hayas asignado) |
| Interactuar con el vendedor | `interact` | E |
| Cerrar la tienda | `ui_cancel` | Escape |

Las teclas se cambian en **Proyecto > Configuración del proyecto > Mapa de entrada**. El script lee los nombres de las acciones, no las teclas.

---

## Estructura del proyecto

Las carpetas reales pueden variar un poco, esta es la organización usada:

```
res://
├── Script/        Scripts (.gd): player, enemy, boss, shop, hud, etc.
├── Scene/         Escenas (.tscn): nivel_1, enemy, enemy2, coin, hud, portal, etc.
├── Sprite/        Imágenes y spritesheets (UI, personajes, tiles, fondo)
├── Audio/         Música y efectos
└── Resources/     Recursos .tres (ShopItem, SpriteFrames)
```

### Escenas principales

| Escena | Nodo raíz | Función |
|---|---|---|
| `main_menu.tscn` | Node2D | Menú principal |
| `nivel_1.tscn` | Node2D | Nivel jugable |
| `player.tscn` | CharacterBody2D | Jugador |
| `enemy.tscn` | CharacterBody2D | Enemigo base |
| `enemy2.tscn` | CharacterBody2D | Enemigo lanzador de TNT |
| `tnt.tscn` | RigidBody2D | Proyectil explosivo |
| `boss.tscn` | CharacterBody2D | Dragón final |
| `coin.tscn` | Area2D | Moneda |
| `hud.tscn` | CanvasLayer | Corazones y contador de monedas |
| `shopkeeper.tscn` | Area2D | Vendedor con su tienda |
| `shop_ui.tscn` | CanvasLayer | Ventana de compras |
| `checkpoint.tscn` | Area2D | Estandarte de guardado |
| `moving_platform.tscn` | AnimatableBody2D | Plataforma móvil |
| `portal.tscn` | Area2D | Portal de fin de nivel |
| `level_complete.tscn` | CanvasLayer | Pantalla de resultados |
| `parallax.tscn` | Node2D | Fondo de nubes (varios `Parallax2D`) |

---

## Configuración del proyecto

- **Resolución:** 1152 × 648.
- **Filtro de texturas por defecto:** `Nearest`, para que el pixel art se vea nítido (Rendering > Textures).
- **Escena principal:** `main_menu.tscn`.
- **Buses de audio:** `Music` y `SFX`. Si no existen, los sliders usan `Master`.
- **Ajustes guardados:** volumen y pantalla completa se guardan en `user://settings.cfg`.

---

## Sistemas del juego

### Jugador (`player.gd`)

`CharacterBody2D` en el grupo `player`.

**Nodos hijos:** `AnimatedSprite2D`, `CollisionShape2D` (cápsula), `Camera2D`, `AttackArea` (Area2D), `WalkSound` (AudioStreamPlayer2D) y `Particles` con cuatro `CPUParticles2D` (salto y aterrizaje, izquierda y derecha).

**Constantes y valores:**

| Nombre | Valor | Uso |
|---|---|---|
| `SPEED` | 300 | Velocidad lateral |
| `JUMP_VELOCITY` | -430 | Fuerza del salto |
| `MAX_HEALTH` | 6 | Vida máxima (2 puntos por corazón) |
| `SAFE_FALL_SPEED` / `DEADLY_FALL_SPEED` | 650 / 1000 | Rango de velocidad para el daño por caída |
| `VOID_Y` | 800 | Altura a la que se considera caída al vacío |

**Señales:** `health_changed(current, maximum)`, `coins_changed(total)`, `shield_changed(current)`, `died`.

**Funciones principales:**

| Función | Qué hace |
|---|---|
| `_physics_process(delta)` | Gravedad, salto, ataque, defensa, movimiento, aterrizaje y animaciones |
| `_update_character(direction)` | Elige la animación (idle, walk, jump, hurt, attack, defend) y gira el sprite con `flip_h` |
| `take_damage(amount, source_x)` | Recibe daño con retroceso, parpadeo e invulnerabilidad de 1 s. Si está defendiendo y el golpe viene de frente, lo bloquea |
| `_attack()` | Activa `AttackArea` durante una ventana corta; `hit_bodies` evita golpear dos veces |
| `_block_hit()` / `_break_shield()` | Defensa: consume durabilidad del escudo y lo rompe al llegar a 0 |
| `_check_fall_damage(fall_speed)` | Daño de 1 a 3 según la velocidad de caída |
| `fall_into_void(damage)` | Resta vida, hace fundido y reaparece en `respawn_position` |
| `respawn()` | Reaparece vivo y con vida completa en el último checkpoint |
| `add_coins()` / `spend_coins()` | Monedas actuales y gastos; `coins_collected` acumula las recogidas para el puntaje |
| `heal()` | Cura vida |
| `upgrade_attack()` / `upgrade_shield()` | Mejoras compradas en la tienda |

**Defensa:** mantener `defend` en el suelo, con escudo disponible. El jugador queda quieto y solo bloquea golpes de frente. `shield` es la durabilidad (cada golpe bloqueado gasta 1) y `shield_defense` cuánto daño absorbe cada golpe.

**Límites horizontales:** la variable `bounds` (un `Rect2`) la asigna el nivel. Después de `move_and_slide()` se limita la posición X con `clampf`.

### Cámara (`Camera2D` hija del jugador)

- Sigue al jugador porque es su hija. Los límites son coordenadas globales.
- El script del nivel define `limit_left` y `limit_right` desde dos `Marker2D` (`LimitTopLeft` y `LimitBottomRight`). **No** se usan límites verticales, para que suba libre en plataformas altas.
- El jugador ajusta `offset.y` según suba o caiga y suaviza la altura con `lerpf`, para que el seguimiento vertical no sea brusco en saltos.
- En la pelea contra el jefe, el nivel guarda los límites actuales, los reemplaza por los de la arena con una transición suave y los restaura al terminar.

### Fondo Parallax

- Escena con varios nodos `Parallax2D`, cada uno con un `Sprite2D` de nubes (`Centered` apagado).
- Para nubes que no reaccionan a la cámara: `Ignore Camera Scroll` activado y solo `Autoscroll` (por ejemplo `(-3, 0)` a `(-15, 0)`, más rápido en capas cercanas).
- `Repeat Size` igual al ancho de la imagen por su escala, y `Repeat Times` entre 3 y 4, para que la repetición no deje huecos.
- Se instancia como primer hijo del nivel para que se dibuje detrás de todo.

### Enemigos (`enemy.gd`)

Una sola escena y un solo script sirven para todos los enemigos comunes. Cada instancia se personaliza desde el Inspector.

**Nodos:** `AnimatedSprite2D`, `CollisionShape2D`, `FloorRay` (RayCast2D para detectar bordes), `DamageArea` (Area2D).

**Animaciones requeridas:** `idle`, `walk`, `attack1` y `dead`.

**Variables exportadas:** `frames` (SpriteFrames), `faces_right`, `speed`, `chase_speed`, `max_health`, `attack_damage`, `attack_cooldown`, `attack_hit_point`, `coin_scene`, `coin_value`, `coin_scale`, `drop_chance`.

**Comportamiento:**

1. Patrulla y gira al chocar con una pared o al llegar a un borde.
2. Si el jugador entra en `DETECT_RANGE`, se da vuelta, lo persigue y se frena a `STOP_DISTANCE`.
3. Ataca con `attack1`; el daño cae a mitad de la animación y solo si el jugador sigue en el área y está al frente.
4. Al recibir daño retrocede, destella en rojo y puede interrumpirse el ataque.
5. Al morir reproduce `dead`, suelta una moneda, emite la señal `died` y se desvanece.

Cambiar el aspecto de un enemigo es asignar otro `SpriteFrames` con los mismos nombres de animación.

### Enemigo lanzador de TNT (`enemy2.gd`)

Con `class_name Thrower`, extiende `Enemy` (definido con `class_name Enemy` en `enemy.gd`). Sobrescribe la detección y la persecución: se planta a distancia y lanza TNT con un tiro parabólico calculado para caer cerca del jugador.

Variables: `tnt_scene`, `throw_range`, `flight_time`, `throw_offset`.

### TNT (`tnt.gd`)

`RigidBody2D` con mecha. Explota tras `fuse_time` y daña a todo lo que esté en `BlastArea`: 2 al jugador y 3 a enemigos. Tiene `take_damage()`, así que el ataque del jugador la desvía en dirección contraria, y si cae sobre un enemigo, lo daña. Además tiene un `HitArea` más grande para que sea más fácil golpearla.

### Jefe final: el dragón (`boss.gd`)

- **Animaciones:** `idle`, `walk`, `roar`, `atacar`, `hurt` y `dead`.
- `activate()` lo despierta con un rugido; durante ese rugido no recibe daño.
- Persigue al jugador y ataca cuando este entra en su `AttackArea` (Area2D espejada junto al sprite en `_apply_flip()`).
- Emite `health_changed` (para la barra de vida) y `died`.
- `reset()` lo devuelve a su posición inicial con la vida completa si el jugador muere durante la pelea.
- Al morir suelta una moneda de valor alto.

### Arena del jefe y fin de nivel (script del nivel)

| Nodo | Función |
|---|---|
| `BossTrigger` (Area2D) | Al entrar el jugador se cierra la arena |
| `ArenaTopLeft` / `ArenaBottomRight` (Marker2D) | Definen el rectángulo de la pelea |
| `Boss` | Instancia del dragón |
| `Portal` | Aparece cuando murió el jefe y todos los enemigos |
| `LevelComplete` | Pantalla de resultados |

Flujo: entrar al trigger, bloquear cámara y jugador, jefe ruge y pelea, jefe muere y se abre la arena, se matan los enemigos restantes, aparece el portal, se entra y se muestra el resumen.

**Puntaje:** `enemigos derrotados × 100 + monedas recogidas × 10` (editable en `level_complete.gd`).

### HUD (`hud.gd`)

`CanvasLayer` con 3 corazones, cada uno un `AnimatedSprite2D` dentro de un slot con un fondo. Cada corazón tiene estados `full`, `half` y `empty`, con animaciones de transición `lose_half` y `lose_last`. Se actualiza con `update_health(current, maximum)` y `update_coins(total)`, conectadas a las señales del jugador desde el script del nivel. El contador de monedas hace un pequeño rebote al sumar.

### Monedas (`coin.gd`)

`Area2D` con animación `spin`. Al tocarla el jugador suma `value`, muestra un popup "+N" creado por código (sobrevive a `queue_free()` porque se agrega al nodo padre), suena y desaparece. Los enemigos y el jefe instancian monedas con un valor y una escala propios.

### Tienda y vendedor

| Archivo | Función |
|---|---|
| `shop_item.gd` | Recurso `ShopItem`: nombre, descripción, tipo (`HEAL`, `WEAPON_UPGRADE`, `SHIELD_UPGRADE`), valor, precio, aumento de precio por nivel, nivel máximo e icono |
| `shopkeeper.gd` | `Area2D` del NPC. Muestra el cartel "[E] Interactuar" sobre el jugador y abre la tienda |
| `shop_ui.gd` | Ventana con tarjetas por producto, precio, estado (bloqueado, vida llena, máximo, faltan monedas), animaciones y botón de cerrar |

Al abrir la tienda se congelan solo la física y el movimiento del jugador. Cada producto se define como un archivo `.tres` y se asigna al array **Items** de la instancia del vendedor en el nivel.

Precios sugeridos: poción pequeña 5, poción grande 9, elixir 20, afilar espada 20 / 35 / 50 (escalonado con `price_step`).

### Checkpoint (`checkpoint.gd`)

`Area2D` con un estandarte de una sola animación. Apagado (gris y quieto) hasta que el jugador lo toca. Al activarse guarda `respawn_position`, destella, rebota, lanza un anillo de luz y chispas, muestra "¡Punto guardado!" y queda ondeando con un brillo suave. El último checkpoint activado es el que vale.

### Plataforma móvil (`moving_platform.gd`)

`AnimatableBody2D` con script `@tool`. Se configura desde el Inspector:

- `direction`: horizontal o vertical.
- `distance`, `speed`, `wait_time`, `smooth`, `start_reversed`.
- El editor dibuja una línea amarilla con el recorrido.

Usa un `Tween` en modo física, así el jugador viaja sobre ella sin código extra.

### Daño de caída y vacío

- Al aterrizar, se compara la velocidad vertical guardada antes de `move_and_slide()` con `SAFE_FALL_SPEED` y `DEADLY_FALL_SPEED`.
- Si el jugador pasa `VOID_Y` se llama a `fall_into_void()`, que resta 1 de vida y lo devuelve al último checkpoint o al inicio.

### Menú principal (`main_menu.gd`)

- Reutiliza el fondo parallax y muestra al héroe en idle sobre una isla; cada 4 a 7 s hace un ataque.
- Logo animado que cae desde arriba y luego flota.
- Botones **Jugar**, **Opciones** y **Salir**. Los botones usan un banner (`StyleBoxTexture`) con efectos de hover y de clic, y entrada en cascada.
- Panel de opciones con volumen de música, volumen de efectos y pantalla completa; se guardan en `user://settings.cfg`.
- Cursor personalizado con `Input.set_custom_mouse_cursor`. En el nivel el cursor se oculta con `Input.mouse_mode = MOUSE_MODE_HIDDEN` y se muestra en la tienda y en los menús.
- Transición con fundido al comenzar el juego.

---

## Capas de colisión y grupos

| Nodo | Layer | Mask |
|---|---|---|
| Plataformas y tiles | 1 | |
| Player | 2 | 1 |
| Enemy y Boss | 3 | 1 |
| Tnt (RigidBody2D) | 3 | 1 |
| Enemy / Boss > DamageArea / AttackArea | ninguna | 2 |
| Player > AttackArea | ninguna | 3 |
| Tnt > BlastArea | ninguna | 2 y 3 |
| Coin, Shopkeeper, Checkpoint, Portal, BossTrigger, KillZone | ninguna | 2 |

**Grupos:** `player` (jugador) y `enemy` (todos los enemigos y el jefe, usado para contar los derrotados).

---

## Cómo agregar contenido nuevo

**Nuevo tipo de enemigo:** instanciá `enemy.tscn`, creá un `SpriteFrames` con las animaciones `idle`, `walk`, `attack1` y `dead` y asignalo en **Frames**. Ajustá vida, velocidad y daño en el Inspector. Si el sprite mira a la izquierda, desactivá `Faces Right`.

**Nuevo producto en la tienda:** clic derecho en el FileSystem > Nuevo recurso > `ShopItem`. Completá los campos, guardalo como `.tres` y arrastralo al array **Items** del vendedor.

**Nuevo nivel:** copiá `nivel_1.tscn`, movés los marcadores de límites, colocás el `SpawnPoint` y el `KillZone` y asignás **Next Level** en la pantalla de resultados.

**Nuevo checkpoint:** instanciá `checkpoint.tscn` con su origen sobre el suelo.

---

## Estado del proyecto y pendientes

**Hecho**

- Movimiento, ataque, defensa, daño y muerte del jugador
- HUD de vida y de monedas
- Enemigo base y enemigo lanzador de TNT
- Monedas, tienda y mejoras
- Checkpoints y reaparición
- Plataformas móviles
- Parallax de nubes
- Menú principal y opciones
- Jefe final, arena, portal y pantalla de resultados

**Pendiente o ideas**

- Autoload `GameState` para conservar monedas, escudo y mejoras entre niveles
- Menú de pausa dentro del juego
- Pantalla de Game Over
- Más niveles y más tipos de enemigos
- Música de fondo y más efectos de sonido
- Sistema de puntuaciones guardadas
- Reiniciar enemigos y monedas al reaparecer

---

## Créditos y licencia

- **Autor:** Matias Muñoz, Lara Camacho, Marina Barranco, Angeles Tramaleo
- **Motor:** [Godot Engine](https://godotengine.org/) (licencia MIT)

