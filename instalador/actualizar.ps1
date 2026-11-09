# Extreme Fighters: actualizador.
# Descarga la ultima version publicada en GitHub (ExtremeFighters_Instalador.zip),
# la descomprime y abre su instalador en modo automatico sobre la instalacion.
# Lo lanzan el juego (Esc > Actualizar) o el instalador (boton ACTUALIZAR).
#   -Destino     carpeta de instalacion (por defecto, la de este script)
#   -Instalador  carpeta del instalador a sustituir por la nueva version
#   -Jugar       abrir el juego al terminar
param([string]$Destino = '', [string]$Instalador = '', [switch]$Jugar)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Repo  = 'kensaiken/ExtremeFighters'
$Asset = 'ExtremeFighters_Instalador.zip'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Destino) { $Destino = $Here }
$Work  = Join-Path $env:TEMP ('ef_actualizacion_' + [DateTime]::Now.ToString('yyyyMMddHHmmss'))
$Zip   = Join-Path $Work $Asset
$Out   = Join-Path $Work 'nuevo'
$LogF  = Join-Path $Work 'actualizar.log'
New-Item -ItemType Directory -Force -Path $Out | Out-Null

# idioma: el que guardo el instalador
$Lang = 'es'
foreach ($f in @((Join-Path $Destino 'idioma.txt'), (Join-Path $Instalador 'idioma.txt'))) {
    try { if ($f -and (Test-Path $f)) { $Lang = (Get-Content $f -Raw).Trim(); break } } catch {}
}
$T = @{
    es = @('Actualizando Extreme Fighters', 'Buscando la ultima version...', 'Descargando {0}...', 'Descomprimiendo...', 'Abriendo el instalador...', 'No se pudo actualizar:', 'Ya tienes la ultima version.', 'Cerrando el juego...')
    en = @('Updating Extreme Fighters', 'Looking for the latest version...', 'Downloading {0}...', 'Unpacking...', 'Opening the installer...', 'The update failed:', 'You already have the latest version.', 'Closing the game...')
    fr = @('Mise a jour d''Extreme Fighters', 'Recherche de la derniere version...', 'Telechargement de {0}...', 'Decompression...', 'Ouverture de l''installateur...', 'La mise a jour a echoue :', 'Vous avez deja la derniere version.', 'Fermeture du jeu...')
    de = @('Extreme Fighters wird aktualisiert', 'Neueste Version wird gesucht...', '{0} wird heruntergeladen...', 'Wird entpackt...', 'Installation wird geoffnet...', 'Update fehlgeschlagen:', 'Du hast bereits die neueste Version.', 'Spiel wird geschlossen...')
    it = @('Aggiornamento di Extreme Fighters', 'Ricerca dell''ultima versione...', 'Download di {0}...', 'Estrazione...', 'Apertura dell''installazione...', 'Aggiornamento non riuscito:', 'Hai gia l''ultima versione.', 'Chiusura del gioco...')
    ja = @('Extreme Fighters を更新中', '最新バージョンを確認中...', '{0} をダウンロード中...', '展開中...', 'インストーラーを起動中...', '更新に失敗しました:', 'すでに最新バージョンです。', 'ゲームを終了中...')
    zh = @('正在更新 Extreme Fighters', '正在查找最新版本...', '正在下载 {0}...', '正在解压...', '正在打开安装程序...', '更新失败：', '已是最新版本。', '正在关闭游戏...')
}
if (-not $T.ContainsKey($Lang)) { $Lang = 'en' }
function Tx([int]$i) { return $T[$Lang][$i] }
function Log([string]$text) { try { Add-Content -Path $LogF -Value ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $text) -Encoding UTF8 } catch {} }

# ventana pequena con barra de progreso
$form = New-Object System.Windows.Forms.Form
$form.Text = Tx 0
$form.ClientSize = New-Object System.Drawing.Size(460, 120)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false; $form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(20, 17, 16)
$form.ForeColor = [System.Drawing.Color]::WhiteSmoke
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$ico = Join-Path $Destino 'Jugar.exe'
try { if (Test-Path $ico) { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($ico) } } catch {}
$label = New-Object System.Windows.Forms.Label
$label.SetBounds(16, 18, 428, 40); $label.Text = Tx 1
$form.Controls.Add($label)
$bar = New-Object System.Windows.Forms.ProgressBar
$bar.SetBounds(16, 70, 428, 22); $bar.Maximum = 1000
$form.Controls.Add($bar)

$script:Step = 'esperar'
$script:Proc = $null
$script:Url = $null
$script:Size = 0
$script:Tag = ''
$script:Waited = 0

function Fail([string]$why) {
    $timer.Stop()
    Log "ERROR: $why"
    [void][System.Windows.Forms.MessageBox]::Show("$(Tx 5)`n$why`n`n$LogF", (Tx 0), 'OK', 'Error')
    $form.Close()
}
function Start-Hidden([string]$file, [string]$arguments) {
    $p = Start-Process -FilePath $file -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $Work 'salida.txt') -RedirectStandardError (Join-Path $Work 'errores.txt')
    $null = $p.Handle
    $script:Proc = $p
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$timer.Add_Tick({
    try {
        switch ($script:Step) {
            'esperar' {
                # el juego se esta cerrando: se espera a que suelte zakuro.exe
                $label.Text = Tx 7
                $script:Waited++
                if (-not (Get-Process zakuro -ErrorAction SilentlyContinue) -or $script:Waited -gt 40) {
                    $script:Step = 'buscar'
                    $label.Text = Tx 1
                    $json = Join-Path $Work 'ultima.json'
                    Start-Hidden 'curl.exe' "-fsSL --max-time 20 -A ExtremeFighters -H `"Accept: application/vnd.github+json`" -o `"$json`" https://api.github.com/repos/$Repo/releases/latest"
                }
            }
            'buscar' {
                if (-not $script:Proc.HasExited) { return }
                if ($script:Proc.ExitCode -ne 0) { Fail 'GitHub'; return }
                $info = Get-Content (Join-Path $Work 'ultima.json') -Raw | ConvertFrom-Json
                $found = $info.assets | Where-Object { $_.name -eq $Asset } | Select-Object -First 1
                if (-not $found) { Fail "$Asset ?"; return }
                $script:Tag = $info.tag_name
                $script:Url = $found.browser_download_url
                $script:Size = [int64]$found.size
                Log "Ultima version: $($script:Tag) ($($script:Size) bytes)"
                $label.Text = (Tx 2) -f $script:Tag
                Start-Hidden 'curl.exe' "-fsSL --retry 3 --connect-timeout 30 -o `"$Zip`" `"$($script:Url)`""
                $script:Step = 'descargar'
            }
            'descargar' {
                $n = 0; if (Test-Path $Zip) { $n = (Get-Item $Zip).Length }
                if ($script:Size -gt 0) { $bar.Value = [int][Math]::Min(950, 950 * $n / $script:Size) }
                if (-not $script:Proc.HasExited) { return }
                if ($script:Proc.ExitCode -ne 0 -or $n -ne $script:Size) { Fail "download ($n / $($script:Size))"; return }
                $label.Text = Tx 3
                Start-Hidden 'tar.exe' "-xf `"$Zip`" -C `"$Out`""
                $script:Step = 'descomprimir'
            }
            'descomprimir' {
                if (-not $script:Proc.HasExited) { return }
                if ($script:Proc.ExitCode -ne 0) { Fail 'tar'; return }
                $new = Get-ChildItem $Out -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'instalador.ps1') } | Select-Object -First 1
                if (-not $new) { Fail 'instalador.ps1 ?'; return }
                $bar.Value = 980
                $label.Text = Tx 4
                $run = $new.FullName
                # la carpeta del instalador del jugador tambien se pone al dia
                if ($Instalador -and (Test-Path $Instalador)) {
                    try {
                        Copy-Item -Path (Join-Path $new.FullName '*') -Destination $Instalador -Recurse -Force
                        $run = $Instalador
                        Log "Instalador actualizado en $Instalador"
                    } catch { Log "No se pudo copiar el instalador: $($_.Exception.Message)" }
                }
                # el instalador nuevo se abre en el mismo idioma
                try { Copy-Item (Join-Path $Destino 'idioma.txt') (Join-Path $run 'idioma.txt') -Force -ErrorAction Stop } catch {}
                $arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $run 'instalador.ps1')`""
                if (Test-Path (Join-Path $Destino 'jugar.ini')) { $arguments += " -AutoUpdate -Destino `"$Destino`"" }
                if ($Jugar) { $arguments += ' -Jugar' }
                Log "powershell $arguments"
                Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $run
                $bar.Value = 1000
                $timer.Stop()
                $form.Close()
            }
        }
    } catch { Fail $_.Exception.Message }
})
$form.Add_Shown({ $timer.Start() })
[void]$form.ShowDialog()
