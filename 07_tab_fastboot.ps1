#==========================================================================
# TAB 4: FASTBOOT / BOOTLOADER
#==========================================================================

# ---- Tabla codename Xiaomi/Redmi/POCO (ro.product.device -> codename) ----
function Get-XiaomiCodename($device) {
    if (-not $device -or $device -eq "") { return "" }
    $d = $device.ToLower().Trim()
    $map = @{
        # Poco X series
        "vayu"="POCO X3 Pro"
        "bhima"="POCO X3 Pro (IN)"
        "surya"="POCO X3 NFC"
        "karna"="POCO X3 (IN)"
        "veux"="POCO X4 Pro 5G"
        "ares"="POCO X5 Pro 5G"
        "marble"="POCO X5 Pro 5G (alt)"
        # Poco M/F series
        "camellia"="POCO M3 Pro 5G"
        "citrus"="POCO M2 Pro"
        "gram"="POCO M4 Pro"
        "fleur"="POCO M4 Pro 5G"
        "light"="POCO M5"
        "earth"="POCO M5s"
        "fog"="POCO M4 5G"
        "mist"="POCO M5 4G"
        "lmi"="POCO F2 Pro"
        "phoenix"="POCO F1 (Pocophone)"
        "poco_f3"="POCO F3"
        "renoir"="POCO F3 GT"
        # alioth: POCO X3 GT / Redmi K40 / Mi 11X (mismo codename segun region)
        "alioth"="POCO X3 GT / Redmi K40 / Mi 11X"
        # Redmi Note series
        "spes"="Redmi Note 11 4G"
        "spesn"="Redmi Note 11 NFC"
        "sapphire"="Redmi Note 13 5G"
        "sapphiren"="Redmi Note 13 NFC"
        "emerald"="Redmi Note 12 5G"
        "tapas"="Redmi Note 12 4G"
        "sea"="Redmi Note 11S 5G"
        "sunny"="Redmi Note 11 Pro"
        "sweet"="Redmi Note 10 Pro"
        "sweetin"="Redmi Note 10 Pro (IN)"
        "curtana"="Redmi Note 9 Pro"
        "excalibur"="Redmi Note 9 Pro Max"
        "miatoll"="Redmi Note 9 Pro (alt)"
        "joyeuse"="Redmi Note 9S"
        "merlin"="Redmi Note 9 4G"
        "cannon"="Redmi Note 9"
        "ginkgo"="Redmi Note 8"
        "willow"="Redmi Note 8T"
        "violet"="Redmi Note 7 Pro"
        "lavender"="Redmi Note 7"
        "lotus"="Redmi Note 7S"
        "tulip"="Redmi Note 6 Pro"
        "whyred"="Redmi Note 5 Pro"
        "platina"="Redmi Note 5 / Redmi 5 Plus"
        "markw"="Redmi Note 4 (Snapdragon)"
        "mido"="Redmi Note 4X"
        "begonia"="Redmi Note 8 Pro"
        "celcius"="Redmi Note 11 Pro+"
        "star"="Redmi Note 10 5G"
        # Redmi numbered
        "lancelot"="Redmi 9"
        "angelica"="Redmi 9A/9C"
        "dandelion"="Redmi 9A Sport"
        "cattail"="Redmi 9C"
        "catpurr"="Redmi 9i"
        "lime"="Redmi 9T"
        "pine"="Redmi 9A / Redmi 7A"
        "carbon"="Redmi 10"
        "selene"="Redmi 10 2022"
        "wind"="Redmi 10C"
        "dawn"="Redmi 10A"
        "ice"="Redmi 12C"
        "sky"="Redmi 12"
        "xaga"="Redmi K50 Pro"
        "zeus"="Redmi K50"
        "riva"="Redmi 5A"
        "tiare"="Redmi 5A (alt)"
        "land"="Redmi 3S"
        "nitrogen"="Redmi 6"
        "cereus"="Redmi 6A"
        "laurel"="Redmi 6 Pro / Mi A2 Lite"
        "clover"="Redmi 7"
        "olivewood"="Redmi 8"
        "olive"="Redmi 8A"
        "maesalong"="Redmi 8A Pro"
        "onc"="Redmi 8A Dual"
        # Xiaomi Mi / flagship
        "cmi"="Mi 10 Pro"
        "umi"="Mi 10"
        "thyme"="Mi 10S"
        "cas"="Mi 10 Ultra"
        "elish"="Mi Pad 5 Pro"
        "enuma"="Mi Pad 5 Pro 5G"
        "nabu"="Mi Pad 5"
        "pipa"="Xiaomi Pad 6"
        "apollo"="Mi 10T / Redmi K30S"
        "apollo_pro"="Mi 10T Pro"
        "ingres"="Mi 11T Pro"
        "agate"="Mi 11T"
        "haydn"="Mi 11 Ultra"
        "mars"="Mi 11X Pro"
        "venus"="Mi 11 Pro"
        "raphael"="Mi 9T Pro"
        "davinci"="Mi 9T"
        "cepheus"="Mi 9"
        "flame"="Mi 9 SE"
        "grus"="Mi 9 SE (alt)"
        "pyxis"="Mi CC9"
        "tucana"="Mi 9 Lite"
        "crux"="Mi 9 Pro 5G"
        "pisces"="Mi 3"
        "cancro"="Mi 4"
        "libra"="Mi 4C"
        "prada"="Mi 4 LTE"
        "sagit"="Mi 6X / Mi A2"
        "wayne"="Mi 6X"
        "tissot"="Mi A1"
        "daisy"="Mi A2 Lite"
        "jasmine"="Mi A2"
        "pond"="Mi A3"
        # 13 series
        "fuxi"="Xiaomi 13"
        "nuwa"="Xiaomi 13 Pro"
        "ishtar"="Xiaomi 13T"
        "corot"="Xiaomi 13T Pro"
        # 14 series
        "houji"="Xiaomi 14"
        "shennong"="Xiaomi 14 Pro"
    }
    if ($map.ContainsKey($d)) { return $map[$d] }
    # fallback: si no está en la tabla devuelve el device tal cual
    return $d
}
function Invoke-Fastboot($fbArgs) {
    $fbExe = Get-FastbootExe
    if (-not $fbExe) { FbLog "[!] fastboot.exe no encontrado"; return $null }
    try {
        $argArr = $fbArgs -split "\s+" | Where-Object { $_ -ne "" }
        $result = & $fbExe $argArr 2>&1
        if ($result -is [array]) { return ($result | ForEach-Object { "$_" }) -join "`n" }
        return "$result"
    } catch { FbLog "[!] Error ejecutando fastboot: $_"; return $null }
}

# ---- Motor Fastboot live (linea a linea en tiempo real, para flash/wipe) ----
function Invoke-FastbootLive($fbArgs) {
    $fbExe = Get-FastbootExe
    if (-not $fbExe) { FbLog "[!] fastboot.exe no encontrado"; return -1 }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $fbExe
        $psi.Arguments              = $fbArgs
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $errQ = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        $p.add_ErrorDataReceived({ param($s,$e); if ($e.Data) { $errQ.Enqueue($e.Data) } })
        $p.Start() | Out-Null
        $p.BeginErrorReadLine()

        # Registrar proceso activo para STOP
        $script:FB_ACTIVE_PROC = $p
        if ($Global:fbBtnStop) {
            $Global:fbBtnStop.Enabled = $true
            $Global:fbBtnStop.Text    = "STOP"
        }

        while (-not $p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            if ($line.Trim()) { FbLog "  $line" }
            $eq = ""
            while ($errQ.TryDequeue([ref]$eq)) { if ($eq.Trim()) { FbLog "  $eq" } }
            [System.Windows.Forms.Application]::DoEvents()
            if ($p.HasExited) { break }
        }
        $p.WaitForExit()
        $eq = ""
        while ($errQ.TryDequeue([ref]$eq)) { if ($eq.Trim()) { FbLog "  $eq" } }
        return $p.ExitCode
    } catch { FbLog "[!] Error: $_"; return -1 }
    finally {
        $script:FB_ACTIVE_PROC = $null
        if ($Global:fbBtnStop) {
            $Global:fbBtnStop.Enabled = $false
            $Global:fbBtnStop.Text    = "STOP"
        }
    }
}

# ---- Helper: obtener fastboot.exe path (busca en todas las rutas conocidas) ----
function Get-FastbootExe {
    $candidates = @(
        (Join-Path $script:TOOLS_DIR "fastboot.exe"),
        (Join-Path $script:SCRIPT_ROOT "fastboot.exe"),
        ".\fastboot.exe",
        "$env:ProgramFiles\Minimal ADB and Fastboot\fastboot.exe",
        "${env:ProgramFiles(x86)}\Minimal ADB and Fastboot\fastboot.exe",
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\fastboot.exe",
        "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\fastboot.exe",
        "C:\platform-tools\fastboot.exe",
        "C:\adb\fastboot.exe",
        "C:\android\platform-tools\fastboot.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c -EA SilentlyContinue)) { return $c }
    }
    # Buscar en PATH
    foreach ($dir in ($env:PATH -split ";")) {
        $full = Join-Path $dir.Trim() "fastboot.exe"
        if (Test-Path $full -EA SilentlyContinue) { return $full }
    }
    # Ultimo recurso: Get-Command
    try { $gc = Get-Command "fastboot" -EA SilentlyContinue; if ($gc) { return $gc.Source } } catch {}
    return $null
}

# FbLog — definido en 09_logger.ps1

# ---- Leer info completa del dispositivo fastboot ----
function Get-FastbootDeviceInfo {
    FbLog "[~] Ejecutando fastboot devices..."
    $devOut = Invoke-Fastboot "devices"
    if (-not $devOut -or $devOut -notmatch "\tfastboot") {
        FbLog "[!] No se detecta dispositivo en modo Fastboot"
        FbLog "    Conecta el equipo y ejecuta:  adb reboot bootloader"
        return $null
    }

    $serial = ($devOut -split "\t")[0].Trim()
    FbLog "[+] Dispositivo detectado: $serial"
    FbLog "[~] Leyendo variables (getvar all)..."
    $allVars = Invoke-Fastboot "getvar all"

    $info = @{
        Serial           = $serial
        Product          = "UNKNOWN"
        SerialNo         = "UNKNOWN"
        VersionBoot      = "UNKNOWN"
        Unlocked         = "UNKNOWN"
        FlashingUnlocked = "UNKNOWN"
        SecureBoot       = "UNKNOWN"
        VerifiedBootState= "UNKNOWN"
        SlotCount        = "1"
        CurrentSlot      = "N/A"
        SlotSuccessA     = "UNKNOWN"
        SlotSuccessB     = "UNKNOWN"
        IsUserspace      = "no"
        BatteryVoltage   = "UNKNOWN"
        BatterySoC       = "UNKNOWN"
        MaxDownloadSize  = "UNKNOWN"
        Variant          = "UNKNOWN"
        HWRevision       = "UNKNOWN"
        CPU              = "UNKNOWN"
        Anti             = "UNKNOWN"
        Partition        = "UNKNOWN"
    }

    foreach ($line in ($allVars -split "`n")) {
        $l = $line.Trim()
        # quitar prefijo "< waiting for any device >" si aparece
        $l = $l -replace "^<[^>]+>\s*",""
        if ($l -imatch "^product\s*:\s*(.+)")                    { $info.Product          = $Matches[1].Trim() }
        if ($l -imatch "^serialno\s*:\s*(.+)")                   { $info.SerialNo         = $Matches[1].Trim() }
        if ($l -imatch "version-bootloader\s*:\s*(.+)")          { $info.VersionBoot      = $Matches[1].Trim() }
        if ($l -imatch "^unlocked\s*:\s*(.+)")                   { $info.Unlocked         = $Matches[1].Trim() }
        if ($l -imatch "flashing-unlocked\s*:\s*(.+)")           { $info.FlashingUnlocked = $Matches[1].Trim() }
        if ($l -imatch "secure-boot\s*:\s*(.+)|^secure\s*:\s*(.+)") {
            $info.SecureBoot = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "verifiedbootstate\s*:\s*(.+)")           { $info.VerifiedBootState= $Matches[1].Trim() }
        if ($l -imatch "slot-count\s*:\s*(.+)")                  { $info.SlotCount        = $Matches[1].Trim() }
        if ($l -imatch "current-slot\s*:\s*(.+)")                { $info.CurrentSlot      = $Matches[1].Trim() }
        if ($l -imatch "slot-successful:a\s*:\s*(.+)")           { $info.SlotSuccessA     = $Matches[1].Trim() }
        if ($l -imatch "slot-successful:b\s*:\s*(.+)")           { $info.SlotSuccessB     = $Matches[1].Trim() }
        if ($l -imatch "is-userspace\s*:\s*(.+)")                { $info.IsUserspace      = $Matches[1].Trim() }
        if ($l -imatch "battery-voltage\s*:\s*(.+)")             { $info.BatteryVoltage   = $Matches[1].Trim() }
        if ($l -imatch "battery-soc-ok\s*:\s*(.+)|batt.*soc\s*:\s*(.+)") {
            $info.BatterySoC = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "max-download-size\s*:\s*(.+)")           { $info.MaxDownloadSize  = $Matches[1].Trim() }
        if ($l -imatch "^variant\s*:\s*(.+)")                    { $info.Variant          = $Matches[1].Trim() }
        if ($l -imatch "hw-revision\s*:\s*(.+)|hardware.*rev\s*:\s*(.+)") {
            $info.HWRevision = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "^cpu\s*:\s*(.+)|processor\s*:\s*(.+)")  {
            $info.CPU = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "^anti\s*:\s*(.+)")                       { $info.Anti             = $Matches[1].Trim() }
        if ($l -imatch "partition-type:userdata\s*:\s*(.+)")     { $info.Partition        = $Matches[1].Trim() }
    }

    # Si serialno no vino de getvar all, usar el que ya tenemos de devices
    if ($info.SerialNo -eq "UNKNOWN" -or $info.SerialNo -eq "") {
        $info.SerialNo = $serial
    }
    return $info
}

# ---- Check: dispositivo fastboot disponible ----
function Check-Fastboot {
    $fbExe = Get-FastbootExe
    if (-not $fbExe) {
        FbLog "[!] fastboot.exe no encontrado."
        FbLog "    Buscado en: tools\, Minimal ADB, platform-tools, PATH"
        FbLog "    Coloca fastboot.exe en la carpeta tools\ del script"
        return $false
    }
    $devOut = Invoke-Fastboot "devices"
    if (-not $devOut -or $devOut -notmatch "\tfastboot") {
        FbLog "[!] No hay dispositivo en modo Fastboot."
        FbLog "    Ejecuta: adb reboot bootloader"
        FbLog "    O mantén Vol- al encender (depende del modelo)"
        return $false
    }
    return $true
}

# ---- Flash de una particion con selector de archivo ----
function Start-FastbootFlash($partition, $btnRef, $btnLabel) {
    if (-not (Check-Fastboot)) { return }
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter = "Imagen ($partition) (*.img)|*.img|Todos los archivos|*.*"
    $fd.Title  = "Selecciona imagen para: $partition"
    if ($fd.ShowDialog() -ne "OK") { return }
    $imgPath = $fd.FileName
    $imgName = [System.IO.Path]::GetFileName($imgPath)

    # Detectar slot activo para A/B
    $slotArg = ""
    $slotSel = $Global:cmbSlot.Text
    if ($slotSel -eq "A")   { $slotArg = "--slot a" }
    if ($slotSel -eq "B")   { $slotArg = "--slot b" }
    if ($slotSel -eq "ALL") { $slotArg = "--slot all" }

    FbLog ""
    FbLog "[*] ====================================="
    FbLog "[*]  FLASH  ->  $($partition.ToUpper())"
    FbLog "[*] ====================================="
    FbLog "[+] Archivo : $imgName"
    if ($slotArg) { FbLog "[+] Slot    : $slotSel" }
    FbLog ""

    $btnRef.Enabled = $false; $btnRef.Text = "FLASHEANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $args = "flash $slotArg $partition `"$imgPath`""
        $ec = Invoke-FastbootLive $args.Trim()
        if ($ec -eq 0) {
            FbLog ""
            FbLog "[OK] Flash $partition completado exitosamente."
        } else {
            FbLog ""
            FbLog "[!] Flash termino con codigo: $ec"
        }
    } catch { FbLog "[!] Error: $_" }
    finally { $btnRef.Enabled = $true; $btnRef.Text = $btnLabel }
}

# ===== CONSTRUCCION UI TAB FASTBOOT =====
# Layout: 2 columnas simetricas
#   Col izq  x=6   ancho=422 : G1 Deteccion, G2 Gestion BL, G3 Flash, G4 Wipe
#   Col der  x=436 ancho=422 : STOP (28px) + Log (altura restante)
# Botones: BW=195 BH=50 — misma familia que ADB/Generales
# Calculo col izq:
#   G1 (1 fila)  h=88   G2 (BL+sep+Moto) h=196  G3 (Flash+ctrl) h=183  G4 (Wipe 2 filas) h=148
#   Total: 88+8+196+8+183+8+148 = 639  -> reducir BH a 46 y ajustar gaps para caber en 618
# Con BH=44:
#   G1=82  G2=187  G3=174  G4=140  gaps=3*8=24  total=607  OK (margen inf 11px)
# ---------------------------------------------------------------
$tabFb           = New-Object Windows.Forms.TabPage
$tabFb.Text      = "FASTBOOT"
$tabFb.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$tabs.TabPages.Add($tabFb)

$FB_PAD  = 6
$FB_GW   = 422
$FB_GAP  = 8
$FB_BW   = 195
$FB_BH   = 44
$FB_PX   = 12
$FB_PY   = 18
$FB_GX   = 8
$FB_GY   = 6
$FB_BFULL = $FB_BW*2 + $FB_GX
$FB_COL2  = $FB_PAD + $FB_GW + $FB_GAP   # x=436

# ---- COLUMNA IZQUIERDA ----

# Grupo 1: Deteccion — 3 botones en 1 fila (Leer / Slots / Reboot▾)
$fbG1H = $FB_PY + $FB_BH + 12
$fbG1 = New-GBox $tabFb "DETECCION Y STATUS" $FB_PAD $FB_PAD $FB_GW $fbG1H "Cyan"
$FB_BW3 = [int](($FB_BFULL - 2*$FB_GX) / 3)
$fbBtnLeer   = New-FlatBtn $fbG1 "LEER INFO FASTBOOT" "Cyan" $FB_PX                        $FB_PY $FB_BW3 $FB_BH
$fbBtnSlots  = New-FlatBtn $fbG1 "VER SLOTS A/B"      "Cyan" ($FB_PX+$FB_BW3+$FB_GX)      $FB_PY $FB_BW3 $FB_BH
$fbBtnReboot = New-FlatBtn $fbG1 "REBOOT  ▾"          "Cyan" ($FB_PX+2*($FB_BW3+$FB_GX))  $FB_PY $FB_BW3 $FB_BH

# ContextMenuStrip para el boton REBOOT
$ctxReboot = New-Object System.Windows.Forms.ContextMenuStrip
$ctxReboot.BackColor = [System.Drawing.Color]::FromArgb(28,28,28)
$ctxReboot.ForeColor = [System.Drawing.Color]::Cyan
$ctxReboot.Font      = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
function Add-RbItem($txt,$clr) {
    $it = $ctxReboot.Items.Add($txt)
    $it.ForeColor = [System.Drawing.Color]::$clr
    $it.Font      = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    return $it
}
$rbItemSys = Add-RbItem "Sistema (reboot)"       "Cyan"
$rbItemRec = Add-RbItem "Recovery"               "Cyan"
$rbItemBl  = Add-RbItem "Bootloader"             "Cyan"
$rbItemFbd = Add-RbItem "Fastbootd (userspace)"  "Cyan"
$rbItemEdl = Add-RbItem "EDL / Download Mode"    "Orange"

$fbBtnReboot.Add_Click({
    $ctxReboot.Show($fbBtnReboot, 0, $fbBtnReboot.Height)
})

$fbBtnRbSys = $rbItemSys
$fbBtnRbRec = $rbItemRec
$fbBtnRbBl  = $rbItemBl
$fbBtnRbFbd = $rbItemFbd
$fbBtnRbEdl = $rbItemEdl

# Grupo 2: Gestion BL + Motorola
$fbG2Y = $FB_PAD + $fbG1H + $FB_GAP
$fbG2H = $FB_PY + ($FB_BH+$FB_GY) + ($FB_BH+$FB_GY) + 14 + $FB_BH + 12
$fbG2 = New-GBox $tabFb "GESTION BOOTLOADER" $FB_PAD $fbG2Y $FB_GW $fbG2H "Orange"
$fbBtnUnlk = New-FlatBtn $fbG2 "UNLOCK BL"  "Orange"  $FB_PX                   $FB_PY                     $FB_BW $FB_BH
$fbBtnLock = New-FlatBtn $fbG2 "LOCK BL"    "Orange" ($FB_PX+$FB_BW+$FB_GX)   $FB_PY                     $FB_BW $FB_BH
$fbBtnOemU = New-FlatBtn $fbG2 "OEM UNLOCK" "Orange"  $FB_PX                  ($FB_PY+$FB_BH+$FB_GY)  $FB_BFULL $FB_BH

$fbSepY = $FB_PY + 2*($FB_BH+$FB_GY) + 4
$fbSepMoto           = New-Object Windows.Forms.Panel
$fbSepMoto.Location  = New-Object System.Drawing.Point($FB_PX, $fbSepY)
$fbSepMoto.Size      = New-Object System.Drawing.Size($FB_BFULL, 1)
$fbSepMoto.BackColor = [System.Drawing.Color]::FromArgb(70,70,70)
$fbG2.Controls.Add($fbSepMoto)

$fbLblMoto           = New-Object Windows.Forms.Label
$fbLblMoto.Text      = "MOTOROLA"
$fbLblMoto.Location  = New-Object System.Drawing.Point($FB_PX, ($fbSepY+4))
$fbLblMoto.AutoSize  = $true
$fbLblMoto.ForeColor = [System.Drawing.Color]::FromArgb(200,140,60)
$fbLblMoto.Font      = New-Object System.Drawing.Font("Segoe UI",7,[System.Drawing.FontStyle]::Bold)
$fbG2.Controls.Add($fbLblMoto)

$fbMotoCodeY = $fbSepY + 14
$fbBtnMotoCode = New-FlatBtn $fbG2 "OBTENER UNLOCK CODE" "Orange" $FB_PX $fbMotoCodeY $FB_BFULL $FB_BH

# Grupo 3: Flash de particiones
$fbG3Y = $fbG2Y + $fbG2H + $FB_GAP
$fbG3H = $FB_PY + 2*($FB_BH+$FB_GY) + 30 + 10
$fbG3 = New-GBox $tabFb "FLASH DE PARTICIONES" $FB_PAD $fbG3Y $FB_GW $fbG3H "Lime"
$fbBtnFlBoot = New-FlatBtn $fbG3 "FLASH BOOT.IMG"        "Lime"  $FB_PX                   $FB_PY                   $FB_BW $FB_BH
$fbBtnFlRec  = New-FlatBtn $fbG3 "FLASH RECOVERY.IMG"    "Lime" ($FB_PX+$FB_BW+$FB_GX)   $FB_PY                   $FB_BW $FB_BH
$fbBtnFlOpc  = New-FlatBtn $fbG3 "FLASH OPCUST.IMG"      "Lime"  $FB_PX                  ($FB_PY+$FB_BH+$FB_GY)   $FB_BW $FB_BH
$fbBtnFlFree = New-FlatBtn $fbG3 "FLASH PARTICION LIBRE" "Lime" ($FB_PX+$FB_BW+$FB_GX)  ($FB_PY+$FB_BH+$FB_GY)   $FB_BW $FB_BH

$fbCtrlY = $FB_PY + 2*($FB_BH+$FB_GY) + 6
$fbLblSlot           = New-Object Windows.Forms.Label
$fbLblSlot.Text      = "SLOT:"
$fbLblSlot.Location  = New-Object System.Drawing.Point($FB_PX, ($fbCtrlY+5))
$fbLblSlot.AutoSize  = $true
$fbLblSlot.ForeColor = [System.Drawing.Color]::Lime
$fbLblSlot.Font      = New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold)
$fbG3.Controls.Add($fbLblSlot)

$Global:cmbSlot           = New-Object Windows.Forms.ComboBox
$Global:cmbSlot.Location  = New-Object System.Drawing.Point(($FB_PX+42), $fbCtrlY)
$Global:cmbSlot.Size      = New-Object System.Drawing.Size(68, 24)
$Global:cmbSlot.FlatStyle = "Flat"
$Global:cmbSlot.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
$Global:cmbSlot.ForeColor = [System.Drawing.Color]::Lime
$Global:cmbSlot.Font      = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
$Global:cmbSlot.DropDownStyle = "DropDownList"
@("AUTO","A","B","ALL") | ForEach-Object { $Global:cmbSlot.Items.Add($_) | Out-Null }
$Global:cmbSlot.SelectedIndex = 0
$fbG3.Controls.Add($Global:cmbSlot)

$fbBtnBlStatus           = New-Object Windows.Forms.Button
$fbBtnBlStatus.Text      = "ESTADO BL"
$fbBtnBlStatus.Location  = New-Object System.Drawing.Point(($FB_PX+120), $fbCtrlY)
$fbBtnBlStatus.Size      = New-Object System.Drawing.Size(106, 24)
$fbBtnBlStatus.FlatStyle = "Flat"
$fbBtnBlStatus.ForeColor = [System.Drawing.Color]::Cyan
$fbBtnBlStatus.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
$fbBtnBlStatus.FlatAppearance.BorderColor = [System.Drawing.Color]::Cyan
$fbBtnBlStatus.Font      = New-Object System.Drawing.Font("Segoe UI",7,[System.Drawing.FontStyle]::Bold)
$fbG3.Controls.Add($fbBtnBlStatus)

# Grupo 4: Wipe / Avanzado — columna IZQUIERDA, debajo de Flash
$fbG4Y = $fbG3Y + $fbG3H + $FB_GAP
$fbG4H = $FB_PY + 2*($FB_BH+$FB_GY) - $FB_GY + 12
$fbG4 = New-GBox $tabFb "WIPE / AVANZADO" $FB_PAD $fbG4Y $FB_GW $fbG4H "Red"
$fbBtnWpUsr = New-FlatBtn $fbG4 "WIPE USERDATA"   "Red"  $FB_PX                  $FB_PY                  $FB_BW $FB_BH
$fbBtnFmtDt = New-FlatBtn $fbG4 "FORMAT DATA"     "Red" ($FB_PX+$FB_BW+$FB_GX)  $FB_PY                  $FB_BW $FB_BH
$fbBtnErase = New-FlatBtn $fbG4 "ERASE PARTICION" "Red"  $FB_PX                 ($FB_PY+$FB_BH+$FB_GY)  $FB_BW $FB_BH
$fbBtnWpCch = New-FlatBtn $fbG4 "WIPE CACHE"      "Red" ($FB_PX+$FB_BW+$FB_GX) ($FB_PY+$FB_BH+$FB_GY)  $FB_BW $FB_BH

# ---- COLUMNA DERECHA — solo STOP + Log (altura total) ----
$fbStopH   = 28
$fbStopGap = 4
$fbLogReal = $FB_PAD + $fbStopH + $fbStopGap
$fbLogH    = 628 - $fbLogReal - $FB_PAD

$fbBtnStop           = New-Object Windows.Forms.Button
$fbBtnStop.Text      = "STOP"
$fbBtnStop.Location  = New-Object System.Drawing.Point($FB_COL2, $FB_PAD)
$fbBtnStop.Size      = New-Object System.Drawing.Size($FB_GW, $fbStopH)
$fbBtnStop.FlatStyle = "Flat"
$fbBtnStop.ForeColor = [System.Drawing.Color]::White
$fbBtnStop.BackColor = [System.Drawing.Color]::FromArgb(45,20,20)
$fbBtnStop.FlatAppearance.BorderColor = [System.Drawing.Color]::White
$fbBtnStop.Font      = New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)
$fbBtnStop.Enabled   = $false
$tabFb.Controls.Add($fbBtnStop)

$Global:logFb           = New-Object Windows.Forms.TextBox
$Global:logFb.Multiline = $true
$Global:logFb.Location  = New-Object System.Drawing.Point($FB_COL2, $fbLogReal)
$Global:logFb.Size      = New-Object System.Drawing.Size($FB_GW, $fbLogH)
$Global:logFb.BackColor = "Black"
$Global:logFb.ForeColor = [System.Drawing.Color]::Cyan
$Global:logFb.BorderStyle = "FixedSingle"
$Global:logFb.ScrollBars  = "Vertical"
$Global:logFb.Font        = New-Object System.Drawing.Font("Consolas", 8.5)
$Global:logFb.ReadOnly    = $true
$tabFb.Controls.Add($Global:logFb)
# Context menu: Limpiar Log
$ctxFb = New-Object System.Windows.Forms.ContextMenuStrip
$mnuClearFb = $ctxFb.Items.Add("Limpiar Log")
$mnuClearFb.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$mnuClearFb.ForeColor = [System.Drawing.Color]::OrangeRed
$mnuClearFb.Add_Click({ $Global:logFb.Clear() })
$Global:logFb.ContextMenuStrip = $ctxFb

$script:FB_ACTIVE_PROC = $null
$Global:fbBtnStop      = $fbBtnStop


#==========================================================================
# LOGICA - TAB FASTBOOT
#==========================================================================

# ---- STOP ----
$fbBtnStop.Add_Click({
    if ($script:FB_ACTIVE_PROC -and -not $script:FB_ACTIVE_PROC.HasExited) {
        try {
            $script:FB_ACTIVE_PROC.Kill()
            FbLog ""
            FbLog "[!] Proceso fastboot detenido por el usuario."
        } catch { FbLog "[!] No se pudo detener el proceso: $_" }
    } else {
        FbLog "[~] No hay proceso activo que detener."
    }
    $fbBtnStop.Enabled = $false
})

# ---- LEER INFO FASTBOOT  (proceso directo con archivos temp + timer, no bloquea UI) ----
# Start-Job aísla el proceso hijo del contexto USB/driver de la sesión interactiva.
# Solución: lanzar fastboot.exe directamente desde el hilo principal redirigiendo
# stdout y stderr a archivos temporales, y pollear con un timer hasta que termine.
$script:FB_LEER_PROC  = $null
$script:FB_LEER_TIMER = $null
$script:FB_LEER_TMP   = $null

$fbBtnLeer.Add_Click({
    if ($script:FB_LEER_PROC -and -not $script:FB_LEER_PROC.HasExited) { return }

    $fbBtnLeer.Enabled = $false; $fbBtnLeer.Text = "LEYENDO..."
    $Global:logFb.Clear()
    FbLog "[~] Buscando fastboot.exe..."
    [System.Windows.Forms.Application]::DoEvents()

    $fbExe = Get-FastbootExe
    if (-not $fbExe) {
        FbLog "[!] fastboot.exe no encontrado."
        FbLog "    Buscado en: tools\, Minimal ADB, platform-tools, PATH"
        $fbBtnLeer.Enabled = $true; $fbBtnLeer.Text = "LEER INFO FASTBOOT"
        return
    }
    FbLog "[+] fastboot.exe : $fbExe"
    FbLog "[~] Leyendo dispositivo..."
    [System.Windows.Forms.Application]::DoEvents()

    # Invocar fastboot directamente con el operador & de PowerShell.
    # Este es el UNICO metodo que hereda el contexto USB de la sesion interactiva.
    # ProcessStartInfo y Start-Job crean procesos hijos aislados que no ven el driver.
    # El operador & ejecuta en el mismo proceso PS, con los mismos handles de sesion.
    function RunFbDirect($exe, $fbArgs) {
        try {
            $argArr = $fbArgs -split "\s+" | Where-Object { $_ -ne "" }
            $result = & $exe $argArr 2>&1
            if ($result -is [array]) { return ($result | ForEach-Object { "$_" }) -join "`n" }
            return "$result"
        } catch { return "" }
    }

    # Paso 1: version
    $ver = RunFbDirect $fbExe "--version"

    # Paso 2: devices
    $devOut = RunFbDirect $fbExe "devices"

    # Filtrar lineas de dispositivos reales
    $deviceLines = ($devOut -split "`n") | Where-Object {
        $l = $_.Trim()
        $l -ne "" -and
        $l -notmatch "^List of devices" -and
        $l -notmatch "^fastboot\.exe" -and
        $l -notmatch "^<" -and
        ($l -match "\tfastboot$" -or $l -match "\s+fastboot$" -or $l -match "fastboot$")
    }

    if ($deviceLines.Count -eq 0) {
        FbLog "[!] No se detecta dispositivo en modo Fastboot"
        FbLog "[~] Asegurate de que el equipo este en Fastboot Mode"
        $fbBtnLeer.Enabled = $true; $fbBtnLeer.Text = "LEER INFO FASTBOOT"
        return
    }

    # Serial: todo lo que hay ANTES de la palabra "fastboot" al final de la linea
    # La linea tiene formato: "cf92c6f7\tfastboot" o "cf92c6f7 fastboot"
    $firstLine = $deviceLines[0].Trim()
    $serial = ($firstLine -replace "\s*fastboot\s*$","").Trim()
    if (-not $serial) { $serial = ($firstLine -split "[\t ]+")[0].Trim() }

    FbLog "[+] Dispositivo : $serial"
    FbLog "[~] Leyendo variables (getvar all)..."
    [System.Windows.Forms.Application]::DoEvents()

    # Paso 3: getvar all
    $allVars = RunFbDirect $fbExe "getvar all"

    # Parsear variables
    $info = @{
        Ver=$ver; Serial=$serial; FbExe=$fbExe
        Product="UNKNOWN"; SerialNo=$serial; VersionBoot="UNKNOWN"
        Unlocked="UNKNOWN"; FlashingUnlocked="UNKNOWN"
        SecureBoot="UNKNOWN"; VerifiedBootState="UNKNOWN"
        SlotCount="1"; CurrentSlot="N/A"
        SlotSuccessA="UNKNOWN"; SlotSuccessB="UNKNOWN"
        IsUserspace="no"; BatteryVoltage="UNKNOWN"; BatterySoC="UNKNOWN"
        MaxDownloadSize="UNKNOWN"; Variant="UNKNOWN"
        HWRevision="UNKNOWN"; CPU="UNKNOWN"; Anti="UNKNOWN"; Partition="UNKNOWN"
    }

    foreach ($line in ($allVars -split "`n")) {
        # Limpiar prefijos comunes:
        # formato nuevo:   "product: a52q"
        # formato antiguo: "(bootloader) product: a52q"
        # formato stderr:  "< waiting for device >"  <- ignorar
        $l = $line.Trim()
        $l = $l -replace "^<[^>]+>\s*",""          # quitar < waiting for device >
        $l = $l -replace "^\(bootloader\)\s*",""   # quitar (bootloader)
        $l = $l -replace "^OKAY\s*",""             # quitar OKAY
        $l = $l -replace "^INFO\s*",""             # quitar INFO
        $l = $l.Trim()
        if ($l -eq "") { continue }

        if ($l -imatch "^product\s*:\s*(.+)")                    { $info.Product          = ($Matches[1] -replace "\s+"," ").Trim() }
        if ($l -imatch "^serialno\s*:\s*(.+)")                   { $info.SerialNo         = ($Matches[1] -replace "\s+"," ").Trim() }
        if ($l -imatch "version-bootloader\s*:\s*(.+)")          { $info.VersionBoot      = ($Matches[1] -replace "\s+"," ").Trim() }
        if ($l -imatch "^unlocked\s*:\s*(.+)")                   { $info.Unlocked         = $Matches[1].Trim() }
        if ($l -imatch "flashing-unlocked\s*:\s*(.+)")           { $info.FlashingUnlocked = $Matches[1].Trim() }
        if ($l -imatch "secure-boot\s*:\s*(.+)|^secure\s*:\s*(.+)") {
            $info.SecureBoot = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "verifiedbootstate\s*:\s*(.+)")           { $info.VerifiedBootState= $Matches[1].Trim() }
        if ($l -imatch "slot-count\s*:\s*(.+)")                  { $info.SlotCount        = $Matches[1].Trim() }
        if ($l -imatch "current-slot\s*:\s*(.+)")                { $info.CurrentSlot      = $Matches[1].Trim() }
        if ($l -imatch "slot-successful:a\s*:\s*(.+)")           { $info.SlotSuccessA     = $Matches[1].Trim() }
        if ($l -imatch "slot-successful:b\s*:\s*(.+)")           { $info.SlotSuccessB     = $Matches[1].Trim() }
        if ($l -imatch "is-userspace\s*:\s*(.+)")                { $info.IsUserspace      = $Matches[1].Trim() }
        if ($l -imatch "battery-voltage\s*:\s*(.+)")             { $info.BatteryVoltage   = $Matches[1].Trim() }
        if ($l -imatch "battery-soc-ok\s*:\s*(.+)|batt.*soc\s*:\s*(.+)") {
            $info.BatterySoC = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "max-download-size\s*:\s*(.+)")           { $info.MaxDownloadSize  = $Matches[1].Trim() }
        if ($l -imatch "^variant\s*:\s*(.+)")                    { $info.Variant          = ($Matches[1] -replace "\s+"," ").Trim() }
        if ($l -imatch "hw-revision\s*:\s*(.+)|hardware.*rev\s*:\s*(.+)") {
            $info.HWRevision = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "^cpu\s*:\s*(.+)|processor\s*:\s*(.+)") {
            $info.CPU = if ($Matches[1]) {$Matches[1].Trim()} else {$Matches[2].Trim()}
        }
        if ($l -imatch "^anti\s*:\s*(.+)")                       { $info.Anti             = $Matches[1].Trim() }
        if ($l -imatch "partition-type:userdata\s*:\s*(.+)")     { $info.Partition        = $Matches[1].Trim() }
    }

    # Mostrar resultados
    $blUnlocked = ($info.Unlocked -imatch "yes|true|1") -or ($info.FlashingUnlocked -imatch "yes|true|1")
    $blStr      = if ($blUnlocked) { "UNLOCKED" } else { "LOCKED" }
    $modoFb     = if ($info.IsUserspace -imatch "yes|true") { "FASTBOOTD (userspace)" } else { "FASTBOOT clasico" }
    $hasAB      = ($info.SlotCount -match "2")

    if ($info.Ver) { FbLog "[+] version      : $(($info.Ver -split "`n")[0].Trim())" }
    FbLog ""
    FbLog "=============================================="
    FbLog "  INFO DISPOSITIVO  -  FASTBOOT"
    FbLog "=============================================="
    FbLog ""
    FbLog "  PRODUCTO         : $($info.Product)"
    FbLog "  SERIAL           : $($info.SerialNo)"
    if ($info.Variant    -ne "UNKNOWN" -and $info.Variant    -ne "") { FbLog "  VARIANTE         : $($info.Variant)"    }
    if ($info.HWRevision -ne "UNKNOWN" -and $info.HWRevision -ne "") { FbLog "  HW REVISION      : $($info.HWRevision)" }
    if ($info.CPU        -ne "UNKNOWN" -and $info.CPU        -ne "") { FbLog "  CPU              : $($info.CPU)"        }
    FbLog ""
    FbLog "  BOOTLOADER       : $($info.VersionBoot)"
    FbLog "  BL STATUS        : $blStr"
    if ($info.FlashingUnlocked  -ne "UNKNOWN" -and $info.FlashingUnlocked  -ne "") { FbLog "  FLASHING UNLOCK  : $($info.FlashingUnlocked)"  }
    if ($info.SecureBoot        -ne "UNKNOWN" -and $info.SecureBoot        -ne "") { FbLog "  SECURE BOOT      : $($info.SecureBoot)"        }
    if ($info.VerifiedBootState -ne "UNKNOWN" -and $info.VerifiedBootState -ne "") { FbLog "  VERIFIED BOOT    : $($info.VerifiedBootState)"  }
    if ($info.Anti              -ne "UNKNOWN" -and $info.Anti              -ne "") { FbLog "  ANTI-ROLLBACK    : $($info.Anti)"               }
    FbLog ""
    FbLog "  MODO ACTUAL      : $modoFb"
    FbLog "  SLOTS A/B        : $(if ($hasAB) { 'SI  (2 slots)' } else { 'NO  (slot unico)' })"
    if ($hasAB) {
        FbLog "  SLOT ACTIVO      : $($info.CurrentSlot)"
        if ($info.SlotSuccessA -ne "UNKNOWN" -and $info.SlotSuccessA -ne "") { FbLog "  SLOT-A OK        : $($info.SlotSuccessA)" }
        if ($info.SlotSuccessB -ne "UNKNOWN" -and $info.SlotSuccessB -ne "") { FbLog "  SLOT-B OK        : $($info.SlotSuccessB)" }
    }
    FbLog ""
    if ($info.BatteryVoltage  -ne "UNKNOWN" -and $info.BatteryVoltage  -ne "") { FbLog "  BATERIA VOLTAJE  : $($info.BatteryVoltage)"  }
    if ($info.BatterySoC      -ne "UNKNOWN" -and $info.BatterySoC      -ne "") { FbLog "  BATERIA SOC OK   : $($info.BatterySoC)"      }
    if ($info.MaxDownloadSize -ne "UNKNOWN" -and $info.MaxDownloadSize -ne "") {
        $dlSize = $info.MaxDownloadSize
        try {
            $dlBytes = if ($dlSize -match "^0x") { [Convert]::ToInt64($dlSize,16) } else { [long]$dlSize }
            $dlMB = [math]::Round($dlBytes / 1MB)
            $dlSize = "$dlMB MB"
        } catch {}
        FbLog "  MAX DL SIZE      : $dlSize"
    }
    if ($info.Partition -ne "UNKNOWN" -and $info.Partition -ne "") { FbLog "  USERDATA TYPE    : $($info.Partition)" }
    FbLog ""
    FbLog "=============================================="
    FbLog "[OK] LECTURA COMPLETADA"

    # Actualizar sidebar
    $Global:lblModo.Text      = "MODO        : FASTBOOT"
    $Global:lblModo.ForeColor = [System.Drawing.Color]::Yellow
    $Global:lblDisp.Text      = "DISPOSITIVO : $($info.Product)"
    $Global:lblSerial.Text    = "SERIAL      : $($info.SerialNo)"
    $Global:lblFRP.Text       = "BL          : $blStr"
    $Global:lblFRP.ForeColor  = if ($blUnlocked) { [System.Drawing.Color]::Lime } else { [System.Drawing.Color]::Red }
    $Global:lblStatus.Text    = "  RNX TOOL PRO v2.3  |  FASTBOOT  |  $($info.Product)  $($info.SerialNo)"

    $fbBtnLeer.Enabled = $true; $fbBtnLeer.Text = "LEER INFO FASTBOOT"
})

# ---- VER SLOTS A/B ----
$fbBtnSlots.Add_Click({
    $fbBtnSlots.Enabled = $false; $fbBtnSlots.Text = "LEYENDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        if (-not (Check-Fastboot)) { return }
        FbLog ""
        FbLog "[*] ===  INFO SLOTS A/B  ==="
        $vars = @(
            "slot-count","current-slot",
            "slot-successful:a","slot-successful:b",
            "slot-unbootable:a","slot-unbootable:b",
            "slot-retry-count:a","slot-retry-count:b"
        )
        foreach ($v in $vars) {
            $val = Invoke-Fastboot "getvar $v"
            $clean = ($val -split "`n") | Where-Object { $_ -imatch $v } | Select-Object -First 1
            if (-not $clean) { $clean = $val }
            FbLog "  $v : $($clean.Trim())"
        }
        FbLog "[OK] Fin info slots"
    } catch { FbLog "[!] Error: $_" }
    finally { $fbBtnSlots.Enabled = $true; $fbBtnSlots.Text = "VER SLOTS A/B" }
})

# ---- REBOOT (items del ContextMenuStrip del boton REBOOT ▾) ----
$rbItemSys.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog "[*] Reiniciando sistema..."; Invoke-Fastboot "reboot" | Out-Null; FbLog "[OK] Enviado."
})
$rbItemRec.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog "[*] Reiniciando recovery..."; Invoke-Fastboot "reboot recovery" | Out-Null; FbLog "[OK] Enviado."
})
$rbItemBl.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog "[*] Reiniciando bootloader..."; Invoke-Fastboot "reboot bootloader" | Out-Null; FbLog "[OK] Enviado."
})
$rbItemFbd.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog "[*] Reiniciando a fastbootd (userspace)..."
    FbLog "    (Android 10+  -  habilita particiones logicas)"
    Invoke-Fastboot "reboot fastboot" | Out-Null
    FbLog "[OK] Enviado."
})
$rbItemEdl.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog "[*] Detectando chip para EDL/Download..."
    $edlOk = $false
    $r1 = Invoke-Fastboot "oem edl"
    if ($r1 -imatch "okay|OKAY") { FbLog "[OK] Modo EDL activado (Qualcomm)."; $edlOk = $true }
    if (-not $edlOk) {
        $r2 = Invoke-Fastboot "reboot download"
        if ($r2 -imatch "okay|OKAY" -or $r2 -eq "") { FbLog "[OK] Reboot Download Mode enviado (Samsung/MTK)."; $edlOk = $true }
    }
    if (-not $edlOk) { FbLog "[!] No se pudo enviar a EDL/Download. Verifica el modelo." }
})

# ---- UNLOCK BL ----
$fbBtnUnlk.Add_Click({
    if (-not (Check-Fastboot)) { return }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "ADVERTENCIA:`n`nDesbloquear el bootloader BORRARA todos los datos del dispositivo`ny puede anular la garantia.`n`n¿Confirmas que deseas continuar?",
        "UNLOCK BOOTLOADER - CONFIRMACION",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne "Yes") { FbLog "[~] Operacion cancelada por el usuario."; return }
    $fbBtnUnlk.Enabled = $false; $fbBtnUnlk.Text = "DESBLOQUEANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        FbLog ""
        FbLog "[*] ===  UNLOCK BOOTLOADER  ==="
        FbLog "[~] Ejecutando fastboot flashing unlock..."
        $ec = Invoke-FastbootLive "flashing unlock"
        if ($ec -eq 0) { FbLog "[OK] BL desbloqueado. El equipo reiniciara y borrara datos." }
        else {
            FbLog "[~] Intentando fastboot oem unlock (fallback legacy)..."
            $ec2 = Invoke-FastbootLive "oem unlock"
            if ($ec2 -eq 0) { FbLog "[OK] BL desbloqueado via oem unlock." }
            else { FbLog "[!] Unlock fallo (cod: $ec2). Verifica que OEM unlock este habilitado en Opciones de Desarrollador." }
        }
    } catch { FbLog "[!] Error: $_" }
    finally { $fbBtnUnlk.Enabled = $true; $fbBtnUnlk.Text = "UNLOCK BL" }
})

# ---- LOCK BL ----
$fbBtnLock.Add_Click({
    if (-not (Check-Fastboot)) { return }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "ADVERTENCIA:`n`nBloquear el bootloader sobre un sistema modificado`npuede dejar el dispositivo en bootloop permanente.`n`nAsegurate de tener el firmware stock original instalado.`n`n¿Confirmas?",
        "LOCK BOOTLOADER - CONFIRMACION",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne "Yes") { FbLog "[~] Operacion cancelada."; return }
    $fbBtnLock.Enabled = $false; $fbBtnLock.Text = "BLOQUEANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        FbLog ""
        FbLog "[*] ===  LOCK BOOTLOADER  ==="
        $ec = Invoke-FastbootLive "flashing lock"
        if ($ec -eq 0) { FbLog "[OK] BL bloqueado correctamente." }
        else { FbLog "[!] Lock fallo (cod: $ec)." }
    } catch { FbLog "[!] Error: $_" }
    finally { $fbBtnLock.Enabled = $true; $fbBtnLock.Text = "LOCK BL" }
})

# ---- OEM UNLOCK ----
$fbBtnOemU.Add_Click({
    if (-not (Check-Fastboot)) { return }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "fastboot oem unlock`n`nEsto borrara los datos del dispositivo.`n¿Confirmas?",
        "OEM UNLOCK",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne "Yes") { FbLog "[~] Cancelado."; return }
    FbLog ""
    FbLog "[*] ===  OEM UNLOCK  ==="
    $fbBtnOemU.Enabled = $false; $fbBtnOemU.Text = "EJECUTANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $ec = Invoke-FastbootLive "oem unlock"
        if ($ec -eq 0) { FbLog "[OK] OEM unlock ejecutado." }
        else { FbLog "[!] Fallo (cod: $ec)" }
    } catch { FbLog "[!] Error: $_" }
    finally { $fbBtnOemU.Enabled = $true; $fbBtnOemU.Text = "OEM UNLOCK" }
})

# ---- MOTOROLA: OBTENER UNLOCK CODE ----
$fbBtnMotoCode.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog ""
    FbLog "[*] ===  MOTOROLA UNLOCK CODE  ==="
    FbLog "[~] Obteniendo serial del dispositivo..."
    $serial = Invoke-Fastboot "getvar serialno"
    $sn = ($serial -split "`n") | Where-Object { $_ -imatch "serialno" } | Select-Object -First 1
    $sn = ($sn -split ":") | Select-Object -Last 1
    $sn = $sn.Trim()
    if ($sn) {
        [System.Windows.Forms.Clipboard]::SetText($sn)
        FbLog "[+] Serial    : $sn"
        FbLog "[+] Serial copiado al portapapeles"
        FbLog ""
        FbLog "[~] Pasos para obtener el codigo de desbloqueo:"
        FbLog "    1. Abre: https://motorola-global-portal.custhelp.com/app/standalone/bootloader/unlock-your-device-b"
        FbLog "    2. Inicia sesion con tu cuenta Motorola"
        FbLog "    3. Pega el serial (ya copiado): $sn"
        FbLog "    4. Acepta los terminos y obtendras el codigo"
        FbLog "    5. Usa ese codigo con: fastboot oem unlock CODIGO"
        try { Start-Process "https://motorola-global-portal.custhelp.com/app/standalone/bootloader/unlock-your-device-b" } catch {}
    } else {
        FbLog "[!] No se pudo leer el serial. Verifica que el dispositivo este en fastboot."
    }
})

# ---- FLASH BOOT.IMG ----
$fbBtnFlBoot.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 40 -NeedUnlockedBL
        Write-RNXLogSection "FLASH BOOT.IMG"
        Start-FastbootFlash "boot" $fbBtnFlBoot "FLASH BOOT.IMG"
    } catch { FbLog "[!] $_" }
})

# ---- FLASH RECOVERY.IMG ----
$fbBtnFlRec.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 40
        Write-RNXLogSection "FLASH RECOVERY.IMG"
        Start-FastbootFlash "recovery" $fbBtnFlRec "FLASH RECOVERY.IMG"
    } catch { FbLog "[!] $_" }
})

# ---- FLASH OPCUST.IMG ----
$fbBtnFlOpc.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 40
        Write-RNXLogSection "FLASH OPCUST.IMG"
        Start-FastbootFlash "opcust" $fbBtnFlOpc "FLASH OPCUST.IMG"
    } catch { FbLog "[!] $_" }
})

# ---- FLASH PARTICION LIBRE ----
$fbBtnFlFree.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 40
        if (-not (Check-Fastboot)) { return }
        Add-Type -AssemblyName Microsoft.VisualBasic
        $partName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Nombre exacto de la particion a flashear:`n(ej: system, vendor, product, modem, tz, abl...)",
            "FLASH PARTICION LIBRE",
            ""
        )
        if (-not $partName.Trim()) { FbLog "[~] Cancelado."; return }
        Write-RNXLogSection "FLASH $($partName.Trim().ToUpper())"
        Start-FastbootFlash $partName.Trim() $fbBtnFlFree "FLASH PARTICION LIBRE"
    } catch { FbLog "[!] $_" }
})

# ---- ESTADO BL ----
$fbBtnBlStatus.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog ""
    FbLog "[*] ===  ESTADO BOOTLOADER  ==="
    $v1 = Invoke-Fastboot "getvar unlocked"
    $v2 = Invoke-Fastboot "getvar flashing-unlocked"
    $unlocked = ($v1 + $v2) -imatch "yes|true"
    $blStr = if ($unlocked) { "UNLOCKED" } else { "LOCKED" }
    FbLog "[+] BL STATUS        : $blStr"
    foreach ($line in (($v1+"`n"+$v2) -split "`n")) {
        $l = $line.Trim()
        if ($l -imatch "unlock|flashing") { FbLog "    $l" }
    }
    $Global:lblFRP.Text      = "BL          : $blStr"
    $Global:lblFRP.ForeColor = if ($unlocked) { [System.Drawing.Color]::Lime } else { [System.Drawing.Color]::Red }
    FbLog "[OK] Consulta completada."
})

# ---- WIPE USERDATA ----
$fbBtnWpUsr.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 40
        if (-not (Confirm-RNXAction "WIPE USERDATA borrara TODOS los datos del usuario.`n`n¿Confirmas?" "WIPE USERDATA")) { return }
        Write-RNXLogSection "WIPE USERDATA"
        # Loguear estado antes de la operacion destructiva
        Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "FASTBOOT" }
        $fbBtnWpUsr.Enabled = $false; $fbBtnWpUsr.Text = "BORRANDO..."
        [System.Windows.Forms.Application]::DoEvents()
        FbLog ""
        FbLog "[*] ===  WIPE USERDATA  ==="
        $ec = Invoke-FastbootLive "erase userdata"
        if ($ec -eq 0) { FbLog "[OK] Userdata borrado." } else { FbLog "[!] Fallo (cod: $ec)" }
    } catch { FbLog "[!] $_" }
    finally { $fbBtnWpUsr.Enabled = $true; $fbBtnWpUsr.Text = "WIPE USERDATA" }
})

# ---- FORMAT DATA ----
$fbBtnFmtDt.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 40
        if (-not (Confirm-RNXAction "FORMAT DATA formatea userdata con ext4.`nNecesario en equipos con cifrado activo.`n`n¿Confirmas?" "FORMAT DATA")) { return }
        Write-RNXLogSection "FORMAT DATA"
        Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "FASTBOOT" }
        $fbBtnFmtDt.Enabled = $false; $fbBtnFmtDt.Text = "FORMATEANDO..."
        [System.Windows.Forms.Application]::DoEvents()
        FbLog ""
        FbLog "[*] ===  FORMAT DATA (ext4)  ==="
        $ec = Invoke-FastbootLive "format:ext4 userdata"
        if ($ec -eq 0) { FbLog "[OK] Data formateado correctamente." }
        else {
            FbLog "[~] Intentando -w (wipe alternativo)..."
            $ec2 = Invoke-FastbootLive "-w"
            if ($ec2 -eq 0) { FbLog "[OK] Wipe -w completado." } else { FbLog "[!] Fallo (cod: $ec2)" }
        }
    } catch { FbLog "[!] $_" }
    finally { $fbBtnFmtDt.Enabled = $true; $fbBtnFmtDt.Text = "FORMAT DATA" }
})

# ---- ERASE PARTICION ----
$fbBtnErase.Add_Click({
    try {
        Assert-DeviceReady -Mode FASTBOOT -MinBattery 30
        if (-not (Check-Fastboot)) { return }
        Add-Type -AssemblyName Microsoft.VisualBasic
        $partName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Nombre exacto de la particion a borrar:`n(ej: cache, metadata, persist, misc...)",
            "ERASE PARTICION",
            "cache"
        )
        if (-not $partName.Trim()) { FbLog "[~] Cancelado."; return }
        if (-not (Confirm-RNXAction "Vas a borrar la particion: $($partName.Trim())`n`n¿Confirmas?" "ERASE PARTICION")) { return }
        Write-RNXLogSection "ERASE $($partName.Trim().ToUpper())"
        Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "FASTBOOT" }
        $fbBtnErase.Enabled = $false; $fbBtnErase.Text = "BORRANDO..."
        [System.Windows.Forms.Application]::DoEvents()
        FbLog ""
        FbLog "[*] ===  ERASE $($partName.Trim().ToUpper())  ==="
        $ec = Invoke-FastbootLive "erase $($partName.Trim())"
        if ($ec -eq 0) { FbLog "[OK] Particion $($partName.Trim()) borrada." } else { FbLog "[!] Fallo (cod: $ec)" }
    } catch { FbLog "[!] $_" }
    finally { $fbBtnErase.Enabled = $true; $fbBtnErase.Text = "ERASE PARTICION" }
})

# ---- WIPE CACHE ----
$fbBtnWpCch.Add_Click({
    if (-not (Check-Fastboot)) { return }
    FbLog ""
    FbLog "[*] ===  WIPE CACHE  ==="
    $fbBtnWpCch.Enabled = $false; $fbBtnWpCch.Text = "BORRANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $ec = Invoke-FastbootLive "erase cache"
        if ($ec -eq 0) { FbLog "[OK] Cache borrado." } else { FbLog "[~] Cache no disponible en este dispositivo (cod: $ec)" }
    } catch { FbLog "[!] Error: $_" }
    finally { $fbBtnWpCch.Enabled = $true; $fbBtnWpCch.Text = "WIPE CACHE" }
})

