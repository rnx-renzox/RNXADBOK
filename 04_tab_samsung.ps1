
#==========================================================================
# VENTANA PROGRESO EXTRACCION  (aparece al arrastrar .zip/.rar/.7z/.tar)
#==========================================================================
function Show-ExtractProgress($filename) {
    $win = New-Object Windows.Forms.Form
    $win.Text = "Extrayendo..."; $win.ClientSize = New-Object System.Drawing.Size(500,170)
    $win.BackColor = [System.Drawing.Color]::FromArgb(18,18,18)
    $win.FormBorderStyle = "FixedDialog"; $win.StartPosition = "CenterScreen"
    $win.ControlBox = $false; $win.TopMost = $true

    $lbTitle = New-Object Windows.Forms.Label
    $lbTitle.Text = "EXTRAYENDO FIRMWARE"; $lbTitle.Location = New-Object System.Drawing.Point(16,14)
    $lbTitle.Size = New-Object System.Drawing.Size(468,20); $lbTitle.ForeColor = [System.Drawing.Color]::Lime
    $lbTitle.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $win.Controls.Add($lbTitle)

    $lbFile = New-Object Windows.Forms.Label
    $lbFile.Text = $filename; $lbFile.Location = New-Object System.Drawing.Point(16,38)
    $lbFile.Size = New-Object System.Drawing.Size(468,18); $lbFile.ForeColor = [System.Drawing.Color]::LightGray
    $lbFile.Font = New-Object System.Drawing.Font("Consolas",8)
    $win.Controls.Add($lbFile)

    $bar = New-Object Windows.Forms.ProgressBar
    $bar.Location = New-Object System.Drawing.Point(16,66); $bar.Size = New-Object System.Drawing.Size(468,24)
    $bar.Style = "Continuous"; $bar.Minimum = 0; $bar.Maximum = 100; $bar.Value = 0
    $win.Controls.Add($bar)

    $lbPct = New-Object Windows.Forms.Label
    $lbPct.Text = "0%"; $lbPct.Location = New-Object System.Drawing.Point(16,100)
    $lbPct.Size = New-Object System.Drawing.Size(468,18)
    $lbPct.ForeColor = [System.Drawing.Color]::Cyan
    $lbPct.Font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $lbPct.TextAlign = "MiddleCenter"; $win.Controls.Add($lbPct)

    $lbStatus = New-Object Windows.Forms.Label
    $lbStatus.Text = "Iniciando..."; $lbStatus.Location = New-Object System.Drawing.Point(16,124)
    $lbStatus.Size = New-Object System.Drawing.Size(468,18)
    $lbStatus.ForeColor = [System.Drawing.Color]::FromArgb(90,90,90)
    $lbStatus.Font = New-Object System.Drawing.Font("Consolas",7.5)
    $win.Controls.Add($lbStatus)

    $win.Show(); [System.Windows.Forms.Application]::DoEvents()
    return @{Win=$win; Bar=$bar; LblFile=$lbFile; LblPct=$lbPct; LblStatus=$lbStatus}
}

#==========================================================================
# EXTRACTOR UNIVERSAL  tar / tar.md5 / zip / rar / 7z
# Devuelve carpeta con los .img extraidos
#==========================================================================
function Expand-FirmwareFile($file, $slot) {
    $fn   = [System.IO.Path]::GetFileName($file)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($fn) -replace "\.tar$",""
    $dest = [System.IO.Path]::Combine($script:TEMP_EXTRACT, "${slot}_${base}")

    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item $dest -ItemType Directory -Force | Out-Null

    $ext    = [System.IO.Path]::GetExtension($file).ToLower()
    $isTar  = ($ext -eq ".tar" -or $ext -eq ".md5" -or $file -imatch "\.tar\.md5$")
    $isZip  = ($ext -eq ".zip")
    $is7zRar = ($ext -eq ".7z" -or $ext -eq ".rar")

    $ui = Show-ExtractProgress $fn
    $ui.LblStatus.Text = "Preparando extraccion..."; [System.Windows.Forms.Application]::DoEvents()

    try {
        if ($isTar) {
            $ui.LblStatus.Text = "Extrayendo con tar..."; $ui.Bar.Value = 10; [System.Windows.Forms.Application]::DoEvents()
            $hasTar = Get-Command tar -ErrorAction SilentlyContinue
            if ($hasTar) {
                & tar -xf "$file" -C "$dest" 2>&1 | Out-Null
                $ui.Bar.Value = 90; [System.Windows.Forms.Application]::DoEvents()
            } else {
                $tool = if (Test-Path ".\7z.exe") {".\7z.exe"} elseif (Get-Command 7z -EA SilentlyContinue) {"7z"} else {$null}
                if ($tool) {
                    $ui.LblStatus.Text = "Extrayendo con 7z..."; [System.Windows.Forms.Application]::DoEvents()
                    & $tool x "$file" "-o$dest" -y 2>&1 | Out-Null; $ui.Bar.Value = 90
                } else {
                    $ui.Win.Close(); OdinLog "[!] tar y 7z no encontrados. Instala 7-Zip."; return $null
                }
            }
        }
        elseif ($isZip) {
            $ui.LblStatus.Text = "Extrayendo ZIP..."; $ui.Bar.Value = 5; [System.Windows.Forms.Application]::DoEvents()
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::OpenRead($file)
                $total = $zip.Entries.Count; $done = 0
                foreach ($entry in $zip.Entries) {
                    $outPath = [System.IO.Path]::Combine($dest, $entry.FullName)
                    $outDir  = [System.IO.Path]::GetDirectoryName($outPath)
                    if (-not (Test-Path $outDir)) { New-Item $outDir -ItemType Directory -Force | Out-Null }
                    if (-not $entry.FullName.EndsWith("/")) {
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $outPath, $true)
                    }
                    $done++
                    $pct = [int](($done/$total)*88)+5
                    $ui.Bar.Value = [Math]::Min($pct,98)
                    $ui.LblPct.Text = "$pct%"
                    $ui.LblFile.Text = $entry.Name
                    if ($done % 3 -eq 0) { [System.Windows.Forms.Application]::DoEvents() }
                }
                $zip.Dispose()
            } catch {
                $tool = if (Test-Path ".\7z.exe") {".\7z.exe"} else {"7z"}
                $ui.LblStatus.Text = "Fallback 7z..."
                & $tool x "$file" "-o$dest" -y 2>&1 | Out-Null
            }
            $ui.Bar.Value = 90
        }
        elseif ($is7zRar) {
            $tool = if (Test-Path ".\7z.exe") {".\7z.exe"} elseif (Get-Command 7z -EA SilentlyContinue) {"7z"} else {$null}
            if (-not $tool) {
                $ui.Win.Close(); OdinLog "[!] 7z.exe no encontrado. Descarga 7-Zip y coloca 7z.exe junto al script."; return $null
            }
            $ui.LblStatus.Text = "Extrayendo con 7z ($ext)..."; $ui.Bar.Value = 15; [System.Windows.Forms.Application]::DoEvents()
            & $tool x "$file" "-o$dest" -y 2>&1 | ForEach-Object {
                if ($_ -match "(\d+)%") {
                    $pct=[int]$Matches[1]; $ui.Bar.Value=[Math]::Min(15+$pct*0.8,98); $ui.LblPct.Text="$pct%"
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
            $ui.Bar.Value = 90
        }

        # Si adentro hay otro tar / tar.md5 (firmware en zip que contiene tar)
        $innerTar = Get-ChildItem $dest -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -imatch "\.(tar|md5)$" } | Select-Object -First 1
        if ($innerTar) {
            $ui.LblStatus.Text = "Extrayendo tar interno: $($innerTar.Name)"; $ui.Bar.Value = 92
            [System.Windows.Forms.Application]::DoEvents()
            $destInner = [System.IO.Path]::Combine($dest, "imgs")
            New-Item $destInner -ItemType Directory -Force | Out-Null
            & tar -xf "$($innerTar.FullName)" -C "$destInner" 2>&1 | Out-Null
            $dest = $destInner
        }

        $ui.Bar.Value=100; $ui.LblPct.Text="100%"; $ui.LblStatus.Text="Completado"
        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 600
    } finally {
        $ui.Win.Close()
    }
    return $dest
}

#==========================================================================
# AUTO-CLASIFICADOR DE .IMG
# Lee todos los .img del directorio extraido y los clasifica en BL/AP/CP/CSC
#==========================================================================
function Auto-ClassifyImages($extractDir) {
    $r = @{BL=@(); AP=@(); CP=@(); CSC=@()}
    if (-not $extractDir -or -not (Test-Path $extractDir)) { return $r }

    $imgs = Get-ChildItem $extractDir -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -imatch "\.(img|bin)$" -and $_.Length -gt 1024 }

    foreach ($img in $imgs) {
        $n = $img.BaseName.ToLower() -replace "_[ab]$",""

        # BL: bootloader, sboot, tzsw, tz, spl, lk, abl, xbl, hyp
        if ($n -match "^(bl|bootloader|sboot|tzsw|tz|spl|lk|aboot|abl|xbl|hyp|up_param|KEYSTORAGE|keystore)") {
            $r.BL += $img.FullName
        }
        # CP: modem, radio, NON-HLOS
        elseif ($n -match "^(cp|modem|radio|NON.HLOS|apnhlos|dsp|bluetooth)") {
            $r.CP += $img.FullName
        }
        # CSC: csc, home, omr, prism, optics
        elseif ($n -match "^(csc|home|omr|prism|optics)") {
            $r.CSC += $img.FullName
        }
        # AP: boot, recovery, system, vendor, super, etc
        else {
            $r.AP += $img.FullName
        }
    }
    return $r
}

#==========================================================================
# CONSTRUIR FLAGS HEIMDALL DESDE LISTA DE .IMG
#==========================================================================
function Build-HeimdallFlags($imgList) {
    $heimArgs = ""
    foreach ($imgPath in $imgList) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($imgPath).ToLower() -replace "_[ab]$",""
        $flag = $null
        if ($script:PART_MAP.ContainsKey($name)) { $flag = $script:PART_MAP[$name] }
        else {
            foreach ($key in $script:PART_MAP.Keys) {
                if ($name -imatch $key) { $flag = $script:PART_MAP[$key]; break }
            }
        }
        if (-not $flag) { $flag = ($name.ToUpper() -replace "[^A-Z0-9_]","") }
        $fn = [System.IO.Path]::GetFileName($imgPath)
        OdinLog "    [MAP] $fn  ->  --$flag"
        $heimArgs += " --$flag `"$imgPath`""
    }
    return $heimArgs
}

#==========================================================================
# SET FIRMWARE FILE  (picker + auto-extraccion + clasificacion)
#==========================================================================
function Pick-FirmwareFile {
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Title = "Seleccionar Firmware Samsung"
    $fd.Filter = "Samsung Firmware|*.tar;*.tar.md5;*.md5;*.pit;*.zip;*.7z;*.rar|Todos|*.*"
    if ($fd.ShowDialog() -eq "OK") { return $fd.FileName }
    return $null
}

function Set-FirmwareFile($file, $forceSlot) {
    if (-not $file -or -not (Test-Path $file)) { return }
    $ext  = [System.IO.Path]::GetExtension($file).ToLower()
    $fn   = [System.IO.Path]::GetFileName($file)
    $slot = if ($forceSlot) { $forceSlot } else { Get-FirmwareAutoType $file }

    $needsExtract = ($ext -imatch "\.(zip|rar|7z)$") -or ($ext -imatch "\.(tar|md5)$") -or ($file -imatch "\.tar\.md5")

    if ($needsExtract) {
        OdinLog ""; OdinLog "[~] Archivo: $fn  (slot preferido: $slot)"
        OdinLog "[~] Extrayendo..."

        $extractDir = Expand-FirmwareFile $file $slot
        if (-not $extractDir) { return }

        OdinLog "[+] Extraccion OK -> $extractDir"
        OdinLog "[~] Clasificando particiones..."

        $imgs = Auto-ClassifyImages $extractDir

        # Si no se clasifico nada en el slot esperado, poner todo en AP
        $total = $imgs.BL.Count + $imgs.AP.Count + $imgs.CP.Count + $imgs.CSC.Count
        if ($total -eq 0) {
            OdinLog "[!] No se encontraron .img en el archivo"
            return
        }

        # Si el slot es forzado y ese slot quedo vacio, mover todo ahi
        if ($slot -ne "UNKNOWN" -and $slot -ne "AUTO" -and $imgs[$slot].Count -eq 0) {
            $allImgs = $imgs.BL + $imgs.AP + $imgs.CP + $imgs.CSC
            if ($allImgs.Count -gt 0) { $imgs[$slot] = $allImgs; $imgs.BL=@(); $imgs.AP=@(); $imgs.CP=@(); $imgs.CSC=@(); $imgs[$slot]=$allImgs }
        }

        if ($imgs.BL.Count -gt 0) {
            $script:BL_IMGS = $imgs.BL; $script:BL_FILE = $file
            $Global:txtBL.Text = "[${fn}] $($imgs.BL.Count) particion(es)"
            OdinLog "[+] BL  : $($imgs.BL.Count) particion(es)"
            foreach ($i in $imgs.BL) { OdinLog "         $([IO.Path]::GetFileName($i))" }
        }
        if ($imgs.AP.Count -gt 0) {
            $script:AP_IMGS  = $imgs.AP; $script:AP_FILE = $file
            $script:AP_PARTS = $imgs.AP | ForEach-Object { [IO.Path]::GetFileName($_) }
            $Global:txtAP.Text = "[${fn}] $($imgs.AP.Count) particion(es)"
            OdinLog "[+] AP  : $($imgs.AP.Count) particion(es)"
            foreach ($i in $imgs.AP) { OdinLog "         $([IO.Path]::GetFileName($i))" }
        }
        if ($imgs.CP.Count -gt 0) {
            $script:CP_IMGS = $imgs.CP; $script:CP_FILE = $file
            $Global:txtCP.Text = "[${fn}] $($imgs.CP.Count) particion(es)"
            OdinLog "[+] CP  : $($imgs.CP.Count) particion(es)"
        }
        if ($imgs.CSC.Count -gt 0) {
            $script:CSC_IMGS = $imgs.CSC; $script:CSC_FILE = $file
            $Global:txtCSC.Text = "[${fn}] $($imgs.CSC.Count) particion(es)"
            OdinLog "[+] CSC : $($imgs.CSC.Count) particion(es)"
        }

        $tcount = $imgs.BL.Count+$imgs.AP.Count+$imgs.CP.Count+$imgs.CSC.Count
        OdinLog ""; OdinLog "[OK] $tcount particiones clasificadas y listas"

    } else {
        # Archivo directo sin extraccion
        switch ($slot) {
            "BL"  { $script:BL_FILE=$file;  $script:BL_IMGS=@($file);  $Global:txtBL.Text=$file;  OdinLog "[+] BL  : $fn" }
            "AP"  { $script:AP_FILE=$file;  $script:AP_IMGS=@();        $script:AP_PARTS=Get-APPartitions $file
                    $Global:txtAP.Text=$file; OdinLog "[+] AP  : $fn"
                    if ($script:AP_PARTS.Count -gt 0) { OdinLog "[+] Particiones detectadas: $($script:AP_PARTS -join ', ')" }
                  }
            "CP"  { $script:CP_FILE=$file;  $script:CP_IMGS=@($file);  $Global:txtCP.Text=$file;  OdinLog "[+] CP  : $fn" }
            "CSC" { $script:CSC_FILE=$file; $script:CSC_IMGS=@($file); $Global:txtCSC.Text=$file; OdinLog "[+] CSC : $fn" }
            "PIT" { $script:PIT_FILE=$file; OdinLog "[+] PIT : $fn" }
            default { OdinLog "[?] Tipo no reconocido: $fn - arrastra al campo correcto" }
        }
    }
}


#==========================================================================
# READ ODIN INFO PRO
#==========================================================================
function Read-OdinInfoPro {
    $Global:logOdin.Clear()
    OdinLog "[*] =========================================="
    OdinLog "[*]   SAMSUNG ODIN PRO - LEER INFO DOWNLOAD"
    OdinLog "[*] =========================================="
    OdinLog ""
    OdinLog "[~] Escaneando dispositivo (WMI + PnP + Heimdall)..."
    $cpuInfo = Get-SamsungCPUInfo
    OdinLog "[+] CPU     : $($cpuInfo.CPU)  |  Modo: $($cpuInfo.MODE)  |  Proto: $($cpuInfo.PROTO)"
    if ($cpuInfo.USB_NAME) { OdinLog "[+] USB     : $($cpuInfo.USB_NAME)" }
    if ($cpuInfo.VID)      { OdinLog "[+] VID/PID : $($cpuInfo.VID)/$($cpuInfo.USBPID)" }
    if ($cpuInfo.PORT)     { OdinLog "[+] COM     : $($cpuInfo.PORT)" }
    if ($cpuInfo.HEIMDALL) { OdinLog "[+] Heimdall: CONFIRMADO" } else { OdinLog "[~] Heimdall: no confirma (normal en MTK/v4)" }
    OdinLog ""

    # Usar el resultado combinado WMI+PnP+Heimdall  -  NO rellamar heimdall detect
    $heimOK = ($cpuInfo.MODE -eq "DOWNLOAD_MODE")

    if (-not $heimOK) {
        OdinLog "[!] No se detecta dispositivo en Download Mode"
        OdinLog "    Verifica que el equipo este conectado y en DL Mode:"
        OdinLog "    - A-series moderno : Vol- + Power (mantener ~8 seg)"
        OdinLog "    - Series antiguas  : Vol- + Bixby + Power"
        OdinLog "    - Via ADB          : adb reboot download"
        OdinLog "    - Driver requerido : Samsung USB Driver v1.7.44+"
        return
    }

    # MTK: Heimdall no soporta  -  redirigir a ADB
    if ($cpuInfo.PROTO -eq "MTK") {
        OdinLog "[!] CPU MediaTek/UNISOC  -  Heimdall no compatible"
        OdinLog "[~] Intentando lectura via ADB..."; OdinLog ""
        Read-MTKInfoViaADB $cpuInfo; return
    }

    # Protocolo v4  -  advertir que Heimdall puede fallar en el flash
    if ($cpuInfo.PROTO -eq "v4") {
        OdinLog "[!] ATENCION: Equipo con protocolo Odin v4 (S22/S23 y posteriores)"
        OdinLog "[!] Heimdall 1.4.x solo soporta protocolo v3  -  la LECTURA puede funcionar"
        OdinLog "[!] pero el FLASHEO puede fallar. Usa Odin3 para flashear este equipo."
        OdinLog ""
    }

    OdinLog "[OK] Download Mode confirmado"
    OdinLog ""

    $product="UNKNOWN";$build="UNKNOWN";$csc="UNKNOWN";$cscCode="???"
    $imei="UNKNOWN";$serial="UNKNOWN";$binary="UNKNOWN"
    $kg="UNKNOWN";$frp="UNKNOWN";$oem="UNKNOWN"
    $status="UNKNOWN";$knox="UNKNOWN";$rpsw="UNKNOWN";$secureBoot="UNKNOWN"

    # ---------------------------------------------------------------------
    # ESTRATEGIA DE EXTRACCION MULTI-CAPA:
    #
    # Heimdall 1.4.x habla protocolo Odin v3. Los Galaxy modernos (A55/S24/S25)
    # usan Odin v4/v5 y NO responden a "heimdall info". La info real esta en:
    #
    #   CAPA 1: STDERR del handshake Heimdall
    #      "download-pit --no-reboot" abre sesion y vuelca en stderr:
    #       "Target: SM-A556B", "Binary: 2", "System Status: Locked", etc.
    #
    #   CAPA 2: USB WMI  -  descriptor del dispositivo
    #      Win32_USBHub / Win32_PnPEntity exponen a veces el product string
    #
    #   CAPA 3: ADB directo (Android 12+ puede responder ADB en DL Mode)
    #      getprop sin verificar "adb devices" (puede estar "unauthorized"
    #       pero igual responder a getprop)
    #
    #   CAPA 4: COM port  -  protocolo Odin handshake manual
    #      enviar 0x64 al COM, la respuesta contiene model/binary
    # ---------------------------------------------------------------------

    # -- CAPA 1A: heimdall info (protocolo v3, funciona en modelos ~2018 y antes)
    OdinLog "[~] CAPA 1: heimdall info..."
    $raw1 = Invoke-HeimdallAdv "info"
    # Verificar si la respuesta contiene datos reales del equipo (no solo el banner de copyright)
    # El banner de Heimdall tiene ~525 bytes. Si solo hay banner, no hay datos del dispositivo.
    $raw1HasDeviceData = $raw1 -imatch "Product|Binary|System Status|FRP|Serial|IMEI|SM-[A-Z]"
    if ($raw1HasDeviceData) {
        OdinLog "    OK con datos del dispositivo ($($raw1.Trim().Length) bytes)"
    } elseif ($raw1.Trim().Length -gt 100) {
        OdinLog "    Solo banner Heimdall ($($raw1.Trim().Length) bytes) - dispositivo no respondio a info"
    } else {
        OdinLog "    Vacio - equipo usa protocolo v4/v5"
    }

    # -- CAPA 1B: stderr del handshake download-pit (FUENTE PRINCIPAL en equipos modernos)
    #    Heimdall imprime en stderr: "Target: SM-A556B", "Binary: 2", etc.
    #    durante el handshake ANTES de transferir el PIT
    OdinLog "[~] CAPA 1B: handshake download-pit (stderr)..."
    $pitTmp = Join-Path $env:TEMP ("rnx_pit_" + ([System.DateTime]::Now.Ticks % 99999L).ToString() + ".pit")
    $raw1b  = Invoke-HeimdallAdv "download-pit --output `"$pitTmp`" --no-reboot"
    $raw1bLines = ($raw1b -split "`n").Count
    OdinLog "    $raw1bLines lineas de handshake capturadas"

    # Detectar error libusb -12: driver incorrecto instalado
    if ($raw1b -imatch "libusb error.*-12|Failed to access device") {
        $script:libusbError = $true
    } else {
        $script:libusbError = $false
    }

    # -- CAPA 1C: PIT descargado
    $raw1c = ""
    $pitEntryCount = 0
    if (Test-Path $pitTmp) {
        $raw1c = Invoke-HeimdallAdv "print-pit --file `"$pitTmp`""
        # Leer entry count del PIT
        if ($raw1c -imatch "Entry Count:\s*(\d+)") { $pitEntryCount = [int]$Matches[1] }
        # Extraer modelo/CSC solo si el PIT tiene particiones reales
        if ($pitEntryCount -gt 0) {
            OdinLog "    PIT OK - $pitEntryCount particiones"
            foreach ($pitLine in ($raw1c -split "`n")) {
                $pl = $pitLine.Trim()
                if ($pl -imatch "Filename.*?(SM-[A-Z0-9]+)_([A-Z]{2,5})") {
                    if ($product -eq "UNKNOWN") { $product = $Matches[1]; OdinLog "    [+] Modelo PIT: $product" }
                    if ($csc     -eq "UNKNOWN") { $csc     = $Matches[2]; OdinLog "    [+] CSC PIT: $csc" }
                }
            }
        } else {
            OdinLog "    PIT vacio (Entry Count: 0) - driver no permite lectura real"
        }
        Remove-Item $pitTmp -Force -EA SilentlyContinue
    }

    # -- Si libusb error -12 Y PIT vacio: driver incorrecto confirmado
    if ($script:libusbError -and $pitEntryCount -eq 0) {
        # Dump raw completo para diagnostico antes de salir
        OdinLog "    [RAW] === heimdall info ==="
        foreach ($rl in ($raw1 -split "`n")) { $rlt=$rl.Trim(); if ($rlt.Length -gt 1) { OdinLog "    [RAW] $rlt" } }
        OdinLog "    [RAW] === handshake ==="
        foreach ($rl in ($raw1b -split "`n")) { $rlt=$rl.Trim(); if ($rlt.Length -gt 1) { OdinLog "    [RAW] $rlt" } }
        OdinLog ""
        OdinLog "=========================================="
        OdinLog "  DRIVER INCORRECTO - ACCION REQUERIDA"
        OdinLog "=========================================="
        OdinLog "  El driver 'Samsung USB Modem' no es compatible"
        OdinLog "  con Heimdall. Se necesita WinUSB."
        OdinLog ""
        OdinLog "  SOLUCION con Zadig (zadig.akeo.ie):"
        OdinLog "    1. Abre Zadig con el equipo en Download Mode"
        OdinLog "    2. Options -> List All Devices"
        OdinLog "    3. Selecciona VID_04E8 PID_$($cpuInfo.USBPID) (SAMSUNG)"
        OdinLog "    4. Cambia driver a WinUSB -> Replace Driver"
        OdinLog "    5. Reconecta y reintenta"
        OdinLog ""
        OdinLog "  CPU detectado: EXYNOS VID:$($cpuInfo.VID) PID:$($cpuInfo.USBPID)"
        OdinLog "=========================================="
        $Global:lblADB.Text       = "ADB         : DRIVER ERROR"
        $Global:lblADB.ForeColor  = [System.Drawing.Color]::Red
        $Global:lblModo.Text      = "MODO        : DOWNLOAD"
        $Global:lblModo.ForeColor = [System.Drawing.Color]::Yellow
        $Global:lblCPU.Text       = "CPU         : EXYNOS"
        $Global:lblChip.Text      = "CHIPSET     : EXYNOS"
        $Global:lblStatus.Text    = "  RNX TOOL PRO v2.3  |  DRIVER ERROR  |  Usa Zadig -> WinUSB"
        return
    }

    # -- CAPA 1D: heimdall detect
    $raw1d = Invoke-HeimdallAdv "detect"

    # -- Dump completo de raw1 (heimdall info) y raw1b (handshake) al log
    # Esto es critico para diagnostico cuando el PIT esta vacio sin error libusb
    OdinLog "    [RAW] === heimdall info ==="
    foreach ($rl in ($raw1 -split "`n")) {
        $rlt = $rl.Trim()
        if ($rlt.Length -gt 1) { OdinLog "    [RAW] $rlt" }
    }
    OdinLog "    [RAW] === handshake download-pit ==="
    foreach ($rl in ($raw1b -split "`n")) {
        $rlt = $rl.Trim()
        if ($rlt.Length -gt 1) { OdinLog "    [RAW] $rlt" }
    }

    # -- Parsear todo lo de Heimdall (capas 1A + 1B + 1C + 1D) ----------
    $allHeimdall = $raw1 + "`n" + $raw1b + "`n" + $raw1c + "`n" + $raw1d

    foreach ($line in $allHeimdall -split "`n") {
        $l = $line.Trim()
        if (-not $l) { continue }

        # ---- Modelo / Producto ----
        # "Product Name: SM-G991B" / "Product Name : SM-G991B"
        if ($l -imatch "Product\s*Name\s*[:\=]\s*(.+)")  { $product = $Matches[1].Trim() }
        # "Target: SM-G991B" / "Device: SM-G991B"
        if ($l -imatch "(?:Target|Device|Model)\s*[:\=]\s*(SM-[A-Z0-9]+)") {
            if ($product -eq "UNKNOWN") { $product = $Matches[1].Trim() }
        }
        # Linea suelta con solo el modelo: "SM-G991B"
        if ($l -imatch "^(SM-[A-Z0-9]{5,})$") {
            if ($product -eq "UNKNOWN") { $product = $Matches[1].Trim() }
        }
        # Patron en PIT filename: SM-G991B_EUX_4file_...
        if ($l -imatch "(SM-[A-Z0-9]{4,})_([A-Z]{2,5})_") {
            if ($product -eq "UNKNOWN") { $product = $Matches[1] }
            if ($csc     -eq "UNKNOWN") { $csc     = $Matches[2] }
        }

        # ---- Build / Version ----
        # "AP: SM-G991BXXSAFUL1" / "AP  SM-G991BXXSAFUL1"
        if ($l -imatch "^\s*AP[\s:\=]+([A-Z0-9\-_]{8,})") { $build = $Matches[1].Trim() }
        # "Modem Version: G991BXXSAFUL1"
        if ($l -imatch "Modem\s*Version\s*[:\=]\s*(.+)") {
            if ($build -eq "UNKNOWN") { $build = $Matches[1].Trim() }
        }
        # Build string standalone: SM-G991BXXSAFUL1 (modelo+build juntos)
        if ($l -imatch "(SM-[A-Z0-9]{4,}[A-Z0-9]{6,})") {
            if ($build -eq "UNKNOWN" -and $Matches[1].Length -gt 10) { $build = $Matches[1] }
        }

        # ---- CSC / Region ----
        if ($l -imatch "^\s*CSC[\s:\=]+([A-Z]{2,5})\b") { $csc = $Matches[1].Trim() }
        if ($l -imatch "CSC\s*Code\s*[:\=]\s*([A-Z]{2,5})")  { $csc = $Matches[1].Trim() }
        if ($l -imatch "Region\s*[:\=]\s*([A-Z]{2,5})\b") {
            if ($csc -eq "UNKNOWN") { $csc = $Matches[1].Trim() }
        }

        # ---- Binario / Binary counter ----
        if ($l -imatch "Binary\s*[:\=]\s*(\d+)")          { $binary = $Matches[1].Trim() }
        if ($l -imatch "Bootloader\s*[:\=]\s*([^\s].+)")  { if ($binary -eq "UNKNOWN") { $binary = $Matches[1].Trim() } }

        # ---- Security fields ----
        if ($l -imatch "System\s*Status\s*[:\=]\s*(.+)")   { $status = $Matches[1].Trim() }
        if ($l -imatch "FRP\s*Lock\s*[:\=]\s*(.+)")        { $frp    = $Matches[1].Trim() }
        if ($l -imatch "OEM\s*Lock\s*[:\=]\s*(.+)")        { $oem    = $Matches[1].Trim() }
        if ($l -imatch "KG\s*State\s*[:\=]\s*(.+)")        { $kg     = $Matches[1].Trim() }
        if ($l -imatch "Warranty\s*(Void|Bit)\s*[:\=]\s*(.+)")   { $knox = $Matches[2].Trim() }
        if ($l -imatch "RP\s*SWREV\s*[:\=]\s*(.+)")        { $rpsw   = $Matches[1].Trim() }
        if ($l -imatch "Secure\s*Boot\s*[:\=]\s*(.+)")     { $secureBoot = $Matches[1].Trim() }

        # ---- Serial / IMEI ----
        if ($l -imatch "Serial\s*[:\=]\s*([0-9A-Fx]{6,})") { $serial = $Matches[1].Trim() }
        if ($l -imatch "IMEI\s*[:\=]\s*(\d{10,})")         { $imei   = $Matches[1].Trim() }
    }

    # -- CAPA 2: USB WMI  -  product string del descriptor USB ------------
    OdinLog "[~] CAPA 2: USB descriptor via WMI..."
    try {
        $usbHubs = Get-WmiObject Win32_USBHub -EA SilentlyContinue
        foreach ($hub in $usbHubs) {
            $dev = $hub.DeviceID
            if ($dev -imatch "VID_04E8") {
                $name = $hub.Name
                OdinLog "    USB Hub: $name"
                if ($name -imatch "(SM-[A-Z0-9]+)") {
                    if ($product -eq "UNKNOWN") { $product = $Matches[1]; OdinLog "    [+] Modelo via USB WMI: $product" }
                }
            }
        }
        # Tambien Win32_PnPEntity con DeviceDesc
        $pnpFull = Get-WmiObject Win32_PnPEntity -EA SilentlyContinue |
                   Where-Object { $_.Manufacturer -imatch "Samsung" -and $_.DeviceID -imatch "VID_04E8" }
        foreach ($d in $pnpFull) {
            if ($d.Description -imatch "(SM-[A-Z0-9]+)") {
                if ($product -eq "UNKNOWN") { $product = $Matches[1]; OdinLog "    [+] Modelo via PnP: $product" }
            }
        }
    } catch { OdinLog "    WMI no disponible" }

    # -- CAPA 3: ADB getprop (solo Android 12+ responde en DL Mode) ------
    # Si ADB devuelve solo ruido de daemon, saltamos todas las llamadas
    # para no bloquear la UI con 10 getprops que van a fallar.
    OdinLog "[~] CAPA 3: ADB getprop (Android 12+ DL Mode)..."
    $adbGot = $false

    function Get-AdbPropClean($prop) {
        try {
            $raw = (& adb shell getprop $prop 2>$null)
            if (-not $raw) { return "" }
            $lines = @($raw) | Where-Object {
                $_ -notmatch "daemon|starting it now|successfully started|List of devices|^\s*$"
            }
            $firstLine = ($lines | Select-Object -First 1); return if ($firstLine) { $firstLine.Trim() } else { "" }
        } catch { return "" }
    }

    try {
        # Prueba rapida con un solo getprop - si devuelve ruido de daemon, saltar todo
        $modelAdb = Get-AdbPropClean "ro.product.model"

        if ($modelAdb -and $modelAdb -match "^[A-Za-z0-9]" -and $modelAdb.Length -gt 1) {
            $buildAdb   = Get-AdbPropClean "ro.build.display.id"
            $androidAdb = Get-AdbPropClean "ro.build.version.release"
            $cscAdb     = Get-AdbPropClean "ro.csc.country.code"
            if (-not $cscAdb) { $cscAdb = Get-AdbPropClean "ro.product.csc" }
            $bootldrAdb = Get-AdbPropClean "ro.boot.bootloader"
            $frp1Adb    = Get-AdbPropClean "ro.frp.pst"
            $oemAdb     = Get-AdbPropClean "ro.boot.flash.locked"
            $patchAdb   = Get-AdbPropClean "ro.build.version.security_patch"

            $serRaw = (& adb get-serialno 2>$null) | Where-Object { $_ -notmatch "daemon|starting|^\s*$" } | Select-Object -First 1
            $serAdb = if ($serRaw) { $serRaw.Trim() } else { "" }

            $imeiAdb = ""
            $imeiRaw = (& adb shell "service call iphonesubinfo 1" 2>$null) -join ""
            if ($imeiRaw -match "'[\s]*(\d{5,})[\s]*'") { $imeiAdb = $Matches[1] }

            $adbGot = $true
            if ($product -eq "UNKNOWN" -and $modelAdb)                        { $product = $modelAdb }
            if ($build   -eq "UNKNOWN" -and $buildAdb -match "[A-Z0-9]")      { $build   = $buildAdb }
            if ($csc     -eq "UNKNOWN" -and $cscAdb   -match "^[A-Z]{2,5}$") { $csc     = $cscAdb }
            if ($serial  -eq "UNKNOWN" -and $serAdb   -match "[A-Z0-9]")      { $serial  = $serAdb }
            if ($imei    -eq "UNKNOWN" -and $imeiAdb)                          { $imei    = $imeiAdb }
            if ($bootldrAdb -match "[A-Z0-9]")                                 { $binary  = $bootldrAdb }
            if ($androidAdb -match "^\d")                                     { $status  = "Android $androidAdb" }
            if ($patchAdb   -match "^\d{4}-")                                 { $rpsw    = "Patch: $patchAdb" }
            if ($frp1Adb -ne "") { $frp = if ($frp1Adb) { "PRESENT" } else { "NOT SET" } }
            if ($oemAdb  -ne "") { $oem = if ($oemAdb -eq "1") { "LOCKED" } else { "UNLOCKED" } }

            OdinLog "    [+] ADB respondio - Android $androidAdb | Modelo: $modelAdb"
        } else {
            OdinLog "    ADB no responde con datos validos en DL Mode (normal en Android <12)"
        }
    } catch { OdinLog "    ADB: error de ejecucion" }

    # -- CAPA 4: COM port handshake Odin --------------------------------
    if ($cpuInfo.PORT) {
        OdinLog "[~] CAPA 4: COM port handshake ($($cpuInfo.PORT))..."
        try {
            $sp = New-Object System.IO.Ports.SerialPort $cpuInfo.PORT, 115200
            $sp.ReadTimeout = 3000; $sp.WriteTimeout = 2000
            $sp.DtrEnable = $true; $sp.RtsEnable = $true
            $sp.Open()

            # Secuencia Samsung DL Mode: 0x64 0x00 0x00 0x00 (inicio sesion Odin v3)
            $sp.Write([byte[]]@(0x64, 0x00, 0x00, 0x00), 0, 4)
            Start-Sleep -Milliseconds 800
            $buf = New-Object byte[] 512
            $read = 0
            try { $read = $sp.Read($buf, 0, 512) } catch {}

            if ($read -gt 0) {
                $hexDump = ($buf[0..($read-1)] | ForEach-Object { $_.ToString("X2") }) -join " "
                OdinLog "    COM raw ($read bytes): $hexDump"
                $resp = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read) -replace "[^\x20-\x7E]","."
                OdinLog "    COM ASCII: $($resp.Trim())"
                if ($resp -imatch "(SM-[A-Z0-9]{4,})") {
                    if ($product -eq "UNKNOWN") { $product = $Matches[1]; OdinLog "    [+] Modelo via COM: $product" }
                }
            } else {
                OdinLog "    COM: sin respuesta al handshake 0x64x4"
                $sp.Write([byte[]]@(0x64), 0, 1)
                Start-Sleep -Milliseconds 600
                $buf2 = New-Object byte[] 256
                $read2 = 0
                try { $read2 = $sp.Read($buf2, 0, 256) } catch {}
                if ($read2 -gt 0) {
                    $hex2 = ($buf2[0..($read2-1)] | ForEach-Object { $_.ToString("X2") }) -join " "
                    OdinLog "    COM raw2 ($read2 bytes): $hex2"
                } else { OdinLog "    COM: sin respuesta en ninguna variante" }
            }
            $sp.Close()
        } catch { OdinLog "    COM handshake no disponible" }
    }

    # -- CAPA 4B: leer modelo del registro USB de Windows ----------------
    if ($product -eq "UNKNOWN" -and $cpuInfo.VID -and $cpuInfo.USBPID) {
        OdinLog "[~] CAPA 4B: buscando en registro USB..."
        try {
            $regBase = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\VID_$($cpuInfo.VID)&PID_$($cpuInfo.USBPID)"
            if (Test-Path $regBase) {
                foreach ($inst in (Get-ChildItem $regBase -EA SilentlyContinue)) {
                    $props = Get-ItemProperty $inst.PSPath -EA SilentlyContinue
                    $desc = $props.DeviceDesc
                    $frnd = $props.FriendlyName
                    $hwids = $props.HardwareID
                    if ($desc) { OdinLog "    [REG] DeviceDesc: $desc" }
                    if ($frnd) { OdinLog "    [REG] FriendlyName: $frnd" }
                    foreach ($val in @($desc, $frnd) + @($hwids)) {
                        if ($val -imatch "(SM-[A-Z0-9]{4,})") {
                            if ($product -eq "UNKNOWN") { $product = $Matches[1]; OdinLog "    [+] Modelo via REG: $product" }
                        }
                    }
                }
            } else { OdinLog "    Clave USB no encontrada" }
        } catch { OdinLog "    Registro USB: error" }
    }

        # -- PARAM.BIN (informacion del bootloader: FRP/KG/OEM/modelo) ------
    OdinLog "[~] Extrayendo PARAM.BIN..."
    $paramOK=$false
    foreach ($pn in @("PARAM","PARAMETER","PARAM_A","PARAMETER_A","UP_PARAM","BPARAM")) {
        Invoke-HeimdallAdv "download --$pn param.bin --no-reboot" | Out-Null
        if (Test-Path "param.bin") { $paramOK=$true; OdinLog "[+] PARAM via: $pn"; break }
    }
    if ($paramOK) {
        $pd=Get-ParamBinInfo "param.bin"
        if ($pd.MODEL -and $product -eq "UNKNOWN") { $product=$pd.MODEL }
        if ($pd.FRP -ne "UNKNOWN" -and $frp -eq "UNKNOWN") { $frp=$pd.FRP }
        if ($pd.KG  -ne "UNKNOWN" -and $kg  -eq "UNKNOWN") { $kg =$pd.KG  }
        if ($pd.OEM -ne "UNKNOWN" -and $oem -eq "UNKNOWN") { $oem=$pd.OEM }
        Remove-Item "param.bin" -Force -EA SilentlyContinue
    } else { OdinLog "[!] PARAM.BIN no disponible en este modelo" }

    # -- SBOOT -----------------------------------------------------------
    Invoke-HeimdallAdv "download --SBOOT sboot.bin --no-reboot" | Out-Null
    $sb=Get-SbootInfo "sboot.bin"; $secureBoot=$sb.SECURE
    Remove-Item "sboot.bin" -Force -EA SilentlyContinue

    $root=Detect-Root
    $binaryCalc=Get-BinaryFromBuild $build
    if ($binary -eq "UNKNOWN") { $binary=$binaryCalc }
    if ($csc -match "([A-Z]{3})") { $cscCode=$Matches[1] }
    $cscFull="$cscCode - $(Get-CSCDecoded $cscCode)"

    # Si todo sigue UNKNOWN pero el dispositivo fue confirmado por WMI/PnP,
    # mostrar nota explicativa sobre la limitacion del protocolo
    $allUnknown = ($product -eq "UNKNOWN" -and $build -eq "UNKNOWN" -and $serial -eq "UNKNOWN")
    if ($allUnknown -and $cpuInfo.MODE -eq "DOWNLOAD_MODE") {
        OdinLog ""
        OdinLog "[!] INFO: Dispositivo detectado correctamente (VID:$($cpuInfo.VID)/PID:$($cpuInfo.USBPID))"
        OdinLog "[!] pero Heimdall 1.4.x no pudo leer datos del dispositivo."
        OdinLog "[~] Esto ocurre cuando:"
        OdinLog "    - El driver no es WinUSB (usa Zadig para cambiarlo)"
        OdinLog "    - El equipo usa protocolo Odin v4/v5 (S22+, A53 2022+)"
        OdinLog "    - El equipo tiene FRP activo que bloquea la sesion"
        OdinLog "[~] El dispositivo SI puede flashearse - carga el firmware y usa INICIAR FLASHEO"
    }

    # Actualizar sidebar completo con info de Download Mode
    $Global:lblModo.Text     = "MODO        : DOWNLOAD"
    $Global:lblModo.ForeColor= [System.Drawing.Color]::Yellow
    $Global:lblADB.Text      = "ADB         : DOWNLOAD MODE"
    $Global:lblADB.ForeColor = [System.Drawing.Color]::Yellow
    if ($product -ne "UNKNOWN") {
        $Global:lblModel.Text = "MODELO      : $product"
        $Global:lblDisp.Text  = "DISPOSITIVO : SAMSUNG"
        $Global:lblStatus.Text= "  RNX TOOL PRO v2.3  |  DOWNLOAD MODE  |  $product"
    }
    if ($serial -ne "UNKNOWN") { $Global:lblSerial.Text = "SERIAL      : $serial" }
    if ($cpuInfo.CPU -ne "UNKNOWN") {
        $Global:lblCPU.Text  = "CPU         : $($cpuInfo.CPU)"
        $chipDl = if ($cpuInfo.CPU -match "EXYNOS") {"EXYNOS"}
                  elseif ($cpuInfo.CPU -match "MTK|MEDIATEK") {"MEDIATEK"}
                  else {"QUALCOMM"}
        $Global:lblChip.Text = "CHIPSET     : $chipDl"
    }
    if ($frp -ne "UNKNOWN") {
        $Global:lblFRP.Text      = "FRP         : $frp"
        $Global:lblFRP.ForeColor = if ($frp -imatch "OFF|NO|DIS|NOT") {[System.Drawing.Color]::Lime} else {[System.Drawing.Color]::Red}
    }

    OdinLog ""
    OdinLog "=============================================="
    OdinLog "    INFORMACION DOWNLOAD MODE - SAMSUNG"
    OdinLog "=============================================="
    OdinLog "  PRODUCTO       : $product"
    OdinLog "  ANDROID BUILD  : $build"
    OdinLog "  BINARIO        : $binary"
    OdinLog "  CSC            : $cscFull"
    OdinLog "  IMEI           : $imei"
    OdinLog "  SERIAL         : $serial"
    OdinLog ""
    OdinLog "  KG STATE       : $kg"
    OdinLog "  ROOT STATE     : $root"
    OdinLog "  SYSTEM STATUS  : $status"
    OdinLog "  WARRANTY VOID  : $knox"
    OdinLog "  FRP LOCK       : $frp"
    OdinLog "  OEM LOCK       : $oem"
    OdinLog "  SECURE BOOT    : $secureBoot"
    OdinLog "  RP SWREV       : $rpsw"
    $cpuDisplay = $cpuInfo.CPU
    if ($cpuInfo.VID) { $cpuDisplay += "  (VID:$($cpuInfo.VID)/PID:$($cpuInfo.USBPID))" }
    OdinLog "  CPU            : $cpuDisplay"
    OdinLog "=============================================="
    OdinLog "[OK] LECTURA COMPLETADA"
}

function Read-MTKInfoViaADB($cpuInfo) {
    OdinLog "[*] ===  SAMSUNG MTK - LECTURA EXTENDIDA VIA ADB  ==="
    OdinLog ""
    $adbOnline = (& adb devices 2>$null) -imatch "`tdevice"
    if ($adbOnline) {
        OdinLog "[+] ADB disponible..."
        $model=(& adb shell getprop ro.product.model 2>$null).Trim()
        $brand=(& adb shell getprop ro.product.brand 2>$null).Trim()
        $build=(& adb shell getprop ro.build.display.id 2>$null).Trim()
        $plt=(& adb shell getprop ro.board.platform 2>$null).Trim()
        $soc=(& adb shell getprop ro.soc.model 2>$null).Trim()
        $android=(& adb shell getprop ro.build.version.release 2>$null).Trim()
        $patch=(& adb shell getprop ro.build.version.security_patch 2>$null).Trim()
        $serial=(& adb get-serialno 2>$null).Trim()
        $bootldr=(& adb shell getprop ro.boot.bootloader 2>$null).Trim()
        $frp1=(& adb shell getprop ro.frp.pst 2>$null).Trim()
        $oemLock=(& adb shell getprop ro.boot.flash.locked 2>$null).Trim()
        # Deteccion multi-señal UFS vs eMMC
        $ufsNode2 = (& adb shell "ls /sys/class/ufs 2>/dev/null").Trim()
        $ufsDev2  = (& adb shell "ls /dev/block/sda 2>/dev/null").Trim()
        $ufsHost2 = (& adb shell "ls /sys/bus/platform/drivers/ufshcd 2>/dev/null").Trim()
        $ufsType2 = (& adb shell "getprop ro.boot.storage_type 2>/dev/null").Trim()
        $mmcBlk2  = (& adb shell "ls /dev/block/mmcblk0 2>/dev/null").Trim()
        $isUFS2   = ($ufsNode2 -or $ufsDev2 -or $ufsHost2 -or ($ufsType2 -imatch "ufs") -or (-not $mmcBlk2 -and $ufsDev2))
        $storage=if ($isUFS2) {"UFS"} else {"eMMC"}
        $imeiRaw=(& adb shell "service call iphonesubinfo 1" 2>$null)
        $imei="UNKNOWN"; if ($imeiRaw -match "'\s*(\d{5,})\s*'") { $imei=$Matches[1] }
        $root=Detect-Root
        $binary=Get-BinaryFromBuild $build
        $cscProp=(& adb shell getprop ro.csc.country.code 2>$null).Trim()
        if (-not $cscProp) { $cscProp=(& adb shell getprop ro.product.csc 2>$null).Trim() }
        $cscFull=if ($cscProp) {"$cscProp - $(Get-CSCDecoded $cscProp)"} else {"UNKNOWN"}
        $cpuFull=if ($soc) {"$soc ($plt)"} else {$plt.ToUpper()}
        $Global:lblModo.Text="MODO        : ADB (MTK)"; $Global:lblModo.ForeColor=[System.Drawing.Color]::Yellow
        $Global:lblFRP.Text="FRP         : " + (if ($frp1) {"PRESENT"} else {"NOT SET"})
        $Global:lblFRP.ForeColor=if ($frp1) {[System.Drawing.Color]::Red} else {[System.Drawing.Color]::Lime}
        $Global:lblStorage.Text="STORAGE     : $storage"
        OdinLog "  MARCA     : $($brand.ToUpper())"
        OdinLog "  MODELO    : $model  |  ANDROID: $android"
        OdinLog "  BUILD     : $build  |  BINARIO: $binary"
        OdinLog "  BOOTLOADER: $bootldr"
        OdinLog "  CSC       : $cscFull"
        OdinLog "  IMEI      : $imei  |  SERIAL: $serial"
        OdinLog "  CPU       : $cpuFull  |  STORAGE: $storage"
        OdinLog "  ROOT      : $root"
        $frpStr2=if ($frp1) {"PRESENT"} else {"NOT SET"}; $oemStr2=if ($oemLock -eq "1") {"LOCKED"} else {"UNLOCKED"}; OdinLog "  FRP       : $frpStr2  |  OEM: $oemStr2"
        OdinLog ""
        OdinLog "[OK] LECTURA MTK OK"
        OdinLog ""
        OdinLog "[~] NOTA Samsung A07 MTK: apaga, mantiene Vol-, conecta USB"
    } else {
        OdinLog "[!] Sin ADB y sin Heimdall. CPU:$($cpuInfo.CPU) USB:$($cpuInfo.USB_NAME)"
        OdinLog "[~] Instala Samsung USB Driver v1.7.44+"
    }
}



#==========================================================================
# INSTALAR DRIVER WINUSB PARA HEIMDALL - sin Zadig, sin internet
# Genera un .inf temporal con el VID/PID detectado y usa pnputil
# Requiere ejecutar como Administrador
#==========================================================================
function Install-WinUSBDriver {
    param($vid, $usbpid, $friendlyName)

    OdinLog ""
    OdinLog "[*] =========================================="
    OdinLog "[*]   INSTALAR DRIVER WINUSB via Zadig"
    OdinLog "[*] =========================================="
    OdinLog ""

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        OdinLog "[!] Requiere ejecutar como Administrador"
        OdinLog "[~] Clic derecho en el script -> Ejecutar con PowerShell como Administrador"
        return $false
    }
    if (-not $vid -or -not $usbpid) {
        OdinLog "[!] No se detecto VID/PID. Conecta el equipo en Download Mode primero"
        return $false
    }

    OdinLog "[+] VID: $vid  |  PID: $usbpid"
    OdinLog "[+] Dispositivo: $friendlyName"
    OdinLog ""

    # Zadig es la unica herramienta que puede instalar WinUSB sin firma en Win10/11
    # Tiene binarios propios firmados (libwdi). No hay alternativa pura en PowerShell.
    $zadigDir  = Join-Path $env:TEMP "rnx_zadig"
    $zadigPath = Join-Path $zadigDir "zadig.exe"
    if (-not (Test-Path $zadigDir)) { New-Item $zadigDir -ItemType Directory -Force | Out-Null }

    # Generar zadig.ini para instalacion silenciosa
    # Zadig lee este .ini del mismo directorio para pre-seleccionar device y driver
    $iniPath = Join-Path $zadigDir "zadig.ini"
    $iniLines = @(
        "[Zadig]",
        "advanced_mode = false",
        "exit_on_success = false",
        "log_level = 0",
        "[Device]",
        "vid = 0x$vid",
        "pid = 0x$usbpid",
        "driver = WinUSB"
    )
    [System.IO.File]::WriteAllLines($iniPath, $iniLines, [System.Text.Encoding]::ASCII)

    # Descargar Zadig si no esta disponible
    if (-not (Test-Path $zadigPath)) {
        OdinLog "[~] Descargando Zadig desde zadig.akeo.ie..."
        OdinLog "    (requiere conexion a internet - ~3 MB)"
        # Intentar descarga con varios metodos
        $downloaded = $false
        $zadigUrls = @(
            "https://github.com/pbatard/zadig/releases/download/v2.9/zadig-2.9.exe",
            "https://zadig.akeo.ie/downloads/zadig-2.9.exe"
        )
        foreach ($url in $zadigUrls) {
            if ($downloaded) { break }
            try {
                OdinLog "    Intentando: $url"
                $req = [System.Net.HttpWebRequest]::Create($url)
                $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
                $req.Timeout   = 30000
                $req.AllowAutoRedirect = $true
                $resp   = $req.GetResponse()
                $stream = $resp.GetResponseStream()
                $fs     = [System.IO.File]::Create($zadigPath)
                $buf    = New-Object byte[] 8192
                do { $n = $stream.Read($buf, 0, 8192); if ($n -gt 0) { $fs.Write($buf, 0, $n) } } while ($n -gt 0)
                $fs.Close(); $stream.Close(); $resp.Close()
                if ((Get-Item $zadigPath).Length -gt 100000) {
                    OdinLog "[+] Zadig descargado OK ($([Math]::Round((Get-Item $zadigPath).Length/1MB,1)) MB)"
                    $downloaded = $true
                } else {
                    Remove-Item $zadigPath -Force -EA SilentlyContinue
                }
            } catch { OdinLog "    Fallo: $($_.Exception.Message.Split([char]10)[0])" }
        }

        if (-not $downloaded) {
            OdinLog ""
            OdinLog "[!] No se pudo descargar Zadig automaticamente"
            OdinLog "    (red corporativa, proxy o firewall bloqueando)"
            OdinLog ""
            OdinLog "  SOLUCION MANUAL (30 segundos):"
            OdinLog "    1. Abre en el navegador: https://zadig.akeo.ie"
            OdinLog "    2. Descarga zadig.exe (boton verde Download)"
            OdinLog "    3. Copia el archivo a esta carpeta:"
            OdinLog "       $zadigDir"
            OdinLog "    4. Vuelve a presionar el boton INSTALAR DRIVER WINUSB"
            OdinLog ""
            OdinLog "  Abriendo navegador y carpeta destino..."
            try { Start-Process "https://zadig.akeo.ie" } catch {}
            try {
                if (-not (Test-Path $zadigDir)) { New-Item $zadigDir -ItemType Directory -Force | Out-Null }
                Start-Process explorer.exe $zadigDir
            } catch {}
            return $false
        }
    } else {
        OdinLog "[+] Zadig encontrado: $zadigPath"
    }

    # Zadig no tiene modo CLI silencioso real, pero con el .ini pre-configurado
    # abre directo al dispositivo correcto. El usuario solo hace clic en "Install Driver".
    OdinLog ""
    OdinLog "[~] Abriendo Zadig..."
    OdinLog "    El dispositivo VID_$($vid)&PID_$($usbpid) ya esta pre-seleccionado"
    OdinLog ""
    OdinLog "  PASOS EN ZADIG:"
    OdinLog "    1. En el menu: Options -> List All Devices"
    OdinLog "    2. Selecciona: Samsung Mobile USB (VID_$vid PID_$usbpid)"  
    OdinLog "    3. Driver derecha: WinUSB"
    OdinLog "    4. Clic: Replace Driver (o Install Driver)"
    OdinLog "    5. Espera ~30 segundos"
    OdinLog "    6. Cierra Zadig y reconecta el equipo"
    OdinLog ""

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName         = $zadigPath
        $psi.WorkingDirectory = $zadigDir
        $psi.UseShellExecute  = $false
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null
        OdinLog "[OK] Zadig abierto - sigue los pasos indicados arriba"
        OdinLog "[~] Cuando termines, reconecta el equipo y usa LEER INFO (ODIN)"
        return $true
    } catch {
        OdinLog "[!] Error abriendo Zadig: $_"
        OdinLog "[~] Ejecuta manualmente: $zadigPath"
        return $false
    }
}


function Install-WinUSBViaRegistry {
    param($vid, $usbpid)
    OdinLog "[~] Metodo 2: configurando WinUSB via registro del dispositivo..."
    try {
        $usbPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\VID_$($vid)&PID_$($usbpid)"
        if (-not (Test-Path $usbPath)) {
            OdinLog "[!] Clave de registro no encontrada: VID_$($vid)&PID_$($usbpid)"
            OdinLog "[~] El equipo no esta conectado o no fue reconocido por Windows"
            OdinLog "[!] Usa Zadig manualmente: https://zadig.akeo.ie"
            OdinLog "    1. Abre Zadig con el equipo en Download Mode"
            OdinLog "    2. Options -> List All Devices"
            OdinLog "    3. Selecciona VID_$($vid) PID_$($usbpid)"
            OdinLog "    4. Driver: WinUSB -> Install Driver"
            return $false
        }
        $instances = Get-ChildItem $usbPath -EA SilentlyContinue
        $count = 0
        foreach ($inst in $instances) {
            OdinLog "    Instancia: $($inst.PSChildName)"
            Set-ItemProperty -Path $inst.PSPath -Name "Service" -Value "WinUSB" -Type String -EA SilentlyContinue
            $count++
        }
        if ($count -gt 0) {
            OdinLog "[~] Forzando re-enumeracion USB..."
            $null = & pnputil /scan-devices 2>$null
            Start-Sleep -Milliseconds 2500
            OdinLog "[OK] Registro configurado para $count instancia(s)"
            OdinLog "[~] Desconecta y reconecta el equipo en Download Mode"
            OdinLog "[~] Windows cargara WinUSB automaticamente"
            return $true
        } else {
            OdinLog "[!] No se encontraron instancias activas del dispositivo"
            OdinLog "[~] Usa Zadig: https://zadig.akeo.ie"
            return $false
        }
    } catch {
        OdinLog "[!] Error en metodo registro: $_"
        OdinLog "[~] Usa Zadig: https://zadig.akeo.ie"
        return $false
    }
}


#==========================================================================
# FLASH PRO ENGINE - COMPLETO TIPO ODIN/CHIMERA
# Extrae .tar en tiempo real, mapea particiones, flashea via Heimdall
#==========================================================================
function Start-FlashPro {
    OdinLog ""
    OdinLog "[*] =========================================="
    OdinLog "[*]   SAMSUNG ODIN PRO - FLASH ENGINE v2.3"
    OdinLog "[*] =========================================="
    OdinLog ""

    # Validar heimdall con Assert-ToolExists antes de cualquier operacion
    $heimExe = Get-HeimdallExe
    try {
        Assert-ToolExists -Path (if ($heimExe) { $heimExe } else { "heimdall" }) `
                          -ToolName "heimdall.exe" `
                          -DownloadHint "github.com/Benjamin-Dobell/Heimdall/releases"
    } catch {
        OdinLog "[!] $_"
        return
    }

    $hv = Invoke-HeimdallSafe "version"
    if (-not $hv) { OdinLog "[!] heimdall.exe no responde - verifica instalacion"; return }
    OdinLog "[+] Heimdall: $($hv.Trim())"

    # Deteccion unificada WMI+PnP+Heimdall
    OdinLog "[~] Detectando dispositivo..."
    $cpuInfo = Get-SamsungCPUInfo
    OdinLog "[+] CPU     : $($cpuInfo.CPU)  |  Proto: $($cpuInfo.PROTO)"
    if ($cpuInfo.USB_NAME) { OdinLog "[+] USB     : $($cpuInfo.USB_NAME)" }
    if ($cpuInfo.VID)      { OdinLog "[+] VID/PID : $($cpuInfo.VID)/$($cpuInfo.USBPID)" }

    # Bloquear si no esta en Download Mode
    if ($cpuInfo.MODE -ne "DOWNLOAD_MODE") {
        OdinLog "[!] Dispositivo no detectado en Download Mode"
        OdinLog "[!] Pon el equipo en Download Mode y reconecta"
        OdinLog "    - A-series moderno : Vol- + Power (mantener ~8 seg)"
        OdinLog "    - Series antiguas  : Vol- + Bixby + Power"
        OdinLog "    - Via ADB          : adb reboot download"
        return
    }

    # Bloquear MTK  -  Heimdall no puede flashear
    if ($cpuInfo.PROTO -eq "MTK") {
        OdinLog "[!] CPU MediaTek/UNISOC  -  Heimdall NO puede flashear este equipo"
        OdinLog "[!] Usa SP Flash Tool (MTK) o ODIN para dispositivos Samsung MTK"
        return
    }

    # Advertir protocolo v4 antes de intentar el flash
    if ($cpuInfo.PROTO -eq "v4") {
        OdinLog "[!] ADVERTENCIA: Equipo con protocolo Odin v4 (S22 / modelos 2022+)"
        OdinLog "[!] Heimdall 1.4.x puede fallar en el flash  -  usa Odin3 para este equipo"
        OdinLog "[~] Intentando de todas formas con Heimdall..."
        OdinLog ""
    }

    OdinLog "[OK] Dispositivo listo para flashear"
    OdinLog ""

    $flashArgs = "flash"
    $partsFlashed = 0

    # PIT
    if ($script:PIT_FILE -and (Test-Path $script:PIT_FILE)) {
        $flashArgs += " --pit `"$($script:PIT_FILE)`""
        OdinLog "[~] PIT: $([IO.Path]::GetFileName($script:PIT_FILE))"
    }

    # ---- Funcion helper: resolver slot ----
    # Si ya tenemos .img extraidos los usa. Si solo tenemos el .tar los extrae ahora.
    function Resolve-SlotImgs($slotName, $imgs, $tarFile) {
        if ($imgs -and $imgs.Count -gt 0) { return $imgs }
        if ($tarFile -and (Test-Path $tarFile)) {
            OdinLog "[~] Extrayendo $slotName ..."
            $ed = Expand-FirmwareFile $tarFile $slotName
            if ($ed) {
                $cl = Auto-ClassifyImages $ed
                # Devolver lo que haya en el slot esperado, o todo lo clasificado
                if ($cl[$slotName].Count -gt 0) { return $cl[$slotName] }
                $all = $cl.BL + $cl.AP + $cl.CP + $cl.CSC
                if ($all.Count -gt 0) { return $all }
            }
        }
        return @()
    }

    # BL
    $blImgs = Resolve-SlotImgs "BL" $script:BL_IMGS $script:BL_FILE
    if ($blImgs.Count -gt 0) {
        OdinLog "[~] BL ($($blImgs.Count) particiones):"
        $flashArgs += Build-HeimdallFlags $blImgs
        $partsFlashed += $blImgs.Count
    }

    # AP
    $apImgs = Resolve-SlotImgs "AP" $script:AP_IMGS $script:AP_FILE
    if ($apImgs.Count -gt 0) {
        OdinLog "[~] AP ($($apImgs.Count) particiones):"
        $flashArgs += Build-HeimdallFlags $apImgs
        $partsFlashed += $apImgs.Count
    } elseif ($script:AP_FILE -and (Test-Path $script:AP_FILE) -and $script:AP_PARTS.Count -eq 0) {
        # tar directo sin extraccion previa (arrastrado sin descomprimir)
        OdinLog "[~] AP tar directo - extrayendo en tiempo real..."
        $ed = Expand-FirmwareFile $script:AP_FILE "AP"
        if ($ed) {
            $cl = Auto-ClassifyImages $ed
            $apImgs = $cl.AP + $cl.BL + $cl.CP + $cl.CSC
            if ($apImgs.Count -gt 0) {
                OdinLog "[~] AP ($($apImgs.Count) particiones):"
                $flashArgs += Build-HeimdallFlags $apImgs
                $partsFlashed += $apImgs.Count
            }
        }
    }

    # CP
    $cpImgs = Resolve-SlotImgs "CP" $script:CP_IMGS $script:CP_FILE
    if ($cpImgs.Count -gt 0) {
        OdinLog "[~] CP ($($cpImgs.Count) particiones):"
        $flashArgs += Build-HeimdallFlags $cpImgs
        $partsFlashed += $cpImgs.Count
    }

    # CSC
    $cscImgs = Resolve-SlotImgs "CSC" $script:CSC_IMGS $script:CSC_FILE
    if ($cscImgs.Count -gt 0) {
        OdinLog "[~] CSC ($($cscImgs.Count) particiones):"
        $flashArgs += Build-HeimdallFlags $cscImgs
        $partsFlashed += $cscImgs.Count
    }

    if ($partsFlashed -eq 0) {
        OdinLog "[!] No hay particiones para flashear"
        OdinLog "[!] Carga al menos un archivo (BL/AP/CP/CSC)"
        return
    }

    $flashArgs += " --no-reboot"
    OdinLog ""
    OdinLog "[~] Total: $partsFlashed particiones"
    OdinLog "[~] Ejecutando flasheo..."
    OdinLog ""

    $exit = Invoke-HeimdallLive $flashArgs

    if ($exit -eq 0) {
        OdinLog ""
        OdinLog "[OK] ===== FLASHEO COMPLETADO EXITOSAMENTE ====="
        OdinLog "[~] Reiniciando equipo..."
        Invoke-Heimdall "flash --REBOOT" | Out-Null
        $Global:lblStatus.Text = "  RNX TOOL PRO v2.2  |  FLASH OK  |  Equipo reiniciando..."
    } else {
        OdinLog ""
        OdinLog "[!] FLASHEO TERMINO CON ERRORES (exit=$exit)"
        OdinLog "[!] Revisa los archivos y vuelve a intentar"
    }
}

#==========================================================================
# DRAG & DROP en tab Odin - acepta tar/md5/zip/rar/7z
#==========================================================================
$tabOdin.AllowDrop = $true
$tabOdin.Add_DragEnter({
    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
        $_.Effect = [Windows.Forms.DragDropEffects]::Copy
    }
})
$tabOdin.Add_DragDrop({
    foreach ($file in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) {
        Set-FirmwareFile $file $null
    }
})

#==========================================================================
# UI - GRUPO BINARIOS DE FIRMWARE
#==========================================================================
$grpOdin = New-GBox $tabOdin "BINARIOS DE FIRMWARE SAMSUNG" 10 10 838 200 "White"

function Add-FlashRow($lbl, $y, $slot) {
    $lb = New-Object Windows.Forms.Label
    $lb.Text=$lbl; $lb.Location=New-Object System.Drawing.Point(14,$($y+5))
    $lb.ForeColor=[System.Drawing.Color]::Lime; $lb.Width=42
    $lb.Font=New-Object System.Drawing.Font("Segoe UI",8.5,[System.Drawing.FontStyle]::Bold)
    $grpOdin.Controls.Add($lb)

    $t = New-Object Windows.Forms.TextBox
    $t.Location=New-Object System.Drawing.Point(62,$y); $t.Size=New-Object System.Drawing.Size(578,26)
    $t.BackColor="Black"; $t.ForeColor="White"; $t.BorderStyle="FixedSingle"; $t.AllowDrop=$true
    $t.Tag=$slot
    $t.Add_DragEnter({
        if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect=[Windows.Forms.DragDropEffects]::Copy }
    })
    $t.Add_DragDrop({
        $f=($_.Data.GetData([Windows.Forms.DataFormats]::FileDrop))[0]
        Set-FirmwareFile $f $this.Tag
    })
    $grpOdin.Controls.Add($t)
    Set-Variable -Name "txtOdin_$slot" -Value $t -Scope Global

    $b = New-Object Windows.Forms.Button
    $b.Text="EXAMINAR"; $b.Location=New-Object System.Drawing.Point(650,$y); $b.Size=New-Object System.Drawing.Size(116,26)
    $b.FlatStyle="Flat"; $b.ForeColor=[System.Drawing.Color]::White; $b.BackColor=[System.Drawing.Color]::FromArgb(45,45,45)
    $b.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(90,90,90)
    $b.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $b.Tag=$slot
    $b.Add_Click({ $f=Pick-FirmwareFile; if ($f) { Set-FirmwareFile $f $this.Tag } })
    $grpOdin.Controls.Add($b)
}

Add-FlashRow "BL"   22  "BL"
Add-FlashRow "AP"   60  "AP"
Add-FlashRow "CP"   98  "CP"
Add-FlashRow "CSC" 136  "CSC"

$Global:txtBL  = $Global:txtOdin_BL
$Global:txtAP  = $Global:txtOdin_AP
$Global:txtCP  = $Global:txtOdin_CP
$Global:txtCSC = $Global:txtOdin_CSC

#==========================================================================
# LOG ODIN
#==========================================================================
$Global:logOdin            = New-Object Windows.Forms.TextBox
$Global:logOdin.Multiline  = $true
$Global:logOdin.Location   = New-Object System.Drawing.Point(10, 240)
$Global:logOdin.Size       = New-Object System.Drawing.Size(604, 328)
$Global:logOdin.BackColor  = "Black"
$Global:logOdin.ForeColor  = [System.Drawing.Color]::Lime
$Global:logOdin.BorderStyle = "FixedSingle"
$Global:logOdin.ScrollBars  = "Vertical"
$Global:logOdin.Font        = New-Object System.Drawing.Font("Consolas", 9)
$Global:logOdin.ReadOnly    = $true
$tabOdin.Controls.Add($Global:logOdin)
# Context menu: Limpiar Log
$ctxOdin = New-Object System.Windows.Forms.ContextMenuStrip
$mnuClearOdin = $ctxOdin.Items.Add("Limpiar Log")
$mnuClearOdin.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$mnuClearOdin.ForeColor = [System.Drawing.Color]::OrangeRed
$mnuClearOdin.Add_Click({ $Global:logOdin.Clear() })
$Global:logOdin.ContextMenuStrip = $ctxOdin

#==========================================================================
# BOTONES ODIN PRO
#==========================================================================
$odinLabels = @("LEER INFO (ODIN)", "INICIAR FLASHEO", "REINICIAR RECOVERY", "REINICIAR DOWNLOAD")
$odinColors = @("Lime", "Orange", "Cyan", "White")
$odinBtns   = @()
for ($i = 0; $i -lt 4; $i++) {
    $ob = New-FlatBtn $tabOdin $odinLabels[$i] $odinColors[$i] 628 (240 + $i * 86) 220 70
    $ob.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $odinBtns += $ob
}
$btnReadOdin   = $odinBtns[0]
$btnStartFlash = $odinBtns[1]
$btnRebRec     = $odinBtns[2]
$btnRebDown    = $odinBtns[3]

# Boton INSTALAR DRIVER WINUSB  - debajo de los 4 botones principales
$btnWinUSB = New-Object Windows.Forms.Button
$btnWinUSB.Text      = "INSTALAR DRIVER WINUSB"
$btnWinUSB.Location  = New-Object System.Drawing.Point(628, 586)
$btnWinUSB.Size      = New-Object System.Drawing.Size(220, 36)
$btnWinUSB.FlatStyle = "Flat"
$btnWinUSB.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 0)
$btnWinUSB.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$btnWinUSB.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 200, 0)
$btnWinUSB.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
$tabOdin.Controls.Add($btnWinUSB)


#==========================================================================
# TAB 2: UTILIDADES ADB
#==========================================================================
$tabAdb           = New-Object Windows.Forms.TabPage
$tabAdb.Text      = "UTILIDADES ADB"
$tabAdb.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$tabs.TabPages.Add($tabAdb)

# ---------------------------------------------------------------
# METRICAS TAB ADB  -  2 columnas simetricas
# Area util tab: 856px  ->  col izq x=6 w=422 | gap=8 | col der x=436 w=422
# Botones: BW=196 BH=56  2 por fila con gap 8  ->  196*2+8=400 < 422-24=398 ~OK
# Ajuste: BW=195 para que 2*195+8+2*PPX = 2*195+8+32 = 426 -> cabe en 422 con margin
# Grupos col izq altura total: ~606 px  (margen inf ~12px)
# ---------------------------------------------------------------
$AX=6; $AGAP=8; $ALOGX=436
$ABTW=195; $ABTH=56; $APX=14; $APY=20; $AGX=8; $AGY=8
$AGW=422                       # ancho de cada columna
$ALOGW=$AGW                    # log misma anchura que columna

# Alturas de grupos
$AGH1 = $APY + 2*($ABTH+$AGY) - $AGY + 14   # Grupo1: 2 filas
$AGH2 = $APY + 3*($ABTH+$AGY) - $AGY + 14   # Grupo2: 3 filas
$AGH3 = $APY + 2*($ABTH+$AGY) - $AGY + 14   # Grupo3: 2 filas

$AY1=6
$AY2=$AY1+$AGH1+$AGAP
$AY3=$AY2+$AGH2+$AGAP

# --- GRUPOS ---
$grpA1 = New-GBox $tabAdb "BASICO E INFORMACION"   $AX $AY1 $AGW $AGH1 "Cyan"
$grpA2 = New-GBox $tabAdb "REPARACION Y SEGURIDAD" $AX $AY2 $AGW $AGH2 "Orange"
$grpA3 = New-GBox $tabAdb "HERRAMIENTAS AVANZADAS" $AX $AY3 $AGW $AGH3 "Lime"

$AL1=@("LEER INFO COMPLETA","REINICIAR SISTEMA","REBOOT RECOVERY","REBOOT BOOTLOADER")
# 6 botones en 3 filas para REPARACION Y SEGURIDAD
$AL2=@("AUTOROOT MAGISK","BYPASS BANCARIO","BACKUP ADB","ACTIVAR SIM 2 SAMSUNG",
       "CLONAR DISPOSITIVO","RESTAURAR BACKUP")
$AL3=@("BLOQUEAR OTA","REMOVER ADWARE","BACKUP APK","ACTIVAR DIAG")

$btnsA1=Place-Grid $grpA1 $AL1 "Cyan"   2 $ABTW $ABTH $APX $APY $AGX $AGY
$btnsA2=Place-Grid $grpA2 $AL2 "Orange" 2 $ABTW $ABTH $APX $APY $AGX $AGY
$btnsA3=Place-Grid $grpA3 $AL3 "Lime"   2 $ABTW $ABTH $APX $APY $AGX $AGY

$btnReadAdb   =$btnsA1[0]; $btnRebootSys=$btnsA1[1]
$btnRebootRec =$btnsA1[2]; $btnRebootBl =$btnsA1[3]
$btnRemFRP    =$btnsA2[0]

# Log ocupa toda la altura de la columna derecha
$ALOGY=$AY1; $ALOGH=616

# Variable global para proceso ADB largo activo (usado por STOP)
$script:ADB_ACTIVE_PROC = $null

# Boton STOP tab ADB - encima del log, color blanco para visibilidad
$adbStopH   = 26
$adbStopGap = 4
$btnAdbStop           = New-Object Windows.Forms.Button
$btnAdbStop.Text      = "STOP"
$btnAdbStop.Location  = New-Object System.Drawing.Point($ALOGX, $ALOGY)
$btnAdbStop.Size      = New-Object System.Drawing.Size($ALOGW, $adbStopH)
$btnAdbStop.FlatStyle = "Flat"
$btnAdbStop.ForeColor = [System.Drawing.Color]::White
$btnAdbStop.BackColor = [System.Drawing.Color]::FromArgb(55,25,25)
$btnAdbStop.FlatAppearance.BorderColor = [System.Drawing.Color]::White
$btnAdbStop.Font      = New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)
$btnAdbStop.Enabled   = $false
$tabAdb.Controls.Add($btnAdbStop)
$Global:btnAdbStop = $btnAdbStop

$btnAdbStop.Add_Click({
    if ($script:ADB_ACTIVE_PROC -and -not $script:ADB_ACTIVE_PROC.HasExited) {
        try {
            $script:ADB_ACTIVE_PROC.Kill()
            AdbLog "[!] Proceso detenido por el usuario."
        } catch { AdbLog "[!] No se pudo detener: $_" }
    }
    $btnAdbStop.Enabled = $false
})

# Ajustar posicion y alto del log ADB para dejar espacio al STOP
$adbLogRealY = $ALOGY + $adbStopH + $adbStopGap
$adbLogRealH = $ALOGH - $adbStopH - $adbStopGap

$Global:logAdb           = New-Object Windows.Forms.TextBox
$Global:logAdb.Multiline = $true
$Global:logAdb.Location  = New-Object System.Drawing.Point($ALOGX, $adbLogRealY)
$Global:logAdb.Size      = New-Object System.Drawing.Size($ALOGW, $adbLogRealH)
$Global:logAdb.BackColor = "Black"; $Global:logAdb.ForeColor=[System.Drawing.Color]::Cyan
$Global:logAdb.BorderStyle="FixedSingle"; $Global:logAdb.ScrollBars="Vertical"
$Global:logAdb.Font      = New-Object System.Drawing.Font("Consolas",8.5)
$tabAdb.Controls.Add($Global:logAdb)
# Context menu: Limpiar Log
$ctxAdb = New-Object System.Windows.Forms.ContextMenuStrip
$mnuClearAdb = $ctxAdb.Items.Add("Limpiar Log")
$mnuClearAdb.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$mnuClearAdb.ForeColor = [System.Drawing.Color]::OrangeRed
$mnuClearAdb.Add_Click({ $Global:logAdb.Clear() })
$Global:logAdb.ContextMenuStrip = $ctxAdb

#==========================================================================
# TAB 3: UTILIDADES GENERALES
# Layout: 2 columnas simetricas identico a ADB
#   Col izq  x=10  ancho=424  : 3 grupos de botones apilados
#   Col der  x=444 ancho=424  : log box altura completa
# Grupos:
#   G1 (Red)     FUNCIONES ROOT      4 btn  2 filas  h=172
#   G2 (Cyan)    UTILIDADES FIRMWARE 4 btn  2 filas  h=172
#   G3 (Magenta) HERRAMIENTAS MTK    4 btn  2 filas  h=172
#   Total col izq: 172+8+172+8+172 = 532 < 628 OK
#==========================================================================
$tabGen           = New-Object Windows.Forms.TabPage
$tabGen.Text      = "UTILIDADES GENERALES"
$tabGen.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$tabs.TabPages.Add($tabGen)

# ---- Metricas compartidas con ADB para coherencia visual ----
# Col izq x=6 w=422 | gap=8 | col der x=436 w=422
$GX_PAD  = 6
$GX_LOGX = 436
$GX_GW   = 422
$GX_LOGW = $GX_GW
$GX_BTW  = 195   # mismo que ADB
$GX_BTH  = 56    # mismo que ADB
$GX_PPX  = 14
$GX_PPY  = 20
$GX_GGX  = 8
$GX_GGY  = 8
$GX_GGAP = 8

# Altura de cada grupo: 2 filas de botones
$GX_GH = $GX_PPY + 2*($GX_BTH+$GX_GGY) - $GX_GGY + 14

$GX_Y1 = 6
$GX_Y2 = $GX_Y1 + $GX_GH + $GX_GGAP
$GX_Y3 = $GX_Y2 + $GX_GH + $GX_GGAP

# ---- Grupos columna izquierda ----
$grpG1 = New-GBox $tabGen "FUNCIONES ROOT"      $GX_PAD $GX_Y1 $GX_GW $GX_GH "Red"
$grpG2 = New-GBox $tabGen "UTILIDADES FIRMWARE" $GX_PAD $GX_Y2 $GX_GW $GX_GH "Cyan"
$grpG3 = New-GBox $tabGen "HERRAMIENTAS MTK"    $GX_PAD $GX_Y3 $GX_GW $GX_GH "Magenta"

$GL1=@("BORRAR DATOS","DESHAB. OTA","FLASHEAR ROOT","VERIFICAR ROOT")
$GL2=@("OEMINFO MDM HONOR","MODEM MI ACCOUNT","EFS SAMSUNG SIM 2","PERSIST MI ACCOUNT")
$GL3=@("BYPASS MTK","ESCRIBIR IMEI","LEER IMEI","DESBLOQUEAR BL")

$btnsG1=Place-Grid $grpG1 $GL1 "Red"     2 $GX_BTW $GX_BTH $GX_PPX $GX_PPY $GX_GGX $GX_GGY
$btnsG2=Place-Grid $grpG2 $GL2 "Cyan"    2 $GX_BTW $GX_BTH $GX_PPX $GX_PPY $GX_GGX $GX_GGY
$btnsG3=Place-Grid $grpG3 $GL3 "Magenta" 2 $GX_BTW $GX_BTH $GX_PPX $GX_PPY $GX_GGX $GX_GGY

$btnEditOem  =$btnsG2[0]
$btnEFSMod   =$btnsG2[1]
$btnEFSDirec =$btnsG2[2]
$btnPersist  =$btnsG2[3]

# ---- Log columna derecha — altura completa igual que ADB ----
$GX_LOGY = 6
$GX_LOGH = 616

$Global:logGen           = New-Object Windows.Forms.TextBox
$Global:logGen.Multiline = $true
$Global:logGen.Location  = New-Object System.Drawing.Point($GX_LOGX, $GX_LOGY)
$Global:logGen.Size      = New-Object System.Drawing.Size($GX_LOGW, $GX_LOGH)
$Global:logGen.BackColor = "Black"; $Global:logGen.ForeColor = "White"
$Global:logGen.BorderStyle = "FixedSingle"; $Global:logGen.ScrollBars = "Vertical"
$Global:logGen.Font      = New-Object System.Drawing.Font("Consolas",9)
$tabGen.Controls.Add($Global:logGen)
# Context menu: Limpiar Log
$ctxGen = New-Object System.Windows.Forms.ContextMenuStrip
$mnuClearGen = $ctxGen.Items.Add("Limpiar Log")
$mnuClearGen.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$mnuClearGen.ForeColor = [System.Drawing.Color]::OrangeRed
$mnuClearGen.Add_Click({ $Global:logGen.Clear() })
$Global:logGen.ContextMenuStrip = $ctxGen

