# Registro de cambios

Cada versión con sus novedades (✨), cambios (🔧) y correcciones (🐛).
Numeración `0.X.Y` mientras esté en desarrollo: sube **Y** para correcciones y **X** para novedades.

## [0.5.1] - 2026-11-10

### ✨ Novedades
- **Un solo archivo para descargar**: el servidor de salas va dentro del instalador (carpeta `servidor` de la instalación). Ya no hay `ExtremeFighters_Servidor.zip` aparte.
- **Online → Abrir servidor público en este PC**: abre 6 salas públicas mientras el juego está abierto, abre el router solo (UPnP) y muestra la dirección para compartir. Usa los puertos 24880-24886 para no chocar con la sala propia.

## [0.5.0] - 2026-11-10

### 🐛 Correcciones
- **L2/R2 fallaban a veces**: ahora cada pulsación hace un **toque corto** (0,1 s) sobre la carta, como un dedo, aunque se mantenga el gatillo.

### ✨ Novedades
- **Dos esquemas de control** para cambiar de personaje / llamar strikers:
  - *Gatillos*: L2 = 2.ª carta, R2 = 3.ª, L2 + R2 a la vez = 4.ª.
  - *L2 + botón*: R2 = 2.ª carta; con L2 mantenido, los botones izquierda/arriba/derecha/abajo = 2.ª a 5.ª carta.
- **Ajustar la posición de cada carta** (hasta la 5.ª) haciendo clic sobre ella en la pantalla inferior.
- **Importar partida guardada** (*Opciones → Partidas guardadas*): para tener todo desbloqueado con una partida al 100 %. Copia de seguridad automática de la partida actual.

## [0.4.0] - 2026-11-09

### ✨ Novedades
- **Actualizaciones automáticas**:
  - El instalador consulta GitHub al abrirse y muestra **ACTUALIZAR A vX.X.X** si hay versión nueva.
  - En el juego (menú de pausa): **Buscar actualizaciones** y **Actualizar a vX.X.X**; también se comprueba al arrancar y avisa.
  - Descarga la versión nueva, conserva partidas, configuración y juego recompilado, y vuelve a abrir el juego.
- **Crear sala online** con **apertura automática del router (UPnP)** y **código de sala** (`EF-XXXXX-XXXXX`) para compartir. Conexión directa entre jugadores.
- **Unirse con código**: el campo de dirección acepta códigos de sala.
- **Aviso de CG-NAT**: si la conexión no puede recibir jugadores, el juego lo detecta y lo explica.
- **Ping** de cada sala en la lista de salas públicas, ordenada de la más cercana a la más lejana.

### 🔧 Cambios
- El servidor de salas (`ExtremeFighters_Servidor.zip`) pasa a ser opcional: solo para salas abiertas 24/7.

## [0.3.0] - 2026-11-09

### ✨ Novedades
- **Pantalla superior completa**: la pantalla principal ocupa todo el alto del monitor y la inferior va pequeña encima, en una esquina. Tamaño (15-45 %) y lado ajustables en *Opciones → Gráficos*. **F10** la muestra u oculta. Es la disposición por defecto.
- **Calidad gráfica por niveles** en *Opciones → Gráficos*: Rendimiento (2x), Equilibrada (3x), Alta (4x), Ultra (6x).
- El instalador **elige la calidad según la tarjeta gráfica** (4x dedicadas modernas, 3x dedicadas, 2x integradas), sin cambiar la que haya elegido el jugador.
- **Salas públicas** en *Online*: lista de salas de un servidor de Extreme Fighters para unirse con un clic.
- **Servidor de salas** (`ef-servidor`, Windows y Linux): mantiene varias salas abiertas y publica su lista. Solo el servidor necesita abrir puertos.

### 🔧 Cambios
- La disposición de pantallas pasa a ser un ajuste general (antes era propia del juego), para que *Opciones → Gráficos → Pantallas* la cambie directamente.

## [0.2.1] - 2026-11-09

### 🐛 Correcciones
- Mandos que envían los dos gatillos igual (por ejemplo algunos 8BitDo): L2 y R2 llevaban al mismo personaje. Ahora los controles de las cartas se **aprenden del propio mando** (código físico y sentido de cada gatillo), así que cada gatillo lleva a su personaje.

### ✨ Novedades
- *Opciones → Controles de combate*: haz clic en "2.º personaje" o "3.º personaje" y aprieta el gatillo que quieras; un **indicador en directo** muestra cuándo se detecta cada uno.
- Aviso automático si un mando no permite distinguir los gatillos, con instrucciones para pasarlo a modo X-input.

## [0.2.0] - 2026-11-09
Primera versión pública.

### ✨ Novedades
- Port nativo de *Dragon Ball Z: Extreme Butoden* con código recompilado por 3dsrecomp.
- Zakuro edición DBZ (basado en Zakuro v0.2.32):
  - L2 / R2 tocan la carta del 2.º / 3.º personaje (cambiar de personaje o llamar al striker), reasignables.
  - Menú de pausa y opciones con estilo propio, simplificados y traducidos a 7 idiomas.
  - Apartado Online (salas por internet, sin rollback).
- Pantalla superior grande e inferior pequeña, y pantalla completa de serie.
- El juego arranca en el idioma elegido en el instalador.
- Instalador todo en uno en 7 idiomas: solo pide el `.3ds` y comprueba que esté descifrado.
- Instalación 100 % portátil en la carpeta que elijas (AppData, caché de gráficos y partidas incluidas).
- Icono pixel art de la bola de dragón de 4 estrellas.

<!-- Plantilla para la siguiente versión:
## [0.2.1] - AAAA-MM-DD
### 🐛 Correcciones
- ...
-->
