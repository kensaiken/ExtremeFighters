# Extreme Fighters: instalador todo-en-uno del port nativo de Dragon Ball Z: Extreme Butoden (3DS)
# Solo pide el .3ds. Lleva 3dsrecomp ya compilado (bin\3dsrecomp.exe), descarga
# Zakuro (motor que ejecuta el codigo recompilado) y Zig (compilador de C
# portable), recompila el juego a codigo nativo y crea los accesos directos.
# Todo se guarda en DBZ_Datos, junto al instalador.

# -AutoUpdate: actualiza solo la instalacion de -Destino (lo usa actualizar.ps1)
# -Jugar: abre el juego al terminar
param([switch]$AutoUpdate, [string]$Destino = '', [switch]$Jugar)

$ErrorActionPreference = 'Stop'
$AppVersion = '0.5.1'   # version de Extreme Fighters
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Native -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Native.Dpi]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------- versiones
# Zakuro edicion DBZ (v0.2.32 modificado: menu traducido y con estilo propio,
# gatillos para las cartas de personaje, Online). Va en bin\zakuro.exe y usa
# exactamente el 3dsrecomp df82e6e3 que va en bin\
$ZakuroVersion = 'v0.2.32-dbz6'
$ZigVersion    = '0.17.0'
$ZigFile       = "zig-x86_64-windows-$ZigVersion.zip"
$ZigSize       = 100268137
$ZigSha256     = 'b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428'

$Here      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Recomp    = Join-Path $Here 'bin\3dsrecomp.exe'
$ZakuroSrc = Join-Path $Here 'bin\zakuro.exe'
$Assets    = Join-Path $Here 'assets'
$PlaySrc   = Join-Path $Here 'bin\Jugar.exe'
$LangFile  = Join-Path $Here 'idioma.txt'
$DestFile  = Join-Path $Here 'destino.txt'

# Todo (juego, motor, partidas, compilador, appdata, cache de graficos...)
# va dentro de la carpeta de instalacion elegida. 100% portatil.
function Set-InstDir([string]$dir) {
    $script:InstDir   = $dir
    $script:ZakuroDir = [IO.Path]::Combine($dir, 'zakuro')
    $script:ZakuroExe = [IO.Path]::Combine($dir, 'zakuro\zakuro.exe')
    $script:GameDir   = [IO.Path]::Combine($dir, 'juego')
    $script:NativeDir = [IO.Path]::Combine($dir, 'nativo')
    $script:SaveDir   = [IO.Path]::Combine($dir, 'partidas')
    $script:BuildDir  = [IO.Path]::Combine($dir, 'compilacion')
    $script:LogDir    = [IO.Path]::Combine($dir, 'logs')
    $script:TmpDir    = [IO.Path]::Combine($dir, 'descargas')
    $script:ToolsDir  = [IO.Path]::Combine($dir, 'tools')
    $script:ZigCache  = [IO.Path]::Combine($dir, 'tools\zig-cache')
    $script:ZigDir    = [IO.Path]::Combine($dir, "tools\zig-$ZigVersion")
    $script:ZigExe    = [IO.Path]::Combine($dir, "tools\zig-$ZigVersion\zig.exe")
    $script:AppRoam   = [IO.Path]::Combine($dir, 'appdata\Roaming')
    $script:AppLocal  = [IO.Path]::Combine($dir, 'appdata\Local')
    $script:AppTemp   = [IO.Path]::Combine($dir, 'appdata\Temp')
    $script:PlayExe   = [IO.Path]::Combine($dir, 'Jugar.exe')
    $script:PlayIni   = [IO.Path]::Combine($dir, 'jugar.ini')
}
# carpeta elegida -> carpeta real: si ya es nuestra o esta vacia se usa tal cual,
# si no se crea dentro una subcarpeta para no mezclar archivos
function Resolve-Dest([string]$picked) {
    if (-not (Test-Path $picked)) { return $picked }
    if ((Test-Path (Join-Path $picked 'jugar.ini')) -or (Test-Path (Join-Path $picked 'zakuro'))) { return $picked }
    if (@(Get-ChildItem -LiteralPath $picked -Force -ErrorAction SilentlyContinue).Count -eq 0) { return $picked }
    return [IO.Path]::Combine($picked, 'ExtremeFighters')
}
function Test-Writable([string]$dir) {
    try {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $probe = Join-Path $dir 'prueba_escritura.tmp'
        Set-Content -Path $probe -Value 'ok'; Remove-Item $probe -Force
        return $true
    } catch { return $false }
}
# calidad grafica por defecto segun la tarjeta grafica: 4x dedicadas modernas,
# 3x dedicadas antiguas, 2x integradas
function Detect-Quality {
    try { $names = (Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join ' | ' } catch { return 3 }
    Log "Tarjeta grafica: $names"
    if ($names -match 'RTX|Radeon RX [5-9]\d{3}|RX [67]\d{3}|Arc A\d') { return 4 }
    if ($names -match 'GTX|Radeon RX|Radeon Pro|Quadro|FirePro') { return 3 }
    if ($names -match 'Intel|Radeon\(TM\) Graphics|Vega \d') { return 2 }
    return 3
}
function Free-GB([string]$dir) {
    try {
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($dir))
        return [Math]::Round((New-Object System.IO.DriveInfo($root)).AvailableFreeSpace / 1GB, 1)
    } catch { return -1 }
}
$dest = Join-Path $Here 'ExtremeFighters'
try { if (Test-Path $DestFile) { $d = (Get-Content $DestFile -Raw).Trim(); if ($d -and (Test-Path ([IO.Path]::GetPathRoot($d)))) { $dest = $d } } } catch {}
Set-InstDir $dest
if ($Destino) { Set-InstDir $Destino }
$GameName  = 'Extreme Fighters'

# ---------------------------------------------------------------- idiomas
$Langs = @(
    @{ id = 'es'; name = 'Español' }, @{ id = 'en'; name = 'English' }, @{ id = 'fr'; name = 'Français' },
    @{ id = 'de'; name = 'Deutsch' }, @{ id = 'it'; name = 'Italiano' }, @{ id = 'ja'; name = '日本語' },
    @{ id = 'zh'; name = '中文' }
)
$script:Strings = @'
{
"es": {
 "upd_btn": "ACTUALIZAR A v{0}", "upd_ok": "v{0} · última versión", "upd_check": "v{0} · buscando actualizaciones…", "upd_auto": "Actualizando a la última versión…",
 "dest": "Carpeta de instalación (todo se guarda aquí)", "free": "Libre: {0} GB", "pickdest": "Elige dónde instalar el juego. Todo (juego, partidas, configuración y caché de gráficos) quedará dentro de esa carpeta.", "nospace": "No hay espacio suficiente en la carpeta elegida: hacen falta unos {0} GB.", "nowrite2": "No se puede escribir en esa carpeta. Elige otra.",
 "lang": "Idioma",
 "win": "Extreme Fighters - Instalador",
 "p1": "1. Selecciona tu juego de 3DS", "ph": "Selecciona el archivo del juego (.3ds)...", "p2": "2. Comprobaciones",
 "cc": "Compilador de C (Zig)", "sys": "Sistema", "found": "Encontrado", "dl": "Se descargará", "bad": "No compatible",
 "inst1": "INSTALAR /", "inst2": "RECOMPILAR", "play": "JUGAR", "quit": "SALIR",
 "infoT": "Información", "info": "Recompilación nativa de Dragon Ball Z: Extreme Butoden para PC.\n¡Disfruta del juego con un rendimiento mejorado!",
 "prog": "Progreso de instalación", "wait": "Esperando para comenzar...",
 "romok": "Juego válido: {0} (descifrado)", "romenc": "Esta ROM está cifrada. Necesitas un .3ds descifrado de tu cartucho.",
 "rombad": "No es una ROM de 3DS válida (.3ds/.cci/.cxi).", "pick": "Selecciona tu copia de Dragon Ball Z: Extreme Butoden",
 "s1": "Preparando carpetas", "s2": "Instalando Zakuro (edición DBZ)", "incl": "Incluido (edición DBZ)", "s3": "Descargando el compilador (Zig, ~100 MB)", "s4": "Descomprimiendo el compilador",
 "s5": "Copiando el juego", "s6": "Recompilando a código nativo (10-20 min)", "s7": "Creando accesos directos",
 "gen": "generando código C...", "files": "{0} de {1} archivos", "retry": "reintentando...",
 "done": "¡Instalación terminada! A jugar.",
 "donemsg": "¡Instalado!\n\nAbre el juego con el acceso directo del escritorio o con Jugar.exe (en la carpeta de instalación).\nEn el juego, Esc abre el menú (controles, gráficos, sonido).",
 "errmsg": "Ha ocurrido un error. Registros en:", "cancel": "La instalación sigue en marcha. ¿Cancelar y salir?",
 "nowrite": "No puedo escribir en la carpeta del instalador. Muévela (por ejemplo al Escritorio) y vuelve a abrirlo.",
 "oldwin": "Hace falta Windows 10 (1803) o posterior.", "installed": "Ya instalado: pulsa JUGAR",
 "errdl": "No se pudo descargar {0}.", "errzip": "No se pudo descomprimir {0}.", "errcopy": "No se pudo copiar el juego (¿disco lleno?).",
 "errrecomp": "La recompilación falló.", "fail": "Error: revisa el mensaje"
},
"en": {
 "upd_btn": "UPDATE TO v{0}", "upd_ok": "v{0} · latest version", "upd_check": "v{0} · checking for updates…", "upd_auto": "Updating to the latest version…",
 "dest": "Install folder (everything is stored here)", "free": "Free: {0} GB", "pickdest": "Choose where to install the game. Everything (game, saves, settings and graphics cache) will stay inside that folder.", "nospace": "Not enough free space in the chosen folder: about {0} GB are needed.", "nowrite2": "That folder can't be written to. Choose another one.",
 "lang": "Language",
 "win": "Extreme Fighters - Installer",
 "p1": "1. Select your 3DS game", "ph": "Select the game file (.3ds)...", "p2": "2. Checks",
 "cc": "C compiler (Zig)", "sys": "System", "found": "Found", "dl": "Will be downloaded", "bad": "Not supported",
 "inst1": "INSTALL /", "inst2": "RECOMPILE", "play": "PLAY", "quit": "EXIT",
 "infoT": "Information", "info": "Native recompilation of Dragon Ball Z: Extreme Butoden for PC.\nEnjoy the game with improved performance!",
 "prog": "Installation progress", "wait": "Waiting to start...",
 "romok": "Valid game: {0} (decrypted)", "romenc": "This ROM is encrypted. You need a decrypted .3ds dumped from your cartridge.",
 "rombad": "This is not a valid 3DS ROM (.3ds/.cci/.cxi).", "pick": "Select your copy of Dragon Ball Z: Extreme Butoden",
 "s1": "Preparing folders", "s2": "Installing Zakuro (DBZ edition)", "incl": "Included (DBZ edition)", "s3": "Downloading the compiler (Zig, ~100 MB)", "s4": "Unpacking the compiler",
 "s5": "Copying the game", "s6": "Recompiling to native code (10-20 min)", "s7": "Creating shortcuts",
 "gen": "generating C code...", "files": "{0} of {1} files", "retry": "retrying...",
 "done": "Installation complete! Have fun.",
 "donemsg": "Installed!\n\nStart the game with the desktop shortcut or Jugar.exe (in the install folder).\nIn game, Esc opens the menu (controls, graphics, sound).",
 "errmsg": "Something went wrong. Logs are in:", "cancel": "The installation is still running. Cancel and exit?",
 "nowrite": "I can't write to the installer's folder. Move it (for example to the Desktop) and open it again.",
 "oldwin": "Windows 10 (1803) or newer is required.", "installed": "Already installed: press PLAY",
 "errdl": "Could not download {0}.", "errzip": "Could not unpack {0}.", "errcopy": "Could not copy the game (is the disk full?).",
 "errrecomp": "Recompilation failed.", "fail": "Error: see the message"
},
"fr": {
 "upd_btn": "METTRE À JOUR v{0}", "upd_ok": "v{0} · dernière version", "upd_check": "v{0} · recherche de mises à jour…", "upd_auto": "Mise à jour vers la dernière version…",
 "dest": "Dossier d'installation (tout est enregistré ici)", "free": "Libre : {0} Go", "pickdest": "Choisissez où installer le jeu. Tout (jeu, sauvegardes, réglages et cache graphique) restera dans ce dossier.", "nospace": "Espace insuffisant dans le dossier choisi : il faut environ {0} Go.", "nowrite2": "Impossible d'écrire dans ce dossier. Choisissez-en un autre.",
 "lang": "Langue",
 "win": "Extreme Fighters - Installateur",
 "p1": "1. Sélectionnez votre jeu 3DS", "ph": "Sélectionnez le fichier du jeu (.3ds)...", "p2": "2. Vérifications",
 "cc": "Compilateur C (Zig)", "sys": "Système", "found": "Trouvé", "dl": "Sera téléchargé", "bad": "Non compatible",
 "inst1": "INSTALLER /", "inst2": "RECOMPILER", "play": "JOUER", "quit": "QUITTER",
 "infoT": "Informations", "info": "Recompilation native de Dragon Ball Z: Extreme Butoden pour PC.\nProfitez du jeu avec des performances améliorées !",
 "prog": "Progression de l'installation", "wait": "En attente...",
 "romok": "Jeu valide : {0} (déchiffré)", "romenc": "Cette ROM est chiffrée. Il vous faut un .3ds déchiffré de votre cartouche.",
 "rombad": "Ce n'est pas une ROM 3DS valide (.3ds/.cci/.cxi).", "pick": "Sélectionnez votre copie de Dragon Ball Z: Extreme Butoden",
 "s1": "Préparation des dossiers", "s2": "Installation de Zakuro (édition DBZ)", "incl": "Inclus (édition DBZ)", "s3": "Téléchargement du compilateur (Zig, ~100 Mo)", "s4": "Décompression du compilateur",
 "s5": "Copie du jeu", "s6": "Recompilation en code natif (10-20 min)", "s7": "Création des raccourcis",
 "gen": "génération du code C...", "files": "{0} sur {1} fichiers", "retry": "nouvel essai...",
 "done": "Installation terminée ! Bon jeu.",
 "donemsg": "Installé !\n\nLancez le jeu avec le raccourci du Bureau ou Jugar.exe.\nEn jeu, Échap ouvre le menu (commandes, graphismes, son).",
 "errmsg": "Une erreur s'est produite. Journaux dans :", "cancel": "L'installation est en cours. Annuler et quitter ?",
 "nowrite": "Impossible d'écrire dans le dossier de l'installateur. Déplacez-le (par exemple sur le Bureau) et relancez-le.",
 "oldwin": "Windows 10 (1803) ou plus récent est requis.", "installed": "Déjà installé : appuyez sur JOUER",
 "errdl": "Impossible de télécharger {0}.", "errzip": "Impossible de décompresser {0}.", "errcopy": "Impossible de copier le jeu (disque plein ?).",
 "errrecomp": "La recompilation a échoué.", "fail": "Erreur : voir le message"
},
"de": {
 "upd_btn": "AKTUALISIEREN v{0}", "upd_ok": "v{0} · neueste Version", "upd_check": "v{0} · suche nach Updates…", "upd_auto": "Aktualisierung auf die neueste Version…",
 "dest": "Installationsordner (alles wird hier gespeichert)", "free": "Frei: {0} GB", "pickdest": "Wähle, wo das Spiel installiert wird. Alles (Spiel, Spielstände, Einstellungen und Grafik-Cache) bleibt in diesem Ordner.", "nospace": "Nicht genug freier Speicher im gewählten Ordner: etwa {0} GB werden benötigt.", "nowrite2": "In diesen Ordner kann nicht geschrieben werden. Wähle einen anderen.",
 "lang": "Sprache",
 "win": "Extreme Fighters - Installation",
 "p1": "1. Wähle dein 3DS-Spiel", "ph": "Spieldatei auswählen (.3ds)...", "p2": "2. Prüfungen",
 "cc": "C-Compiler (Zig)", "sys": "System", "found": "Gefunden", "dl": "Wird heruntergeladen", "bad": "Nicht unterstützt",
 "inst1": "INSTALLIEREN /", "inst2": "REKOMPILIEREN", "play": "SPIELEN", "quit": "BEENDEN",
 "infoT": "Information", "info": "Native Rekompilierung von Dragon Ball Z: Extreme Butoden für PC.\nGenieße das Spiel mit verbesserter Leistung!",
 "prog": "Installationsfortschritt", "wait": "Warte auf Start...",
 "romok": "Gültiges Spiel: {0} (entschlüsselt)", "romenc": "Dieses ROM ist verschlüsselt. Du brauchst eine entschlüsselte .3ds deines Moduls.",
 "rombad": "Kein gültiges 3DS-ROM (.3ds/.cci/.cxi).", "pick": "Wähle deine Kopie von Dragon Ball Z: Extreme Butoden",
 "s1": "Ordner werden vorbereitet", "s2": "Zakuro wird installiert (DBZ-Edition)", "incl": "Enthalten (DBZ-Edition)", "s3": "Compiler wird heruntergeladen (Zig, ~100 MB)", "s4": "Compiler wird entpackt",
 "s5": "Spiel wird kopiert", "s6": "Rekompilierung in nativen Code (10-20 Min.)", "s7": "Verknüpfungen werden erstellt",
 "gen": "C-Code wird erzeugt...", "files": "{0} von {1} Dateien", "retry": "neuer Versuch...",
 "done": "Installation abgeschlossen! Viel Spaß.",
 "donemsg": "Installiert!\n\nStarte das Spiel über die Desktop-Verknüpfung oder Jugar.exe.\nIm Spiel öffnet Esc das Menü (Steuerung, Grafik, Ton).",
 "errmsg": "Ein Fehler ist aufgetreten. Protokolle in:", "cancel": "Die Installation läuft noch. Abbrechen und beenden?",
 "nowrite": "Ich kann nicht in den Ordner der Installation schreiben. Verschiebe ihn (z. B. auf den Desktop) und starte erneut.",
 "oldwin": "Windows 10 (1803) oder neuer wird benötigt.", "installed": "Bereits installiert: drücke SPIELEN",
 "errdl": "{0} konnte nicht heruntergeladen werden.", "errzip": "{0} konnte nicht entpackt werden.", "errcopy": "Das Spiel konnte nicht kopiert werden (Festplatte voll?).",
 "errrecomp": "Die Rekompilierung ist fehlgeschlagen.", "fail": "Fehler: siehe Meldung"
},
"it": {
 "upd_btn": "AGGIORNA A v{0}", "upd_ok": "v{0} · ultima versione", "upd_check": "v{0} · ricerca aggiornamenti…", "upd_auto": "Aggiornamento all'ultima versione…",
 "dest": "Cartella di installazione (tutto viene salvato qui)", "free": "Libero: {0} GB", "pickdest": "Scegli dove installare il gioco. Tutto (gioco, salvataggi, impostazioni e cache grafica) resterà in quella cartella.", "nospace": "Spazio insufficiente nella cartella scelta: servono circa {0} GB.", "nowrite2": "Impossibile scrivere in quella cartella. Scegline un'altra.",
 "lang": "Lingua",
 "win": "Extreme Fighters - Installazione",
 "p1": "1. Seleziona il tuo gioco 3DS", "ph": "Seleziona il file del gioco (.3ds)...", "p2": "2. Controlli",
 "cc": "Compilatore C (Zig)", "sys": "Sistema", "found": "Trovato", "dl": "Verrà scaricato", "bad": "Non supportato",
 "inst1": "INSTALLA /", "inst2": "RICOMPILA", "play": "GIOCA", "quit": "ESCI",
 "infoT": "Informazioni", "info": "Ricompilazione nativa di Dragon Ball Z: Extreme Butoden per PC.\nGoditi il gioco con prestazioni migliorate!",
 "prog": "Avanzamento installazione", "wait": "In attesa di iniziare...",
 "romok": "Gioco valido: {0} (decrittato)", "romenc": "Questa ROM è criptata. Ti serve un .3ds decrittato dalla tua cartuccia.",
 "rombad": "Non è una ROM 3DS valida (.3ds/.cci/.cxi).", "pick": "Seleziona la tua copia di Dragon Ball Z: Extreme Butoden",
 "s1": "Preparazione delle cartelle", "s2": "Installazione di Zakuro (edizione DBZ)", "incl": "Incluso (edizione DBZ)", "s3": "Download del compilatore (Zig, ~100 MB)", "s4": "Estrazione del compilatore",
 "s5": "Copia del gioco", "s6": "Ricompilazione in codice nativo (10-20 min)", "s7": "Creazione dei collegamenti",
 "gen": "generazione del codice C...", "files": "{0} di {1} file", "retry": "nuovo tentativo...",
 "done": "Installazione completata! Buon divertimento.",
 "donemsg": "Installato!\n\nAvvia il gioco dal collegamento sul desktop o con Jugar.exe.\nNel gioco, Esc apre il menu (comandi, grafica, audio).",
 "errmsg": "Si è verificato un errore. Log in:", "cancel": "L'installazione è ancora in corso. Annullare e uscire?",
 "nowrite": "Non posso scrivere nella cartella dell'installazione. Spostala (ad esempio sul Desktop) e riaprila.",
 "oldwin": "È richiesto Windows 10 (1803) o successivo.", "installed": "Già installato: premi GIOCA",
 "errdl": "Impossibile scaricare {0}.", "errzip": "Impossibile estrarre {0}.", "errcopy": "Impossibile copiare il gioco (disco pieno?).",
 "errrecomp": "La ricompilazione non è riuscita.", "fail": "Errore: vedi il messaggio"
},
"ja": {
 "upd_btn": "v{0} に更新", "upd_ok": "v{0} · 最新版", "upd_check": "v{0} · アップデートを確認中…", "upd_auto": "最新バージョンに更新中…",
 "dest": "インストール先フォルダー（すべてここに保存）", "free": "空き: {0} GB", "pickdest": "ゲームのインストール先を選んでください。ゲーム・セーブ・設定・グラフィックキャッシュはすべてそのフォルダー内に保存されます。", "nospace": "選択したフォルダーの空き容量が足りません。約 {0} GB 必要です。", "nowrite2": "そのフォルダーには書き込めません。別のフォルダーを選んでください。",
 "lang": "言語",
 "win": "Extreme Fighters - インストーラー",
 "p1": "1. 3DSのゲームを選択", "ph": "ゲームファイルを選択 (.3ds)...", "p2": "2. チェック",
 "cc": "Cコンパイラ (Zig)", "sys": "システム", "found": "検出済み", "dl": "ダウンロードします", "bad": "非対応",
 "inst1": "インストール /", "inst2": "リコンパイル", "play": "プレイ", "quit": "終了",
 "infoT": "情報", "info": "PC向け『ドラゴンボールZ 超究極武闘伝』のネイティブリコンパイル版です。\nより快適なパフォーマンスでお楽しみください！",
 "prog": "インストールの進行状況", "wait": "開始を待っています...",
 "romok": "有効なゲーム: {0}（復号済み）", "romenc": "このROMは暗号化されています。カートリッジから吸い出した復号済みの .3ds が必要です。",
 "rombad": "有効な3DS ROMではありません (.3ds/.cci/.cxi)。", "pick": "『ドラゴンボールZ 超究極武闘伝』のファイルを選択",
 "s1": "フォルダーを準備中", "s2": "Zakuro（DBZ版）をインストール中", "incl": "同梱（DBZ版）", "s3": "コンパイラをダウンロード中 (Zig, 約100 MB)", "s4": "コンパイラを展開中",
 "s5": "ゲームをコピー中", "s6": "ネイティブコードにリコンパイル中 (10〜20分)", "s7": "ショートカットを作成中",
 "gen": "Cコードを生成中...", "files": "{0} / {1} ファイル", "retry": "再試行中...",
 "done": "インストール完了！お楽しみください。",
 "donemsg": "インストールしました！\n\nデスクトップのショートカットまたは Jugar.exe からゲームを起動してください。\nゲーム中は Esc でメニュー（操作・グラフィック・サウンド）を開けます。",
 "errmsg": "エラーが発生しました。ログの場所:", "cancel": "インストール中です。中止して終了しますか？",
 "nowrite": "インストーラーのフォルダーに書き込めません。デスクトップなどに移動してから、もう一度開いてください。",
 "oldwin": "Windows 10 (1803) 以降が必要です。", "installed": "インストール済み: プレイを押してください",
 "errdl": "{0} をダウンロードできませんでした。", "errzip": "{0} を展開できませんでした。", "errcopy": "ゲームをコピーできませんでした（ディスクの空き容量を確認してください）。",
 "errrecomp": "リコンパイルに失敗しました。", "fail": "エラー: メッセージを確認してください"
},
"zh": {
 "upd_btn": "更新到 v{0}", "upd_ok": "v{0} · 最新版本", "upd_check": "v{0} · 正在检查更新…", "upd_auto": "正在更新到最新版本…",
 "dest": "安装文件夹（所有数据都保存在这里）", "free": "可用：{0} GB", "pickdest": "选择游戏的安装位置。游戏、存档、设置和图形缓存都将保存在该文件夹中。", "nospace": "所选文件夹的可用空间不足：大约需要 {0} GB。", "nowrite2": "无法写入该文件夹。请选择其他文件夹。",
 "lang": "语言",
 "win": "Extreme Fighters - 安装程序",
 "p1": "1. 选择你的 3DS 游戏", "ph": "选择游戏文件 (.3ds)...", "p2": "2. 检查",
 "cc": "C 编译器 (Zig)", "sys": "系统", "found": "已找到", "dl": "将自动下载", "bad": "不支持",
 "inst1": "安装 /", "inst2": "重新编译", "play": "开始游戏", "quit": "退出",
 "infoT": "信息", "info": "《龙珠Z 超究极武斗传》PC 原生重编译版。\n享受性能更出色的游戏体验！",
 "prog": "安装进度", "wait": "等待开始...",
 "romok": "有效的游戏：{0}（已解密）", "romenc": "此 ROM 已加密。你需要从自己的卡带中导出的已解密 .3ds 文件。",
 "rombad": "这不是有效的 3DS ROM (.3ds/.cci/.cxi)。", "pick": "选择你的《龙珠Z 超究极武斗传》文件",
 "s1": "正在准备文件夹", "s2": "正在安装 Zakuro（DBZ 版）", "incl": "已内置（DBZ 版）", "s3": "正在下载编译器 (Zig，约 100 MB)", "s4": "正在解压编译器",
 "s5": "正在复制游戏", "s6": "正在重编译为原生代码 (10-20 分钟)", "s7": "正在创建快捷方式",
 "gen": "正在生成 C 代码...", "files": "{0} / {1} 个文件", "retry": "正在重试...",
 "done": "安装完成！祝你玩得开心。",
 "donemsg": "安装完成！\n\n请使用桌面快捷方式或 Jugar.exe 启动游戏。\n游戏中按 Esc 打开菜单（按键、画面、声音）。",
 "errmsg": "发生错误。日志位置：", "cancel": "安装仍在进行中。要取消并退出吗？",
 "nowrite": "无法写入安装程序所在的文件夹。请将其移动到其他位置（例如桌面）后重新打开。",
 "oldwin": "需要 Windows 10 (1803) 或更高版本。", "installed": "已安装：请点击开始游戏",
 "errdl": "无法下载 {0}。", "errzip": "无法解压 {0}。", "errcopy": "无法复制游戏（磁盘空间是否已满？）。",
 "errrecomp": "重编译失败。", "fail": "错误：请查看提示"
}
}
'@ | ConvertFrom-Json

function L([string]$key) { return [string]$script:Strings.($script:Lang).$key }

$script:Lang = 'es'
try { if (Test-Path $LangFile) { $saved = (Get-Content $LangFile -Raw).Trim(); if ($Langs.id -contains $saved) { $script:Lang = $saved } } else {
    $ui = (Get-UICulture).TwoLetterISOLanguageName; if ($Langs.id -contains $ui) { $script:Lang = $ui } } } catch {}

function Msg([string]$text, [string]$icon) {
    [void][System.Windows.Forms.MessageBox]::Show($text, (L 'win'), 'OK', $icon)
}

if (-not (Test-Path $Recomp) -or -not (Test-Path (Join-Path $Assets 'banner.png'))) {
    [void][System.Windows.Forms.MessageBox]::Show("bin\3dsrecomp.exe / assets\banner.png ?`n`nExtrae TODO el ZIP en una carpeta. / Extract the WHOLE ZIP into a folder.", 'DBZ', 'OK', 'Error')
    exit 1
}
try { Get-ChildItem -Path $Here -Recurse | Unblock-File } catch {}

# ---------------------------------------------------------------- ROM
function Read-Rom([string]$path) {
    $fs = [System.IO.File]::OpenRead($path)
    try {
        $buf = New-Object byte[] 0x200
        $null = $fs.Read($buf, 0, 0x200)
        $magic = [System.Text.Encoding]::ASCII.GetString($buf, 0x100, 4)
        $ncch = 0L
        if ($magic -eq 'NCSD') { $ncch = [int64][BitConverter]::ToUInt32($buf, 0x120) * 0x200 }
        elseif ($magic -ne 'NCCH') { throw (L 'rombad') }
        $h = New-Object byte[] 0x200
        $null = $fs.Seek($ncch, 'Begin')
        $null = $fs.Read($h, 0, 0x200)
        if ([System.Text.Encoding]::ASCII.GetString($h, 0x100, 4) -ne 'NCCH') { throw (L 'rombad') }
        $tid = [BitConverter]::ToUInt64($h, 0x118)
        $code = [System.Text.Encoding]::ASCII.GetString($h, 0x150, 16).Trim([char]0)
        $noCrypto = ($h[0x18F] -band 0x4) -ne 0
        [pscustomobject]@{ TitleId = ('{0:X16}' -f $tid); Product = $code; Decrypted = $noCrypto; Size = $fs.Length }
    } finally { $fs.Close() }
}

# ---------------------------------------------------------------- estado
$script:S = @{}
$script:Rom = $null
$script:RomPath = $null
$script:TitleId = $null
$script:Running = $false
$script:Status = ''
$script:StatusKey = $null
$script:StatusArg = $null
$script:StatusColor = 'normal'
$script:Progress = 0.0
$script:Hover = ''

function Get-SystemInfo {
    $build = [Environment]::OSVersion.Version.Build
    $name = 'Windows 10'
    if ($build -ge 22000) { $name = 'Windows 11' }
    try { $ed = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID; if ($ed -match 'Professional') { $name += ' Pro' } elseif ($ed -match 'Core') { $name += ' Home' } } catch {}
    $ok = [Environment]::Is64BitOperatingSystem -and ($build -ge 17134)
    if ([Environment]::Is64BitOperatingSystem) { $name += ' (x64)' } else { $name += ' (x86)' }
    return @{ Name = $name; Ok = $ok }
}
$SysInfo = Get-SystemInfo
function Zakuro-Ready { (Test-Path $ZakuroExe) -and (Test-Path (Join-Path $ZakuroDir 'version.txt')) -and ((Get-Content (Join-Path $ZakuroDir 'version.txt') -Raw).Trim() -eq $ZakuroVersion) }
function Zig-Ready { Test-Path $ZigExe }
function Is-Installed { (Test-Path $script:PlayIni) -and (Test-Path $script:PlayExe) -and (@(Get-ChildItem $NativeDir -Filter '*.dll' -ErrorAction SilentlyContinue).Count -gt 0) }

function Log([string]$text) {
    $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $text
    try { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null; Add-Content -Path (Join-Path $LogDir 'instalador.log') -Value $line -Encoding UTF8 } catch {}
}

# ---------------------------------------------------------------- dibujo
$tmpG = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $k = $tmpG.DpiX / 96.0; $tmpG.Dispose()
$work = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$k = [Math]::Min($k, [Math]::Min(($work.Width - 20) / 1024.0, ($work.Height - 50) / 693.0))
function P([double]$v) { return [single]($v * $k) }
function RF([double]$x, [double]$y, [double]$w, [double]$h) { New-Object System.Drawing.RectangleF((P $x), (P $y), (P $w), (P $h)) }
function C([int]$r, [int]$g, [int]$b, [int]$a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function PT([double]$x, [double]$y) { New-Object System.Drawing.PointF((P $x), (P $y)) }

$Banner = [System.Drawing.Image]::FromFile((Join-Path $Assets 'banner.png'))
$InfoArt = [System.Drawing.Image]::FromFile((Join-Path $Assets 'info.png'))

$FontNames = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }
function Pick-Family([string[]]$names) { foreach ($n in $names) { if ($FontNames -contains $n) { return New-Object System.Drawing.FontFamily($n) } }; return [System.Drawing.FontFamily]::GenericSansSerif }
function Set-Fonts {
    switch ($script:Lang) {
        'ja' { $script:FamBold = Pick-Family @('Yu Gothic UI', 'Meiryo UI', 'MS UI Gothic'); $script:FamText = $script:FamBold }
        'zh' { $script:FamBold = Pick-Family @('Microsoft YaHei UI', 'Microsoft YaHei', 'SimHei'); $script:FamText = $script:FamBold }
        default {
            $script:FamBold = Pick-Family @('Bahnschrift SemiBold SemiConden', 'Bahnschrift', 'Arial Narrow', 'Segoe UI')
            $script:FamText = Pick-Family @('Bahnschrift SemiLight SemiConde', 'Bahnschrift', 'Segoe UI')
        }
    }
}
Set-Fonts
function F([System.Drawing.FontFamily]$fam, [double]$px, [System.Drawing.FontStyle]$style = 'Regular') {
    if (-not $fam.IsStyleAvailable($style)) { $style = 'Regular' }
    if (-not $fam.IsStyleAvailable($style)) { $style = 'Bold' }
    New-Object System.Drawing.Font($fam, (P $px), $style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Grad($rect, $c1, $c2, [single]$angle = 90) {
    $b = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, $angle)
    $b.WrapMode = [System.Drawing.Drawing2D.WrapMode]::TileFlipXY
    return $b
}
function RoundPath([System.Drawing.RectangleF]$r, [double]$rad) {
    $d = [single]([Math]::Max(1, 2 * (P $rad)))
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($r.X, $r.Y, $d, $d, 180, 90)
    $p.AddArc($r.Right - $d, $r.Y, $d, $d, 270, 90)
    $p.AddArc($r.Right - $d, $r.Bottom - $d, $d, $d, 0, 90)
    $p.AddArc($r.X, $r.Bottom - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}
function Star($g, [single]$cx, [single]$cy, [single]$r, $brush) {
    $pts = New-Object 'System.Drawing.PointF[]' 10
    for ($i = 0; $i -lt 10; $i++) {
        $rr = $r; if ($i % 2) { $rr = $r * 0.45 }
        $a = -[Math]::PI / 2 + $i * [Math]::PI / 5
        $pts[$i] = New-Object System.Drawing.PointF(($cx + $rr * [Math]::Cos($a)), ($cy + $rr * [Math]::Sin($a)))
    }
    $g.FillPolygon($brush, $pts)
}
function DragonBall($g, [double]$x, [double]$y, [double]$d) {
    $r = RF $x $y $d $d
    $br = (Grad $r (C 255 222 110) (C 232 104 0) 45)
    $g.FillEllipse($br, $r); $br.Dispose()
    $pen = New-Object System.Drawing.Pen((C 140 50 0), (P 1.2)); $g.DrawEllipse($pen, $r); $pen.Dispose()
    $hl = New-Object System.Drawing.SolidBrush((C 255 255 255 170))
    $g.FillEllipse($hl, (RF ($x + $d * 0.2) ($y + $d * 0.14) ($d * 0.28) ($d * 0.2))); $hl.Dispose()
    $red = New-Object System.Drawing.SolidBrush((C 215 25 20))
    Star $g (P ($x + $d * 0.42)) (P ($y + $d * 0.58)) (P ($d * 0.17)) $red
    Star $g (P ($x + $d * 0.68)) (P ($y + $d * 0.4)) (P ($d * 0.14)) $red
    $red.Dispose()
}
function PanelBox($g, [double]$x, [double]$y, [double]$w, [double]$h) {
    $r = RF $x $y $w $h
    $path = RoundPath $r 7
    $br = (Grad $r (C 30 26 24) (C 12 11 12) 90)
    $g.FillPath($br, $path); $br.Dispose()
    $pen = New-Object System.Drawing.Pen((C 242 142 20), (P 2)); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
}
function Heading($g, [double]$x, [double]$y, [string]$text, [double]$w) {
    DragonBall $g $x $y 22
    $f = F $script:FamBold 19 'Bold'
    $br = New-Object System.Drawing.SolidBrush((C 255 196 40))
    $sf = New-Object System.Drawing.StringFormat; $sf.FormatFlags = 'NoWrap'; $sf.Trimming = 'EllipsisCharacter'
    $g.DrawString($text, $f, $br, (RF ($x + 28) ($y - 2) $w 28), $sf); $br.Dispose(); $f.Dispose()
    $pen = New-Object System.Drawing.Pen((C 255 255 255 28), (P 1))
    $g.DrawLine($pen, (P ($x - 6)), (P ($y + 29)), (P ($x + $w + 24)), (P ($y + 29))); $pen.Dispose()
}
function OutlinedText($g, [string]$text, [System.Drawing.FontFamily]$fam, [double]$px, [System.Drawing.RectangleF]$rect, $fill, [double]$outline, [string]$align = 'Center') {
    $style = [System.Drawing.FontStyle]::Bold
    if (-not $fam.IsStyleAvailable($style)) { $style = [System.Drawing.FontStyle]::Regular }
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = $align; $sf.LineAlignment = 'Center'; $sf.FormatFlags = 'NoWrap'
    $size = P $px
    $font = New-Object System.Drawing.Font($fam, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    while ($size -gt 8 -and $g.MeasureString($text, $font).Width -gt $rect.Width) {
        $font.Dispose(); $size -= 1; $font = New-Object System.Drawing.Font($fam, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $font.Dispose()
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($text, $fam, [int]$style, [single]$size, $rect, $sf)
    if ($outline -gt 0) {
        $pen = New-Object System.Drawing.Pen((C 40 14 0 220), (P $outline)); $pen.LineJoin = 'Round'
        $g.DrawPath($pen, $path); $pen.Dispose()
    }
    $g.FillPath($fill, $path); $path.Dispose()
}
function StateIcon($g, [double]$x, [double]$y, [string]$kind) {
    $r = RF $x $y 22 22
    $c1 = C 70 205 80; $c2 = C 25 135 40
    if ($kind -eq 'dl') { $c1 = C 255 186 60; $c2 = C 215 105 0 }
    if ($kind -eq 'bad') { $c1 = C 255 100 90; $c2 = C 180 30 30 }
    $br = (Grad $r $c1 $c2 90)
    $g.FillEllipse($br, $r); $br.Dispose()
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, (P 2.6)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    switch ($kind) {
        'ok'  { $g.DrawLines($pen, [System.Drawing.PointF[]]@((PT ($x + 6) ($y + 11.5)), (PT ($x + 9.5) ($y + 15)), (PT ($x + 16.5) ($y + 7)))) }
        'dl'  { $g.DrawLine($pen, (PT ($x + 11) ($y + 5)), (PT ($x + 11) ($y + 15))); $g.DrawLines($pen, [System.Drawing.PointF[]]@((PT ($x + 6.5) ($y + 11)), (PT ($x + 11) ($y + 15.5)), (PT ($x + 15.5) ($y + 11)))) }
        'bad' { $g.DrawLine($pen, (PT ($x + 7) ($y + 7)), (PT ($x + 15) ($y + 15))); $g.DrawLine($pen, (PT ($x + 15) ($y + 7)), (PT ($x + 7) ($y + 15))) }
    }
    $pen.Dispose()
}
function Gear($g, [double]$cx, [double]$cy, [double]$r, $color) {
    $st = $g.Save()
    $g.TranslateTransform((P $cx), (P $cy))
    $br = New-Object System.Drawing.SolidBrush($color)
    for ($i = 0; $i -lt 8; $i++) {
        $g.FillRectangle($br, (RF (-$r * 0.18) (-$r) ($r * 0.36) ($r * 0.4)))
        $g.RotateTransform(45)
    }
    $pen = New-Object System.Drawing.Pen($color, (P ($r * 0.3)))
    $g.DrawEllipse($pen, (RF (-$r * 0.68) (-$r * 0.68) ($r * 1.36) ($r * 1.36)))
    $g.DrawEllipse($pen, (RF (-$r * 0.22) (-$r * 0.22) ($r * 0.44) ($r * 0.44)))
    $pen.Dispose(); $br.Dispose()
    $g.Restore($st)
}
function Gamepad($g, [double]$cx, [double]$cy) {
    $white = New-Object System.Drawing.SolidBrush((C 245 245 250))
    $body = RoundPath (RF ($cx - 22) ($cy - 11) 44 20) 9
    $g.FillPath($white, $body); $body.Dispose()
    $g.FillEllipse($white, (RF ($cx - 24) ($cy - 4) 15 17)); $g.FillEllipse($white, (RF ($cx + 9) ($cy - 4) 15 17))
    $dark = New-Object System.Drawing.SolidBrush((C 40 42 50))
    $g.FillRectangle($dark, (RF ($cx - 16) ($cy - 2.5) 11 4)); $g.FillRectangle($dark, (RF ($cx - 12.5) ($cy - 6) 4 11))
    $g.FillEllipse($dark, (RF ($cx + 8) ($cy - 6) 5 5)); $g.FillEllipse($dark, (RF ($cx + 12) ($cy - 1) 5 5))
    $white.Dispose(); $dark.Dispose()
}
function ExitIcon($g, [double]$cx, [double]$cy) {
    $pen = New-Object System.Drawing.Pen((C 245 245 250), (P 3)); $pen.LineJoin = 'Round'; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $g.DrawLines($pen, [System.Drawing.PointF[]]@((PT ($cx - 2) ($cy - 9)), (PT ($cx - 2) ($cy - 15)), (PT ($cx + 15) ($cy - 15)), (PT ($cx + 15) ($cy + 15)), (PT ($cx - 2) ($cy + 15)), (PT ($cx - 2) ($cy + 9))))
    $g.DrawLine($pen, (PT ($cx - 16) $cy), (PT ($cx + 7) $cy))
    $g.DrawLines($pen, [System.Drawing.PointF[]]@((PT ($cx + 1) ($cy - 6)), (PT ($cx + 7) $cy), (PT ($cx + 1) ($cy + 6))))
    $pen.Dispose()
}
function FolderIcon($g, [double]$x, [double]$y) {
    $back = New-Object System.Drawing.SolidBrush((C 230 160 20))
    $front = New-Object System.Drawing.SolidBrush((C 255 205 50))
    $g.FillPath($back, (RoundPath (RF $x $y 11 6) 2))
    $g.FillPath($back, (RoundPath (RF $x ($y + 3) 24 16) 2))
    $g.FillPath($front, (RoundPath (RF $x ($y + 6.5) 24 12.5) 2))
    $back.Dispose(); $front.Dispose()
}

# rectangulos (coordenadas base 1024x642)
$Layout = @{
    Banner = @(0, 0, 1024, 333)
    Install = @(455, 340, 276, 100); Play = @(455, 452, 276, 74); Quit = @(455, 538, 276, 74)
    Update = @(763, 486, 246, 34)
    File = @(21, 380, 350, 36); Folder = @(380, 380, 44, 36); Dest = @(21, 444, 350, 36); DestBtn = @(380, 444, 44, 36)
}
function RR([string]$n) { $a = $Layout[$n]; RF $a[0] $a[1] $a[2] $a[3] }
function Can([string]$n) {
    switch ($n) {
        'Install' { return [bool]((-not $script:Running) -and $script:Rom -and $SysInfo.Ok) }
        'Play'    { return [bool]((-not $script:Running) -and (Is-Installed)) }
        'File'    { return -not $script:Running }
        'Folder'  { return -not $script:Running }
        'Dest'    { return -not $script:Running }
        'DestBtn' { return -not $script:Running }
        'Quit'    { return $true }
        'Update'  { return [bool]((-not $script:Running) -and $script:NewVersion) }
    }
    return $false
}

function Draw-Button($g, [string]$n, [bool]$primary) {
    $r = RR $n
    $en = Can $n
    $hov = $en -and ($script:Hover -eq $n)
    $path = RoundPath $r 9
    if ($primary) {
        $c1 = C 255 178 52; $c2 = C 232 92 0
        if ($hov) { $c1 = C 255 200 90; $c2 = C 245 115 10 }
        if (-not $en) { $c1 = C 150 110 70; $c2 = C 100 64 30 }
        $border = C 255 226 130
    } else {
        $c1 = C 68 70 80; $c2 = C 30 31 36
        if ($hov) { $c1 = C 90 92 104; $c2 = C 42 43 50 }
        if (-not $en) { $c1 = C 45 46 50; $c2 = C 26 26 30 }
        $border = C 120 122 135
    }
    $br = (Grad $r $c1 $c2 90)
    $g.FillPath($br, $path); $br.Dispose()
    $pen = New-Object System.Drawing.Pen($border, (P 2)); $g.DrawPath($pen, $path); $pen.Dispose(); $path.Dispose()
    $a = $Layout[$n]
    $tc = C 255 255 255; if (-not $en) { $tc = C 175 175 175 }
    $fill = New-Object System.Drawing.SolidBrush($tc)
    switch ($n) {
        'Install' {
            Gear $g ($a[0] + 44) ($a[1] + 50) 26 (C 120 42 0)
            OutlinedText $g (L 'inst1') $script:FamBold 27 (RF ($a[0] + 80) ($a[1] + 15) ($a[2] - 92) 36) $fill 3.5
            OutlinedText $g (L 'inst2') $script:FamBold 27 (RF ($a[0] + 80) ($a[1] + 49) ($a[2] - 92) 36) $fill 3.5
        }
        'Play' { Gamepad $g ($a[0] + 52) ($a[1] + 37); OutlinedText $g (L 'play') $script:FamBold 30 (RF ($a[0] + 88) $a[1] ($a[2] - 100) $a[3]) $fill 2.5 }
        'Quit' { ExitIcon $g ($a[0] + 52) ($a[1] + 37); OutlinedText $g (L 'quit') $script:FamBold 30 (RF ($a[0] + 88) $a[1] ($a[2] - 100) $a[3]) $fill 2.5 }
    }
    $fill.Dispose()
}

function PathBox($g, [string]$box, [string]$btn, [string]$txt, $tcol, $border) {
    $fr = RR $box
    $fp = RoundPath $fr 5
    $bgb = New-Object System.Drawing.SolidBrush((C 22 22 26)); $g.FillPath($bgb, $fp); $bgb.Dispose()
    $bc = C 130 130 140
    if ($script:Hover -eq $box -and (Can $box)) { $bc = C 255 170 40 }
    if ($border) { $bc = $border }
    $pen = New-Object System.Drawing.Pen($bc, (P 1.6)); $g.DrawPath($pen, $fp); $pen.Dispose(); $fp.Dispose()
    $a = $Layout[$box]
    $f = F $script:FamText 16
    $sf = New-Object System.Drawing.StringFormat; $sf.LineAlignment = 'Center'; $sf.Trimming = 'EllipsisPath'; $sf.FormatFlags = 'NoWrap'
    $tb = New-Object System.Drawing.SolidBrush($tcol)
    $g.DrawString($txt, $f, $tb, (RF ($a[0] + 10) $a[1] ($a[2] - 16) $a[3]), $sf); $tb.Dispose(); $f.Dispose()
    $or = RR $btn; $op = RoundPath $or 5
    $c1 = C 70 70 78; if ($script:Hover -eq $btn -and (Can $btn)) { $c1 = C 100 100 110 }
    $ob = (Grad $or $c1 (C 30 30 34) 90); $g.FillPath($ob, $op); $ob.Dispose()
    $pen = New-Object System.Drawing.Pen((C 140 140 150), (P 1.4)); $g.DrawPath($pen, $op); $pen.Dispose(); $op.Dispose()
    $b = $Layout[$btn]
    FolderIcon $g ($b[0] + 10) ($b[1] + 8)
}

function Draw-All($g) {
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.Clear((C 8 8 10))

    # banner
    $g.DrawImage($Banner, (RR 'Banner'))
    $fade = RF 0 288 1024 50
    $br = (Grad $fade (C 8 8 10 0) (C 8 8 10 255) 90)
    $g.FillRectangle($br, $fade); $br.Dispose()

    # etiqueta del selector de idioma
    $lb = RF 750 4 126 34
    $plate = RoundPath (RF 752 5 266 32) 6
    $pb = New-Object System.Drawing.SolidBrush((C 0 0 0 150)); $g.FillPath($pb, $plate); $pb.Dispose()
    $pen = New-Object System.Drawing.Pen((C 242 142 20), (P 1.5)); $g.DrawPath($pen, $plate); $pen.Dispose(); $plate.Dispose()
    $yb = New-Object System.Drawing.SolidBrush((C 255 200 50))
    OutlinedText $g ((L 'lang') + ':') $script:FamBold 19 $lb $yb 2.5 'Far'
    $yb.Dispose()

    # 1. juego + carpeta de instalacion
    PanelBox $g 9 338 427 146
    Heading $g 21 347 (L 'p1') 395
    $romTxt = L 'ph'; $romCol = C 150 150 158
    if ($script:RomPath) { $romTxt = $script:RomPath; $romCol = C 235 235 240 }
    $romBorder = $null
    if ($script:StatusColor -eq 'romok') { $romBorder = C 80 200 90 } elseif ($script:StatusColor -eq 'romerr') { $romBorder = C 230 80 70 }
    PathBox $g 'File' 'Folder' $romTxt $romCol $romBorder
    $fc = F $script:FamText 14
    $cap = New-Object System.Drawing.SolidBrush((C 255 190 70))
    $g.DrawString((L 'dest'), $fc, $cap, (RF 22 421 300 20))
    $free = Free-GB $script:InstDir
    if ($free -ge 0) {
        $sfr = New-Object System.Drawing.StringFormat; $sfr.Alignment = 'Far'
        $gb = New-Object System.Drawing.SolidBrush((C 170 170 178))
        $g.DrawString(((L 'free') -f $free), $fc, $gb, (RF 260 421 164 20), $sfr); $gb.Dispose()
    }
    $cap.Dispose(); $fc.Dispose()
    PathBox $g 'Dest' 'DestBtn' $script:InstDir (C 235 235 240) $null

    # 2. comprobaciones
    PanelBox $g 9 490 427 122
    Heading $g 21 499 (L 'p2') 395
    $rows = @(
        @{ label = 'Zakuro'; ok = (Zakuro-Ready); incl = $true },
        @{ label = (L 'cc'); ok = (Zig-Ready) }
    )
    $y = 534
    $fl = F $script:FamText 17
    $white = New-Object System.Drawing.SolidBrush((C 235 235 240))
    foreach ($row in $rows) {
        $kind = 'dl'; $val = L 'dl'; $vc = C 255 186 60
        if ($row.incl) { $kind = 'ok'; $val = L 'incl'; $vc = C 90 220 100 }
        if ($row.ok) { $kind = 'ok'; $val = L 'found'; $vc = C 90 220 100 }
        StateIcon $g 21 $y $kind
        $lab = $row.label + ':'
        $g.DrawString($lab, $fl, $white, (RF 52 ($y - 1) 360 26))
        $w = $g.MeasureString($row.label + ':', $fl).Width / $k + 8
        $vb = New-Object System.Drawing.SolidBrush($vc); $g.DrawString($val, $fl, $vb, (RF (52 + $w) ($y - 1) 300 26)); $vb.Dispose()
        $y += 26
    }
    $kind = 'ok'; if (-not $SysInfo.Ok) { $kind = 'bad' }
    StateIcon $g 21 $y $kind
    $g.DrawString(((L 'sys') + ':  ' + $SysInfo.Name), $fl, $white, (RF 52 ($y - 1) 370 26))
    $fl.Dispose()

    # botones
    Draw-Button $g 'Install' $true
    Draw-Button $g 'Play' $false
    Draw-Button $g 'Quit' $false

    # informacion
    PanelBox $g 751 338 264 274
    Heading $g 763 347 (L 'infoT') 230
    $g.SetClip((RF 753 529 260 81))
    $g.DrawImage($InfoArt, (RF 753 529 260 81))
    $g.ResetClip()
    $fade2 = RF 753 528 260 20
    $br = (Grad $fade2 (C 20 18 18 255) (C 20 18 18 0) 90)
    $g.FillRectangle($br, $fade2); $br.Dispose()
    $fi = F $script:FamText 16
    $g.DrawString((L 'info'), $fi, $white, (RF 763 382 246 100)); $fi.Dispose()
    # actualizaciones: boton cuando hay una version nueva en GitHub
    if ($script:NewVersion) {
        $ur = RR 'Update'; $up = RoundPath $ur 7
        $c1 = C 255 178 52; $c2 = C 232 92 0
        if ($script:Hover -eq 'Update' -and (Can 'Update')) { $c1 = C 255 205 95; $c2 = C 245 120 15 }
        $ub = (Grad $ur $c1 $c2 90); $g.FillPath($ub, $up); $ub.Dispose()
        $pen = New-Object System.Drawing.Pen((C 255 230 140), (P 1.5)); $g.DrawPath($pen, $up); $pen.Dispose(); $up.Dispose()
        $wb = New-Object System.Drawing.SolidBrush((C 255 255 255))
        OutlinedText $g ((L 'upd_btn') -f $script:NewVersion) $script:FamBold 17 $ur $wb 2.5
        $wb.Dispose()
    } else {
        $key = 'upd_check'; if ($script:UpdChecked) { $key = 'upd_ok' }
        $fu = F $script:FamText 13 'Italic'
        $gb = New-Object System.Drawing.SolidBrush((C 165 165 172))
        $g.DrawString(((L $key) -f $AppVersion), $fu, $gb, (RF 763 494 246 22)); $gb.Dispose(); $fu.Dispose()
    }
    $pen = New-Object System.Drawing.Pen((C 242 142 20), (P 2)); $p = RoundPath (RF 751 338 264 274) 7; $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()

    # progreso
    PanelBox $g 9 619 1006 66
    Heading $g 21 627 (L 'prog') 400
    $st = $script:Status; if (-not $st) { $st = L 'wait' }
    $sc = C 235 235 240
    switch ($script:StatusColor) { 'ok' { $sc = C 90 220 100 } 'romok' { $sc = C 90 220 100 } 'err' { $sc = C 255 105 95 } 'romerr' { $sc = C 255 105 95 } }
    $fs = F $script:FamText 16 'Italic'
    $sf2 = New-Object System.Drawing.StringFormat; $sf2.Alignment = 'Far'; $sf2.Trimming = 'EllipsisCharacter'; $sf2.FormatFlags = 'NoWrap'
    $sb = New-Object System.Drawing.SolidBrush($sc); $g.DrawString($st, $fs, $sb, (RF 330 628 676 24), $sf2); $sb.Dispose(); $fs.Dispose()
    $track = RF 25 659 974 15
    $tp = RoundPath $track 7
    $tb2 = (Grad $track (C 70 70 76) (C 40 40 44) 90); $g.FillPath($tb2, $tp); $tb2.Dispose()
    $pen = New-Object System.Drawing.Pen((C 150 150 160), (P 1)); $g.DrawPath($pen, $tp); $pen.Dispose(); $tp.Dispose()
    if ($script:Progress -gt 0.005) {
        $fillR = RF 25 659 ([Math]::Max(14, 974 * $script:Progress)) 15
        $fpth = RoundPath $fillR 7
        $c1 = C 255 205 70; $c2 = C 235 105 0
        if ($script:StatusColor -eq 'err') { $c1 = C 255 120 110; $c2 = C 190 40 40 }
        $fb = (Grad $fillR $c1 $c2 90); $g.FillPath($fb, $fpth); $fb.Dispose(); $fpth.Dispose()
    }
    $white.Dispose()
}

# ---------------------------------------------------------------- ventana
$form = New-Object System.Windows.Forms.Form
$form.Text = (L 'win') + "  v$AppVersion"
$form.ClientSize = New-Object System.Drawing.Size([int](P 1024), [int](P 693))
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = (C 8 8 10)
try { $form.Icon = New-Object System.Drawing.Icon((Join-Path $Assets 'bola.ico')) } catch {}
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($form, $true, $null)

$LangBox = New-Object System.Windows.Forms.ComboBox
$LangBox.DropDownStyle = 'DropDownList'
$LangBox.FlatStyle = 'Flat'
$LangBox.BackColor = (C 24 24 28)
$LangBox.ForeColor = (C 255 200 60)
$LangBox.Font = New-Object System.Drawing.Font('Segoe UI', (P 13), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$LangBox.SetBounds([int](P 882), [int](P 9), [int](P 130), [int](P 24))
foreach ($l in $Langs) { [void]$LangBox.Items.Add($l.name) }
$LangBox.SelectedIndex = [Array]::IndexOf([string[]]@($Langs | ForEach-Object { $_.id }), $script:Lang)
$form.Controls.Add($LangBox)
$LangBox.Add_SelectedIndexChanged({
    $script:Lang = $Langs[$LangBox.SelectedIndex].id
    try { Set-Content -Path $LangFile -Value $script:Lang } catch {}
    Set-Fonts
    $form.Text = (L 'win') + "  v$AppVersion"
    if ($script:StatusKey) { $script:Status = (L $script:StatusKey) -f $script:StatusArg }
    $form.Invalidate()
})

$form.Add_Paint({ param($sender, $e) try { Draw-All $e.Graphics } catch { Log "paint: $($_.Exception.Message)" } })

function Hit([int]$x, [int]$y) {
    foreach ($n in 'Install', 'Play', 'Quit', 'File', 'Folder', 'Dest', 'DestBtn', 'Update') {
        if ((RR $n).Contains([single]$x, [single]$y)) { return $n }
    }
    return ''
}
$form.Add_MouseMove({ param($sender, $e)
    $h = Hit $e.X $e.Y
    if ($h -ne $script:Hover) {
        $script:Hover = $h
        if ($h -and (Can $h)) { $form.Cursor = [System.Windows.Forms.Cursors]::Hand } else { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
        $form.Invalidate()
    }
})
$form.Add_MouseLeave({ $script:Hover = ''; $form.Invalidate() })

function SetStatus([string]$key, $arg, [double]$fraction, [string]$color = 'normal') {
    $script:StatusKey = $key; $script:StatusArg = $arg
    $script:Status = (L $key) -f $arg
    $script:StatusColor = $color
    if ($fraction -ge 0) { $script:Progress = [Math]::Max(0, [Math]::Min(1, $fraction)) }
    $form.Invalidate()
}

# ---------------------------------------------------------------- procesos en segundo plano
function Start-Hidden([string]$file, [string]$arguments, [string]$name) {
    $out = Join-Path $LogDir "$name.log"
    $err = Join-Path $LogDir "$name.err.log"
    $p = Start-Process -FilePath $file -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle
    $script:S.Proc = $p; $script:S.Out = $out; $script:S.Err = $err
}
function Read-Shared([string]$path) {
    try {
        $fs = New-Object System.IO.FileStream($path, 'Open', 'Read', 'ReadWrite')
        $sr = New-Object System.IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Close(); return $t
    } catch { return '' }
}
function Tail-Err {
    $t = (Read-Shared $script:S.Err) + "`n" + (Read-Shared $script:S.Out)
    (($t -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 10) -join "`r`n")
}
function RomDst { Join-Path $GameDir ('DBZ_ExtremeButoden' + [IO.Path]::GetExtension($script:Rom).ToLower()) }

$Steps = @(
    @{ Key = 's1'; Begin = {
        if (-not (Test-Writable $InstDir)) { throw (L 'nowrite2') }
        $need = [Math]::Ceiling((Get-Item $script:Rom).Length / 1GB + 2.5)
        $free = Free-GB $InstDir
        if ($free -ge 0 -and $free -lt $need) { throw ((L 'nospace') -f $need) }
        foreach ($d in $InstDir, $ZakuroDir, $GameDir, $NativeDir, $SaveDir, $LogDir, $TmpDir, $ToolsDir, $ZigCache, $AppRoam, $AppLocal, $AppTemp) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
        try { Set-Content -Path $DestFile -Value $InstDir } catch {}
        if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue) -or -not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw (L 'oldwin') }
        $script:S.Skip = $true }; Poll = { 'ok' } },

    @{ Key = 's2'; Begin = {
        if (Zakuro-Ready) { Log 'Zakuro ya estaba.'; $script:S.Skip = $true; return }
        Copy-Item $ZakuroSrc $ZakuroExe -Force
        Copy-Item (Join-Path $Here 'bin\LICENSE-zakuro.txt') (Join-Path $ZakuroDir 'LICENSE.txt') -Force -ErrorAction SilentlyContinue
        Set-Content -Path (Join-Path $ZakuroDir 'version.txt') -Value $ZakuroVersion
        $script:S.Skip = $true }; Poll = { 'ok' } },

    @{ Key = 's3'; Begin = {
        if (Zig-Ready) { Log 'Zig ya estaba.'; $script:S.Skip = $true; return }
        $sources = @("https://ziglang.org/download/$ZigVersion/$ZigFile")
        try {
            $m = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 'https://ziglang.org/download/community-mirrors.txt').Content
            $sources += ($m -split "`r?`n" | Where-Object { $_ -like 'https://*' } | Get-Random -Count 4 | ForEach-Object { $_.TrimEnd('/') + "/$ZigFile" })
        } catch {}
        $script:S.Sources = [System.Collections.ArrayList]$sources
        $script:S.Zip = Join-Path $TmpDir $ZigFile
        $script:S.NextZig = {
            $url = $script:S.Sources[0]; $script:S.Sources.RemoveAt(0)
            Remove-Item $script:S.Zip -ErrorAction SilentlyContinue
            Log "Zig: $url"
            Start-Hidden 'curl.exe' "-sSfL --retry 2 --connect-timeout 30 -o `"$($script:S.Zip)`" `"$url`"" 'descarga_zig'
        }
        & $script:S.NextZig
      }; Poll = {
        $p = $script:S.Proc
        if (-not $p.HasExited) {
            $n = 0; if (Test-Path $script:S.Zip) { $n = (Get-Item $script:S.Zip).Length }
            return @{ f = [Math]::Min(0.99, $n / $ZigSize); t = ('{0:N0} / {1:N0} MB' -f ($n / 1MB), ($ZigSize / 1MB)) }
        }
        $good = ($p.ExitCode -eq 0) -and (Test-Path $script:S.Zip) -and ((Get-FileHash $script:S.Zip -Algorithm SHA256).Hash -eq $ZigSha256)
        if (-not $good) {
            if ($script:S.Sources.Count -gt 0) { Log 'Zig: otro servidor'; & $script:S.NextZig; return @{ f = 0; t = (L 'retry') } }
            throw (((L 'errdl') -f 'Zig') + "`r`n" + (Tail-Err))
        }
        'ok' } },

    @{ Key = 's4'; Begin = {
        if (Zig-Ready) { $script:S.Skip = $true; return }
        $script:S.Stage = Join-Path $ToolsDir "zig-$ZigVersion.unpacking"
        Remove-Item $script:S.Stage -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $script:S.Stage | Out-Null
        Start-Hidden 'tar.exe' "-xf `"$($script:S.Zip)`" -C `"$($script:S.Stage)`"" 'descomprimir_zig'
      }; Poll = {
        if (-not $script:S.Proc.HasExited) { $script:S.Tick = 1 + [int]$script:S.Tick; return @{ f = [Math]::Min(0.95, $script:S.Tick / 150.0); t = '' } }
        if ($script:S.Proc.ExitCode -ne 0) { throw (((L 'errzip') -f 'Zig') + "`r`n" + (Tail-Err)) }
        $inner = Get-ChildItem $script:S.Stage -Directory | Select-Object -First 1
        Remove-Item $ZigDir -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item $inner.FullName $ZigDir
        Remove-Item $script:S.Stage -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $script:S.Zip -ErrorAction SilentlyContinue
        if (-not (Zig-Ready)) { throw ((L 'errzip') -f 'Zig') }
        'ok' } },

    @{ Key = 's5'; Begin = {
        $script:S.RomDst = RomDst
        if ([IO.Path]::GetFullPath($script:Rom) -eq [IO.Path]::GetFullPath($script:S.RomDst)) { $script:S.Skip = $true; return }
        if ((Test-Path $script:S.RomDst) -and ((Get-Item $script:S.RomDst).Length -eq (Get-Item $script:Rom).Length)) { $script:S.Skip = $true; return }
        Start-Hidden 'cmd.exe' "/c copy /y `"$($script:Rom)`" `"$($script:S.RomDst)`"" 'copiar'
      }; Poll = {
        $total = (Get-Item $script:Rom).Length
        if (-not $script:S.Proc.HasExited) {
            $n = 0; if (Test-Path $script:S.RomDst) { $n = (Get-Item $script:S.RomDst).Length }
            return @{ f = $n / [double]$total; t = ('{0:N0} / {1:N0} MB' -f ($n / 1MB), ($total / 1MB)) }
        }
        if ($script:S.Proc.ExitCode -ne 0 -or (Get-Item $script:S.RomDst).Length -ne $total) { throw ((L 'errcopy') + "`r`n" + (Tail-Err)) }
        'ok' } },

    @{ Key = 's6'; Begin = {
        $script:S.RomDst = RomDst
        if (Test-Path (Join-Path $NativeDir "$($script:TitleId).dll")) { Log 'Ya recompilado.'; $script:S.Skip = $true; return }
        $env:PATH = "$ZigDir;$env:PATH"
        $env:CC = 'zig cc'
        $env:ZIG_GLOBAL_CACHE_DIR = $ZigCache
        $env:ZIG_LOCAL_CACHE_DIR = $ZigCache
        # nada fuera de la carpeta de instalacion
        $env:APPDATA = $AppRoam; $env:LOCALAPPDATA = $AppLocal; $env:TEMP = $AppTemp; $env:TMP = $AppTemp
        Remove-Item $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
        # con carpeta de salida, 3dsrecomp lo deja todo ahi y no toca AppData
        Start-Hidden $Recomp "build `"$($script:S.RomDst)`" `"$BuildDir`"" 'recompilar'
        $script:S.Seen = 0
      }; Poll = {
        $text = Read-Shared $script:S.Out
        $lines = $text -split "`r?`n"
        for ($i = $script:S.Seen; $i -lt $lines.Count - 1; $i++) { if ($lines[$i] -and $lines[$i] -notmatch '^compiled \d+ of \d+$') { Log $lines[$i] } }
        $script:S.Seen = [Math]::Max($script:S.Seen, $lines.Count - 1)
        $m = [regex]::Matches($text, 'compiled (\d+) of (\d+)')
        $f = 0.03; $t = L 'gen'
        if ($m.Count -gt 0) { $last = $m[$m.Count - 1]; $f = 0.05 + 0.9 * [int]$last.Groups[1].Value / [double][int]$last.Groups[2].Value; $t = (L 'files') -f $last.Groups[1].Value, $last.Groups[2].Value }
        if (-not $script:S.Proc.HasExited) { return @{ f = $f; t = $t } }
        $dll = Get-ChildItem $BuildDir -Recurse -Filter "$($script:TitleId).dll" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($script:S.Proc.ExitCode -ne 0 -or -not $dll) { throw ((L 'errrecomp') + "`r`n" + (Tail-Err)) }
        Copy-Item $dll.FullName (Join-Path $NativeDir "$($script:TitleId).dll") -Force
        Remove-Item $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
        'ok' } },

    @{ Key = 's7'; Begin = {
        $romName = Split-Path $script:S.RomDst -Leaf
        Copy-Item $PlaySrc $PlayExe -Force
        # actualizador del juego (Esc > Actualizar) y lo que necesita saber
        Copy-Item (Join-Path $Here 'bin\actualizar.ps1') (Join-Path $InstDir 'actualizar.ps1') -Force
        # servidor de salas (Online > Abrir servidor publico, o Iniciar_servidor.bat)
        $srvDir = Join-Path $InstDir 'servidor'
        New-Item -ItemType Directory -Force -Path $srvDir | Out-Null
        Copy-Item (Join-Path $Here 'bin\servidor\*') $srvDir -Force
        [IO.File]::WriteAllText((Join-Path $InstDir 'ef_version.txt'), $AppVersion, (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $InstDir 'idioma.txt'), $script:Lang, (New-Object System.Text.UTF8Encoding($false)))
        # de serie: pantalla superior grande y la inferior pequena (layout large_top
        # de Zakuro) para este juego, en la configuracion portatil (appdata)
        $cfgDir = Join-Path $AppRoam 'zakuro'
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        $cfg = Join-Path $cfgDir 'settings.toml'
        $section = "[per_game.$($script:TitleId)]"
        $old = ''; if (Test-Path $cfg) { $old = [IO.File]::ReadAllText($cfg) }
        # 0.2.x ponia la disposicion por juego; ahora es general (superior completa)
        $old = [regex]::Replace($old, '(?m)^layout = "large_top"\r?\n', '')
        if ($old -notmatch [regex]::Escape($section)) {
            # el juego arranca en el idioma elegido en el instalador (idioma de la consola)
            $consoleLang = @{ es = 'spanish'; en = 'english'; fr = 'french'; de = 'german'; it = 'italian'; ja = 'japanese'; zh = 'chinese_simplified' }[$script:Lang]
            $old = $old.TrimEnd() + "`n`n$section`nlanguage = `"$consoleLang`"`n"
        }
        # claves generales: van antes de la primera [seccion] del archivo
        $cut = if ($old.StartsWith('[')) { 0 } else { $old.IndexOf("`n[") }
        if ($cut -lt 0) { $top = $old; $rest = '' } else { $top = $old.Substring(0, $cut); $rest = $old.Substring($cut) }
        $get = { param($key) $m = [regex]::Match($script:cfgTop, "(?m)^$key = (.*)$"); if ($m.Success) { $m.Groups[1].Value.Trim() } else { $null } }
        $set = { param($key, $value) $script:cfgTop = [regex]::Replace($script:cfgTop, "(?m)^$key = .*\r?\n?", ''); $script:cfgTop = "$key = $value`n" + $script:cfgTop }
        $script:cfgTop = $top
        & $set 'ui_language' "`"$($script:Lang)`""
        # pantalla superior completa con la inferior pequena encima (salvo que el jugador eligiera otra)
        $chosenScreens = & $get 'layout'
        if (-not $chosenScreens -or $chosenScreens -eq '"stacked"' -or $chosenScreens -eq '"large_top"') { & $set 'layout' '"top_overlay"' }
        if (-not (& $get 'scale')) { & $set 'scale' '3' }
        # calidad grafica segun la tarjeta grafica (si sigue la de serie)
        $res = & $get 'resolution'
        if (-not $res -or $res -eq '3') {
            $quality = Detect-Quality
            Log "Calidad grafica automatica: ${quality}x"
            & $set 'resolution' "$quality"
        }
        $old = $script:cfgTop.TrimEnd() + "`n" + $rest
        [IO.File]::WriteAllText($cfg, $old, (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($PlayIni, "$($script:TitleId)`r`n$romName`r`npantalla_completa=1`r`n", (New-Object System.Text.UTF8Encoding($false)))
        $sh = New-Object -ComObject WScript.Shell
        foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
            $lnk = $sh.CreateShortcut((Join-Path $dir "$GameName.lnk"))
            $lnk.TargetPath = $PlayExe
            $lnk.WorkingDirectory = $InstDir
            $lnk.IconLocation = "$PlayExe,0"
            $lnk.Description = "$GameName - Dragon Ball Z: Extreme Butoden"
            $lnk.Save()
        }
        $script:S.Skip = $true }; Poll = { 'ok' } }
)

$script:Index = -1
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 400

function StepFraction([double]$f) { return ($script:Index + [Math]::Max(0, [Math]::Min(1, $f))) / $Steps.Count }

function Next-Step {
    $script:Index++
    if ($script:Index -ge $Steps.Count) {
        $timer.Stop()
        $script:Running = $false
        SetStatus 'done' $null 1 'ok'
        Log 'Instalacion terminada.'
        if ($Jugar) { Start-Process -FilePath $PlayExe -WorkingDirectory $InstDir; $form.Close(); return }
        if (-not $AutoUpdate) { Msg (L 'donemsg') 'Information' }
        return
    }
    $st = $Steps[$script:Index]
    $script:S.Skip = $false; $script:S.Proc = $null; $script:S.Tick = 0
    Log ("Paso {0}/{1}: {2}" -f ($script:Index + 1), $Steps.Count, $st.Key)
    SetStatus $st.Key $null (StepFraction 0)
    & $st.Begin
    if ($script:S.Skip) { Next-Step }
}

function Fail([string]$msg) {
    $timer.Stop()
    if ($script:S.Proc -and -not $script:S.Proc.HasExited) { try { $script:S.Proc.Kill() } catch {} }
    $script:Running = $false
    Log "ERROR: $msg"
    SetStatus 'fail' $null -1 'err'
    Msg ("$msg`n`n" + (L 'errmsg') + "`n$LogDir") 'Error'
}

$timer.Add_Tick({
    $timer.Stop()
    try {
        $r = & $Steps[$script:Index].Poll | Select-Object -Last 1
        if ($r -eq 'ok') { Next-Step }
        else {
            $step = $Steps[$script:Index]
            $script:StatusKey = $null
            $script:Status = "{0}   {1}" -f (L $step.Key), $r.t
            $script:StatusColor = 'normal'
            $script:Progress = StepFraction $r.f
            $form.Invalidate()
        }
        if ($script:Running) { $timer.Start() }
    } catch { Fail $_.Exception.Message }
})

function Pick-Dest {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = L 'pickdest'
    $dlg.ShowNewFolderButton = $true
    $start = $script:InstDir; while ($start -and -not (Test-Path $start)) { $start = Split-Path $start -Parent }
    if ($start) { $dlg.SelectedPath = $start }
    if ($dlg.ShowDialog($form) -ne 'OK') { return }
    $target = Resolve-Dest $dlg.SelectedPath
    if (-not (Test-Writable (Split-Path $target -Parent)) -and -not (Test-Writable $target)) { Msg (L 'nowrite2') 'Warning'; return }
    Set-InstDir $target
    try { Set-Content -Path $DestFile -Value $target } catch {}
    if (Is-Installed) { SetStatus 'installed' $null 1 'ok' } elseif ($script:StatusKey -eq 'installed') { SetStatus 'wait' $null 0 }
    $form.Invalidate()
}

function Pick-Rom {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = L 'pick'
    $dlg.Filter = '3DS ROM (*.3ds;*.cci;*.cxi)|*.3ds;*.cci;*.cxi|*.*|*.*'
    if ($dlg.ShowDialog($form) -ne 'OK') { return }
    $script:RomPath = $dlg.FileName
    $script:Rom = $null
    try {
        $info = Read-Rom $dlg.FileName
        if (-not $info.Decrypted) { SetStatus 'romenc' $null 0 'romerr'; return }
        $script:Rom = $dlg.FileName
        $script:TitleId = $info.TitleId
        SetStatus 'romok' ("{0} | {1} | {2:N0} MB" -f $info.Product, $info.TitleId, ($info.Size / 1MB)) 0 'romok'
    } catch {
        $script:StatusKey = $null; $script:Status = $_.Exception.Message; $script:StatusColor = 'romerr'; $form.Invalidate()
    }
}

function Start-Install {
    $script:Running = $true
    $script:Index = -1
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    try { Next-Step; if ($script:Running) { $timer.Start() } } catch { Fail $_.Exception.Message }
    $form.Invalidate()
}

$form.Add_MouseClick({ param($sender, $e)
    if ($e.Button -ne 'Left') { return }
    $h = Hit $e.X $e.Y
    if (-not $h -or -not (Can $h)) { return }
    switch ($h) {
        'File'   { Pick-Rom }
        'Folder' { Pick-Rom }
        'Install' { Start-Install }
        'Update' {
            # el actualizador descarga la version nueva, pone al dia esta carpeta
            # del instalador y la instalacion, y vuelve a abrir el instalador
            $upd = Join-Path $Here 'bin\actualizar.ps1'
            $updArgs = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$upd`" -Destino `"$InstDir`" -Instalador `"$Here`""
            Start-Process -FilePath 'powershell.exe' -ArgumentList $updArgs -WorkingDirectory $Here
            $form.Close()
        }
        'Play' { Start-Process -FilePath $PlayExe -WorkingDirectory $InstDir; $form.Close() }
        'Dest'    { Pick-Dest }
        'DestBtn' { Pick-Dest }
        'Quit' { $form.Close() }
    }
})

$form.Add_FormClosing({
    if ($script:Running) {
        $a = [System.Windows.Forms.MessageBox]::Show((L 'cancel'), (L 'win'), 'YesNo', 'Warning')
        if ($a -ne 'Yes') { $_.Cancel = $true; return }
        if ($script:S.Proc -and -not $script:S.Proc.HasExited) { try { $script:S.Proc.Kill() } catch {} }
    }
    $timer.Stop()
})

if (Is-Installed) { SetStatus 'installed' $null 1 'ok' }
Log 'Instalador abierto.'

# ---------------------------------------------------------------- actualizaciones
$script:NewVersion = $null
$script:UpdChecked = $false
$script:UpdProc = $null
$UpdJson = Join-Path $env:TEMP ("ef_ultima_{0}.json" -f $PID)
$updTimer = New-Object System.Windows.Forms.Timer
$updTimer.Interval = 500
$updTimer.Add_Tick({
    if (-not $script:UpdProc -or -not $script:UpdProc.HasExited) { return }
    $updTimer.Stop()
    $script:UpdChecked = $true
    try {
        if ($script:UpdProc.ExitCode -eq 0) {
            $tag = ((Get-Content $UpdJson -Raw | ConvertFrom-Json).tag_name).TrimStart('v')
            if ([version]$tag -gt [version]$AppVersion) { $script:NewVersion = $tag; Log "Version nueva disponible: $tag" }
        }
    } catch { Log "Comprobar actualizaciones: $($_.Exception.Message)" }
    try { Remove-Item $UpdJson -Force -ErrorAction SilentlyContinue } catch {}
    $form.Invalidate()
})

$form.Add_Shown({
    if ($AutoUpdate) {
        # actualizacion automatica: la copia del juego que ya esta instalada
        $installedCopy = Get-ChildItem $GameDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(3ds|cci|cxi)$' } | Select-Object -First 1
        if ($installedCopy) {
            try {
                $info = Read-Rom $installedCopy.FullName
                $script:Rom = $installedCopy.FullName; $script:RomPath = $installedCopy.FullName; $script:TitleId = $info.TitleId
                SetStatus 'upd_auto' $null 0
                Start-Install
                return
            } catch { Log "AutoUpdate: $($_.Exception.Message)" }
        }
        Log 'AutoUpdate: no hay juego instalado en el destino'
        return
    }
    try {
        $script:UpdProc = Start-Process -FilePath 'curl.exe' -WindowStyle Hidden -PassThru -ArgumentList "-fsSL --max-time 15 -A ExtremeFighters -H `"Accept: application/vnd.github+json`" -o `"$UpdJson`" https://api.github.com/repos/kensaiken/ExtremeFighters/releases/latest"
        $null = $script:UpdProc.Handle
        $updTimer.Start()
    } catch { $script:UpdChecked = $true }
})

[void]$form.ShowDialog()
