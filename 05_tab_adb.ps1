
#==========================================================================
# LOGICA - TAB SAMSUNG FLASHER
#==========================================================================
$btnRebRec.Add_Click({
    try {
        Assert-DeviceReady -Mode ADB
        OdinLog "[*] Reiniciando Recovery..."
        Invoke-ADB "reboot recovery" -LogSource "SAMSUNG" | Out-Null
        OdinLog "[OK] Enviado."
    } catch { OdinLog "[!] $_" }
})
$btnRebDown.Add_Click({
    try {
        Assert-DeviceReady -Mode ADB
        OdinLog "[*] Reiniciando Download Mode..."
        Invoke-ADB "reboot download" -LogSource "SAMSUNG" | Out-Null
        OdinLog "[OK] Enviado."
    } catch { OdinLog "[!] $_" }
})
$btnReadOdin.Add_Click({
    $btnReadOdin.Enabled=$false; $btnReadOdin.Text="LEYENDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Write-RNXLogSection "LEER INFO ODIN"
        Read-OdinInfoPro
    } catch { OdinLog "[!] Error: $_" }
    finally { $btnReadOdin.Enabled=$true; $btnReadOdin.Text="LEER INFO (ODIN)" }
})
$btnStartFlash.Add_Click({
    $btnStartFlash.Enabled=$false; $btnStartFlash.Text="FLASHEANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Assert-DeviceReady -Mode DOWNLOAD -MinBattery 50 -NeedUnlockedBL
        Write-RNXLogSection "INICIAR FLASHEO SAMSUNG"
        Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "SAMSUNG" }
        Start-FlashPro
    } catch { OdinLog "[!] $_" }
    finally { $btnStartFlash.Enabled=$true; $btnStartFlash.Text="INICIAR FLASHEO" }
})

#==========================================================================
# LOGICA - TAB UTILIDADES ADB
#==========================================================================
$btnReadAdb.Add_Click({
    if ($Global:logAdb) { $Global:logAdb.Clear() }
    AdbLog "[*] Iniciando lectura profunda..."
    if (-not (Check-ADB)) { return }
    try {
        # Helpers null-safe para ADB (evitan error si devuelve array o null)
        function SafeShell {
            param($cmd)
            $r = & adb shell $cmd 2>$null
            if ($null -eq $r) { return "" }
            if ($r -is [array]) { return ($r -join " ").Trim() }
            return $r.ToString().Trim()
        }
        function SafeAdb {
            param($cmd)
            $parts = $cmd -split " "
            $r = & adb @parts 2>$null
            if ($null -eq $r) { return "" }
            if ($r -is [array]) { return ($r -join " ").Trim() }
            return $r.ToString().Trim()
        }

        $brand   = (SafeShell "getprop ro.product.brand").ToUpper()
        $model    = SafeShell "getprop ro.product.model"
        $deviceId = (SafeShell "getprop ro.product.device").ToUpper()
        $modDevId = (SafeShell "getprop ro.product.mod_device").ToUpper()
        $devId    = if ($modDevId -ne "" -and $modDevId -ne $deviceId) { $modDevId } else { $deviceId }
        $modelFull = if ($devId -ne "" -and $devId -ne $model.ToUpper()) { "$model  [$devId]" } else { $model }
        $mfr     = (SafeShell "getprop ro.product.manufacturer").ToUpper()
        $android = SafeShell "getprop ro.build.version.release"
        $patch   = SafeShell "getprop ro.build.version.security_patch"
        $build   = SafeShell "getprop ro.build.display.id"
        $serial  = SafeAdb "get-serialno"
        $bootldr = SafeShell "getprop ro.boot.bootloader"
        $cpu     = Get-TechnicalCPU
        $frp1    = SafeShell "getprop ro.frp.pst"
        $oemLk   = SafeShell "getprop ro.boot.flash.locked"
        $root    = Detect-Root

        # Storage: deteccion multi-senal UFS vs eMMC (solo /sys/class/ufs falla en muchos UFS)
        $ufsNode3 = SafeShell "ls /sys/class/ufs 2>/dev/null"
        $ufsDev3  = SafeShell "ls /dev/block/sda 2>/dev/null"
        $ufsHost3 = SafeShell "ls /sys/bus/platform/drivers/ufshcd 2>/dev/null"
        $ufsType3 = SafeShell "getprop ro.boot.storage_type"
        $mmcBlk3  = SafeShell "ls /dev/block/mmcblk0 2>/dev/null"
        $isUFS3   = ($ufsNode3 -ne "" -or $ufsDev3 -ne "" -or $ufsHost3 -ne "" -or
                     ($ufsType3 -imatch "ufs") -or ($mmcBlk3 -eq "" -and $ufsDev3 -ne ""))
        $storage  = if ($isUFS3) { "UFS" } else { "eMMC" }

        # IMEI via service call
        $imeiRaw = SafeShell "service call iphonesubinfo 1"
        $imei = "UNKNOWN"
        if ($imeiRaw -match "[0-9]{15}") { $imei = $Matches[0] }
        elseif ($imeiRaw -match "Result: Parcel") {
            $digits = ($imeiRaw -replace "[^0-9]","")
            if ($digits.Length -ge 15) { $imei = $digits.Substring(0,15) }
        }

        # Pre-calcular strings para evitar if() dentro de strings
        $frpStr  = if ($frp1  -and $frp1  -ne "") { "PRESENT" } else { "NOT SET"  }
        $oemStr  = if ($oemLk -eq "1")             { "LOCKED"  } else { "UNLOCKED" }
        $rootStr = if ($root  -ne "NO ROOT")        { "SI"      } else { "NO"       }

        AdbLog ""
        AdbLog "=============================================="
        AdbLog "  INFO DISPOSITIVO  -  $brand $modelFull"
        AdbLog "=============================================="
        AdbLog ""
        AdbLog "  MARCA          : $brand"
        AdbLog "  MODELO         : $modelFull"
        AdbLog "  ANDROID        : $android"
        AdbLog "  PARCHE SEG.    : $patch"
        AdbLog "  BUILD          : $build"
        $board_gen = SafeShell "getprop ro.board.platform"
        AdbLog "  CPU            : $cpu"
        if ($board_gen -ne "") { AdbLog "  PLATAFORMA     : $board_gen" }
        AdbLog "  SERIAL         : $serial"
        AdbLog "  STORAGE        : $storage"
        AdbLog ""
        AdbLog "  ROOT           : $rootStr"
        AdbLog "  FRP            : $frpStr"
        AdbLog "  OEM LOCK       : $oemStr"
        AdbLog ""

        # ---- INFO ESPECIFICA POR MARCA ----
        if ($brand -match "SAMSUNG") {
            AdbLog "  --- SAMSUNG ---"
            $cscProp = SafeShell "getprop ro.csc.country.code"
            if ($cscProp -eq "") { $cscProp = SafeShell "getprop ro.product.csc" }
            if ($cscProp -ne "") { AdbLog "  CSC            : $cscProp - $(Get-CSCDecoded $cscProp)" }
            $kg   = SafeShell "getprop ro.boot.kg_state"
            $knox = SafeShell "getprop ro.boot.warranty_bit"
            if ($kg   -ne "") { AdbLog "  KG STATE       : $kg"   }
            if ($knox -ne "") { AdbLog "  WARRANTY VOID  : $knox" }
            $binary = Get-BinaryFromBuild $bootldr
            AdbLog "  BOOTLOADER     : $bootldr"
            AdbLog "  BINARIO        : $binary"
        }
        elseif ($brand -match "MOTOROLA|MOTO|LENOVO") {
            AdbLog "  --- MOTOROLA ---"
            $board  = SafeShell "getprop ro.board.platform"
            $hw     = SafeShell "getprop ro.hardware"
            $sku    = SafeShell "getprop ro.product.device"
            $locale = SafeShell "getprop ro.product.locale"
            $blLk   = SafeShell "getprop ro.boot.flash.locked"
            $blStr  = if ($blLk -eq "1") { "LOCKED" } else { "UNLOCKED" }
            $modVer = SafeShell "getprop ro.product.mod_version"
            $bbRaw  = SafeShell "getprop gsm.version.baseband"
            $bb     = ($bbRaw -split "`n")[0]
            if ($hw -ne $board) { AdbLog "  HARDWARE       : $hw" }
            AdbLog "  DEVICE SKU     : $sku"
            AdbLog "  LOCALE         : $locale"
            AdbLog "  BL ESTADO      : $blStr"
            if ($modVer -ne "") { AdbLog "  MOD VERSION    : $modVer" }
            if ($bb     -ne "") { AdbLog "  BASEBAND       : $bb"     }
            AdbLog "  IMEI           : $imei"
        }
        elseif ($brand -match "XIAOMI|REDMI|POCO") {
            AdbLog "  --- XIAOMI ---"
            $miuiVer  = SafeShell "getprop ro.miui.ui.version.name"
            $miuiBuild= SafeShell "getprop ro.miui.ui.version.code"
            $region   = SafeShell "getprop ro.miui.region"
            $blLk2    = SafeShell "getprop ro.boot.flash.locked"
            $vbs      = SafeShell "getprop ro.boot.verifiedbootstate"
            $blStr2   = if ($blLk2 -eq "1") { "LOCKED" } else { "UNLOCKED" }
            $devProp  = SafeShell "getprop ro.product.device"
            $codename = Get-XiaomiCodename $devProp
            $antiRaw  = SafeShell "getprop ro.boot.anti_version"
            if (-not $antiRaw) { $antiRaw = SafeShell "getprop ro.boot.verifiedbootstate" }
            AdbLog "  MIUI VERSION   : $miuiVer"
            if ($miuiBuild -ne "") { AdbLog "  MIUI BUILD     : $miuiBuild" }
            AdbLog "  REGION MIUI    : $region"
            AdbLog "  BL LOCK        : $blStr2"
            AdbLog "  BOOT STATE     : $vbs"
            AdbLog "  DEVICE         : $devProp"
            if ($codename -ne "" -and $codename -ne $devProp) {
                AdbLog "  CODENAME       : $codename"
            }
            if ($antiRaw -ne "" -and $antiRaw -match "^\d+$") {
                AdbLog "  ANTI-ROLLBACK  : $antiRaw"
            }
            AdbLog "  IMEI           : $imei"
        }
        elseif ($brand -match "HUAWEI|HONOR") {
            AdbLog "  --- HUAWEI ---"
            $emui = SafeShell "getprop ro.build.version.emui"
            $hw2  = SafeShell "getprop ro.hardware"
            AdbLog "  EMUI VERSION   : $emui"
            AdbLog "  HARDWARE       : $hw2"
            AdbLog "  IMEI           : $imei"
        }
        else {
            AdbLog "  --- INFO ADICIONAL ---"
            $board2 = SafeShell "getprop ro.board.platform"
            $bbRaw2 = SafeShell "getprop gsm.version.baseband"
            $bb2    = ($bbRaw2 -split "`n")[0]
            if ($bb2    -ne "") { AdbLog "  BASEBAND       : $bb2"    }
            AdbLog "  IMEI           : $imei"
            AdbLog "  BOOTLOADER     : $bootldr"
        }

        AdbLog ""
        AdbLog "=============================================="
        AdbLog "[OK] LECTURA COMPLETADA"

        # Actualizar sidebar
        $Global:lblDisp.Text      = "DISPOSITIVO : $brand"
        $Global:lblModel.Text     = "MODELO      : $modelFull"
        $Global:lblSerial.Text    = "SERIAL      : $serial"
        $Global:lblCPU.Text       = "CPU         : $cpu"
        $Global:lblStorage.Text   = "STORAGE     : $storage"
        $Global:lblFRP.Text       = "FRP         : $frpStr"
        $Global:lblFRP.ForeColor  = if ($frp1 -and $frp1 -ne "") { [System.Drawing.Color]::Red } else { [System.Drawing.Color]::Lime }
        $Global:lblRoot.Text      = "ROOT        : $rootStr"
        $Global:lblRoot.ForeColor = if ($root -ne "NO ROOT") { [System.Drawing.Color]::Lime } else { [System.Drawing.Color]::Red }

    } catch { AdbLog "[!] Error: $_" }
})
$btnRebootSys.Add_Click({ if (-not (Check-ADB)) { return }; AdbLog "[*] Reiniciando..."; & adb reboot 2>$null; AdbLog "[OK]" })
$btnRebootRec.Add_Click({ if (-not (Check-ADB)) { return }; AdbLog "[*] Recovery..."; & adb reboot recovery 2>$null; AdbLog "[OK]" })
$btnRebootBl.Add_Click({
    if (-not (Check-ADB)) { return }; AdbLog "[*] Bootloader/Download..."
    & adb reboot bootloader 2>$null; & adb reboot download 2>$null; AdbLog "[OK]"
})
#==========================================================================
# AUTOROOT MAGISK 1-CLICK  -  Integrado en boton AUTOROOT MAGISK
# Flujo: Seleccion AP.tar.md5 -> Escaneo rapido TAR -> Extraccion quirurgica
#        boot.img.lz4 o init_boot.img.lz4 -> Parcheo magiskboot en PC ->
#        Generacion .tar -> Flash via Heimdall CLI o apertura Odin
#
# BINARIOS REQUERIDOS en .\tools\
#   magiskboot_v24.exe   <- Magisk 24.1  (modelos legacy: A21s / A13 / A51 5G)
#   magiskboot_v27.exe   <- Magisk 27    (todos los demas modelos)
#   lz4.exe
#   heimdall.exe
#   Odin3.exe            (opcional, fallback GUI)
#
# MODELOS LEGACY (usan magiskboot_v24.exe / Magisk 24.1):
#   SM-A217M  -  Galaxy A21s
#   SM-A135M  -  Galaxy A13 4G
#   SM-A515G  -  Galaxy A51 5G (Exynos)
#==========================================================================

function AutoRoot-Log($msg) {
    AdbLog $msg
}

function AutoRoot-SetStatus($btn, $txt) {
    $btn.Text    = $txt
    $btn.Enabled = ($txt -eq "AUTOROOT MAGISK")
    [System.Windows.Forms.Application]::DoEvents()
}

# ---- Tabla de modelos que requieren Magisk 24.1 (magiskboot legacy) ----
# Estos equipos tienen kernel antiguo incompatible con Magisk 25+
# Agregar aqui nuevos modelos legacy si se identifican
$script:MAGISK_LEGACY_MODELS = @(
    "SM-A217M",   # Galaxy A21s   - Exynos 850
    "SM-A135M",   # Galaxy A13 4G - Exynos 850
    "SM-A515G"    # Galaxy A51 5G - Exynos 980
)
$script:MAGISKBOOT    = Join-Path $script:TOOLS_DIR "magiskboot.exe"   # Windows x64 nativo
$script:MAGISK_APK_27 = Join-Path $script:TOOLS_DIR "magisk27.apk"
$script:MAGISK_APK_24 = Join-Path $script:TOOLS_DIR "magisk24.apk"
$script:MAGISK_BINS   = Join-Path $script:TOOLS_DIR "magisk_bins"      # cache de binarios extraidos

# ---- Extrae binarios ARM64 del APK de Magisk usando 7z ----
function Extract-MagiskBins($apkPath, $binsDir, $label) {
    $7z = Join-Path $script:TOOLS_DIR "7z.exe"
    if (-not (Test-Path $7z)) { AutoRoot-Log "[!] 7z.exe no encontrado en .\tools\"; return $false }
    if (-not (Test-Path $binsDir)) { New-Item $binsDir -ItemType Directory -Force | Out-Null }
    AutoRoot-Log "[~] Extrayendo binarios Magisk de $label ..."
    & $7z x "$apkPath" "lib\arm64-v8a\*" "-o$binsDir" -y 2>&1 | Out-Null
    $arm64 = Join-Path $binsDir "lib\arm64-v8a"
    if (-not (Test-Path $arm64)) {
        AutoRoot-Log "[!] No se encontro lib\arm64-v8a en el APK"
        return $false
    }
    $map = @{
        "libmagisk64.so"   = "magisk64"
        "libmagisk32.so"   = "magisk32"
        "libmagiskinit.so" = "magiskinit"
        "libstub.so"       = "stub.apk"
    }
    foreach ($so in $map.Keys) {
        $src = Join-Path $arm64 $so
        $dst = Join-Path $binsDir $map[$so]
        if (Test-Path $src) { Copy-Item $src $dst -Force; AutoRoot-Log "  [+] $so -> $($map[$so])" }
    }
    if (Test-Path (Join-Path $binsDir "magiskinit")) {
        AutoRoot-Log "[+] Binarios Magisk extraidos OK en: $binsDir"
        return $true
    }
    AutoRoot-Log "[!] magiskinit no encontrado - APK puede estar corrupto"
    return $false
}

# ---- Selector automatico de version de Magisk segun modelo ----
function Get-MagiskbootExe($model) {
    $modelClean = $model.Trim().ToUpper()
    $isLegacy   = $false
    foreach ($leg in $script:MAGISK_LEGACY_MODELS) {
        if ($modelClean -eq $leg.ToUpper()) { $isLegacy = $true; break }
    }
    $apkToUse = if ($isLegacy) { $script:MAGISK_APK_24 } else { $script:MAGISK_APK_27 }
    $apkLabel = if ($isLegacy) { "magisk24.apk (Magisk 24.1 - legacy)" } else { "magisk27.apk (Magisk 27)" }
    if ($isLegacy) {
        AutoRoot-Log "[*] MODELO LEGACY detectado: $modelClean"
        AutoRoot-Log "[*] Usando Magisk 24.1 (kernel antiguo incompatible con Magisk 25+)"
    } else {
        AutoRoot-Log "[*] Modelo estandar: $modelClean"
        AutoRoot-Log "[*] Usando Magisk 27"
    }
    if (-not (Test-Path $script:MAGISKBOOT)) {
        AutoRoot-Log "[!] magiskboot.exe no encontrado en .\tools\"
        AutoRoot-Log "[~] Descarga: github.com/affggh/magiskboot_build/releases"
        AutoRoot-Log "[~] Archivo : magiskboot-...-windows-mingw-w64-ucrt-x86_64..."
        return $null
    }
    $binsDirSub = if ($isLegacy) { "v24" } else { "v27" }
    $binsDir = Join-Path $script:MAGISK_BINS $binsDirSub
    $initBin = Join-Path $binsDir "magiskinit"
    if (-not (Test-Path $initBin)) {
        if (-not (Test-Path $apkToUse)) {
            AutoRoot-Log "[!] APK no encontrado: $apkToUse"
            AutoRoot-Log "[~] Coloca $([System.IO.Path]::GetFileName($apkToUse)) en .\tools\"
            return $null
        }
        $ok = Extract-MagiskBins $apkToUse $binsDir $apkLabel
        if (-not $ok) { return $null }
    } else {
        AutoRoot-Log "[+] Binarios Magisk en cache: $binsDir"
    }
    return @{ Exe = (Resolve-Path $script:MAGISKBOOT).Path; BinsDir = $binsDir; IsLegacy = $isLegacy }
}

# ---- Busqueda rapida en TAR sin extraer todo (solo lee cabeceras) ----
function Find-BootInTar($tarPath) {
    $result = @{ Target=$null; InitBoot=$false; Boot=$false; InitBootFile=$null; BootFile=$null }
    try {
        $hasTar = Get-Command tar -ErrorAction SilentlyContinue
        if (-not $hasTar) {
            AutoRoot-Log "[!] tar.exe no encontrado. Requiere Windows 10 build 17063+"
            return $result
        }
        AutoRoot-Log "[~] Escaneando indice TAR (sin extraer)..."
        $listing = & tar -tf "$tarPath" 2>&1
        foreach ($line in $listing) {
            $name = "$line".Trim()
            if ($name -imatch "init_boot\.img\.lz4$" -or $name -imatch "init_boot\.lz4$") {
                $result.InitBoot = $true
                $result.InitBootFile = $name
            }
            if ($name -imatch "^boot\.img\.lz4$" -or $name -imatch "^boot\.lz4$") {
                $result.Boot = $true
                $result.BootFile = $name
            }
        }
        # Regla simple:
        #   solo init_boot         -> usar init_boot
        #   solo boot              -> usar boot
        #   ambos (boot+init_boot) -> usar init_boot
        if ($result.InitBoot)       { $result.Target = $result.InitBootFile }
        elseif ($result.Boot)       { $result.Target = $result.BootFile }
    } catch { AutoRoot-Log "[!] Error escaneando TAR: $_" }
    return $result
}

# ---- Extraccion quirurgica: solo 1 archivo del TAR grande ----
function Extract-SingleFromTar($tarPath, $targetFile, $outDir) {
    try {
        if (-not (Test-Path $outDir)) { New-Item $outDir -ItemType Directory -Force | Out-Null }
        AutoRoot-Log "[~] Extrayendo: $targetFile"
        & tar -xf "$tarPath" -C "$outDir" "$targetFile" 2>&1 | Out-Null
        $extracted = Get-ChildItem $outDir -Recurse -Filter ($targetFile -replace ".*/","") -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($extracted -and (Test-Path $extracted.FullName)) {
            AutoRoot-Log "[+] Extraido: $($extracted.FullName) ($([math]::Round($extracted.Length/1KB,1)) KB)"
            return $extracted.FullName
        }
        AutoRoot-Log "[!] No se encontro el archivo extraido en: $outDir"
    } catch { AutoRoot-Log "[!] Error en extraccion: $_" }
    return $null
}

# ---- Descomprimir LZ4 usando lz4.exe del directorio tools ----
function Expand-LZ4($lz4Path, $outImg) {
    $lz4exe = $null
    foreach ($candidate in @((Join-Path $script:TOOLS_DIR "lz4.exe"), ".\lz4.exe", "lz4")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) { $lz4exe = $candidate; break }
        if (Test-Path $candidate) { $lz4exe = $candidate; break }
    }
    if (-not $lz4exe) {
        # Fallback: usar 7z si disponible (puede descomprimir LZ4)
        foreach ($z in @((Join-Path $script:TOOLS_DIR "7z.exe"),".\7z.exe","7z")) {
            if (Get-Command $z -ErrorAction SilentlyContinue -or (Test-Path $z)) {
                AutoRoot-Log "[~] Descomprimiendo LZ4 con 7z..."
                & $z e "$lz4Path" "-o$(Split-Path $outImg)" -y 2>&1 | Out-Null
                $extracted = Get-ChildItem (Split-Path $outImg) -File | Where-Object { $_.Extension -ne ".lz4" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($extracted) { Rename-Item $extracted.FullName $outImg -Force -EA SilentlyContinue; return (Test-Path $outImg) }
            }
        }
        AutoRoot-Log "[!] lz4.exe no encontrado. Coloca lz4.exe en .\tools\"
        AutoRoot-Log "[~] Descarga desde: https://github.com/lz4/lz4/releases"
        return $false
    }
    AutoRoot-Log "[~] Descomprimiendo LZ4 -> $([System.IO.Path]::GetFileName($outImg))"
    & $lz4exe -d -f "$lz4Path" "$outImg" 2>&1 | Out-Null
    return (Test-Path $outImg)
}

# ---- Parchear boot con magiskboot.exe (Windows x64) + binarios ARM64 del APK ----
# $mbInfo: hashtable { Exe, BinsDir, IsLegacy } devuelto por Get-MagiskbootExe
function Patch-BootWithMagiskboot($imgPath, $workDir, $mbInfo) {
    if (-not $mbInfo -or -not (Test-Path $mbInfo.Exe)) {
        AutoRoot-Log "[!] magiskboot.exe no encontrado"
        return $null
    }
    $mbExe   = $mbInfo.Exe
    $binsDir = $mbInfo.BinsDir
    AutoRoot-Log "[+] magiskboot : $([System.IO.Path]::GetFileName($mbExe))"
    AutoRoot-Log "[+] Binarios   : $binsDir"

    if (-not (Test-Path $workDir)) { New-Item $workDir -ItemType Directory -Force | Out-Null }
    $imgName    = [System.IO.Path]::GetFileName($imgPath)
    $workImg    = Join-Path $workDir $imgName
    $patchedImg = Join-Path $workDir "patched_$imgName"
    Copy-Item $imgPath $workImg -Force

    # Copiar binarios ARM64 al workdir (magiskboot los busca en el directorio actual)
    foreach ($bin in @("magisk64","magisk32","magiskinit","stub.apk")) {
        $src = Join-Path $binsDir $bin
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $workDir $bin) -Force
            AutoRoot-Log "  [+] Copiado: $bin"
        }
    }

    $origDir = Get-Location
    try {
        Set-Location $workDir

        # PASO 1: Desempaquetar boot.img
        AutoRoot-Log "[~] Paso 1/3: magiskboot unpack $imgName"
        $out = & $mbExe unpack $imgName 2>&1
        $out | ForEach-Object { $line = "$_".Trim(); if ($line) { AutoRoot-Log "    $line" } }

        if (-not (Test-Path "ramdisk.cpio")) {
            AutoRoot-Log "[!] magiskboot unpack no genero ramdisk.cpio"
            AutoRoot-Log "[!] Verifica que boot.img sea valido y no este corrupto"
            return $null
        }
        AutoRoot-Log "[+] Unpack OK - ramdisk.cpio generado"

        # PASO 2: Inyectar Magisk en el ramdisk
        # Metodo exacto de customize.sh de Magisk:
        #   - "add 0750 init magiskinit"  reemplaza /init con el init de Magisk
        #   - "mkdir 0750 overlay.d"      directorio para overlays de Magisk
        #   - "mkdir 0750 overlay.d/sbin" overlay del sbin de Magisk  
        #   - "patch"                     CRITICO: parchea SHA1, dm-verity y AVB
        #                                 sin este comando Magisk aparece en gris
        # Todo en UN SOLO comando cpio (no llamadas separadas)
        AutoRoot-Log "[~] Paso 2/3: Inyectando Magisk en ramdisk (metodo oficial)..."
        $injectOut = & $mbExe cpio ramdisk.cpio `
            "add 0750 init magiskinit" `
            "mkdir 0750 overlay.d" `
            "mkdir 0750 overlay.d/sbin" `
            "patch" 2>&1
        $injectOut | ForEach-Object { $line = "$_".Trim(); if ($line) { AutoRoot-Log "    $line" } }

        if (-not (Test-Path "ramdisk.cpio")) {
            AutoRoot-Log "[!] ramdisk.cpio desaparecio tras la inyeccion"
            return $null
        }
        AutoRoot-Log "[+] Inyeccion OK"

        # PASO 3: Reempaquetar boot.img parcheado
        # magiskboot repack usa el boot.img original como referencia para
        # mantener cabecera, kernel, dtb y parametros exactos
        AutoRoot-Log "[~] Paso 3/3: magiskboot repack $imgName"
        $repackOut = & $mbExe repack $imgName 2>&1
        $repackOut | ForEach-Object { $line = "$_".Trim(); if ($line) { AutoRoot-Log "    $line" } }

        # magiskboot repack genera siempre "new-boot.img" en el directorio actual
        $newBoot = Join-Path $workDir "new-boot.img"
        if (Test-Path $newBoot) {
            $sz = [math]::Round((Get-Item $newBoot).Length/1KB,1)
            AutoRoot-Log "[+] Boot parcheado OK: new-boot.img ($sz KB)"
            # Renombrar a patched_boot.img para consistencia
            Rename-Item $newBoot $patchedImg -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $patchedImg)) {
                # Si el rename fallo (mismo nombre u otro problema), usar new-boot.img directo
                $patchedImg = $newBoot
            }
            return $patchedImg
        } else {
            # Algunos builds de magiskboot usan "patched_$imgName" como nombre de salida
            $altOut = Join-Path $workDir "patched_$imgName"
            if (Test-Path $altOut) {
                $sz = [math]::Round((Get-Item $altOut).Length/1KB,1)
                AutoRoot-Log "[+] Boot parcheado OK: patched_$imgName ($sz KB)"
                return $altOut
            }
            AutoRoot-Log "[!] magiskboot repack no genero new-boot.img ni patched_$imgName"
            AutoRoot-Log "[!] Revisa el log de repack arriba para ver el error"
            return $null
        }
    } catch {
        AutoRoot-Log "[!] Error en parcheo: $_"
        return $null
    } finally {
        Set-Location $origDir
        foreach ($tmp in @("kernel","kernel_dtb","ramdisk.cpio","dtb","extra",
                           "recovery_dtbo","vbmeta","magisk64","magisk32",
                           "magiskinit","stub.apk","config")) {
            Remove-Item (Join-Path $workDir $tmp) -Force -EA SilentlyContinue
        }
    }
}

# ---- Crear .tar compatible con Odin (formato USTAR, sin extensiones GNU) ----
# tar.exe de Windows genera cabeceras GNU que Odin no acepta -> congela en NAND Write.
# Se escribe el TAR byte a byte en formato USTAR puro que Odin acepta correctamente.
function Build-OdinTar($imgPath, $outDir, $isInitBootHint = $null) {
    # El nombre del archivo DENTRO del TAR determina a que particion flashea Odin:
    #   "boot.img"       -> particion BOOT      (correcto)
    #   "patched_boot.img" -> "Unassigned file" -> FAIL
    # Se usa el nombre canonico segun el tipo de imagen detectado.
    # $isInitBootHint: $true/$false pasado desde el caller (mas fiable que el nombre del archivo)
    $origName = [System.IO.Path]::GetFileName($imgPath)
    $detectedInitBoot = if ($isInitBootHint -ne $null) {
        [bool]$isInitBootHint
    } else {
        $origName -imatch "init_boot"
    }
    $tarEntryName = if ($detectedInitBoot) { "init_boot.img" } else { "boot.img" }
    $tarName = "autoroot_patched.tar"
    $tarPath = [System.IO.Path]::Combine($outDir, $tarName)
    try {
        if (-not (Test-Path $outDir)) { New-Item $outDir -ItemType Directory -Force | Out-Null }
        AutoRoot-Log "[~] Creando $tarName (nombre en TAR: $tarEntryName)..."

        $imgBytes   = [System.IO.File]::ReadAllBytes($imgPath)
        $imgSize    = $imgBytes.Length
        $fileStream = [System.IO.File]::Open($tarPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)

        # Cabecera USTAR 512 bytes - todos los campos en ASCII, null-padded
        $header = New-Object byte[] 512

        # Nombre (offset 0, 100 bytes) - nombre canonico que Odin reconoce
        $nameB = [System.Text.Encoding]::ASCII.GetBytes($tarEntryName)
        $nameL = [Math]::Min($nameB.Length, 99)
        [Array]::Copy($nameB, 0, $header, 0, $nameL)

        # Modo (offset 100, 8 bytes): "0000644" + null
        $modeB = [System.Text.Encoding]::ASCII.GetBytes("0000644")
        [Array]::Copy($modeB, 0, $header, 100, $modeB.Length)
        $header[107] = 0  # null terminator

        # UID (offset 108, 8 bytes): "0000000" + null
        $uidB = [System.Text.Encoding]::ASCII.GetBytes("0000000")
        [Array]::Copy($uidB, 0, $header, 108, $uidB.Length)
        $header[115] = 0

        # GID (offset 116, 8 bytes): "0000000" + null
        [Array]::Copy($uidB, 0, $header, 116, $uidB.Length)
        $header[123] = 0

        # Tamano (offset 124, 12 bytes): 11 digitos octales + espacio
        $sizeStr = [Convert]::ToString($imgSize, 8).PadLeft(11, [char]'0') + " "
        $sizeB   = [System.Text.Encoding]::ASCII.GetBytes($sizeStr)
        [Array]::Copy($sizeB, 0, $header, 124, $sizeB.Length)

        # Mtime (offset 136, 12 bytes): timestamp octal + espacio
        $mtime    = [long]([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
        $mtimeStr = [Convert]::ToString($mtime, 8).PadLeft(11, [char]'0') + " "
        $mtimeB   = [System.Text.Encoding]::ASCII.GetBytes($mtimeStr)
        [Array]::Copy($mtimeB, 0, $header, 136, $mtimeB.Length)

        # Checksum placeholder (offset 148, 8 bytes): 8 espacios
        for ($ci = 148; $ci -lt 156; $ci++) { $header[$ci] = 0x20 }

        # Tipo de archivo (offset 156): '0' = archivo regular
        $header[156] = [byte][char]'0'

        # Magic USTAR (offset 257, 6 bytes): "ustar" + espacio + null
        $magicB = [System.Text.Encoding]::ASCII.GetBytes("ustar ")
        [Array]::Copy($magicB, 0, $header, 257, $magicB.Length)
        $header[263] = 0x20  # version " "
        $header[264] = 0x20  # version " "

        # Calcular checksum real (suma de todos los bytes, con checksum=espacios)
        $chkSum = 0
        for ($ci = 0; $ci -lt 512; $ci++) { $chkSum += $header[$ci] }

        # Escribir checksum: 6 digitos octales + null + espacio
        $chkStr = [Convert]::ToString($chkSum, 8).PadLeft(6, [char]'0')
        $chkB   = [System.Text.Encoding]::ASCII.GetBytes($chkStr)
        [Array]::Copy($chkB, 0, $header, 148, $chkB.Length)
        $header[154] = 0     # null
        $header[155] = 0x20  # espacio

        # Escribir cabecera + datos + padding + EOF
        $fileStream.Write($header, 0, 512)
        $fileStream.Write($imgBytes, 0, $imgSize)
        $pad = (512 - ($imgSize % 512)) % 512
        if ($pad -gt 0) { $fileStream.Write((New-Object byte[] $pad), 0, $pad) }
        $fileStream.Write((New-Object byte[] 1024), 0, 1024)
        $fileStream.Close()

        $sz = [math]::Round((Get-Item $tarPath).Length / 1MB, 2)
        AutoRoot-Log "[+] TAR USTAR creado: $tarPath ($sz MB)"

        # Crear .tar.md5: TAR + newline + md5hex + 2espacios + nombre + newline
        $md5Name = $tarName + ".md5"
        $md5Path = [System.IO.Path]::Combine($outDir, $md5Name)
        $md5hex  = (Get-FileHash $tarPath -Algorithm MD5).Hash.ToLower()
        Copy-Item $tarPath $md5Path -Force
        $hashLine  = [System.Text.Encoding]::ASCII.GetBytes("`n$md5hex  $tarEntryName`n")
        $fsmd5     = [System.IO.File]::Open($md5Path, [System.IO.FileMode]::Append)
        $fsmd5.Write($hashLine, 0, $hashLine.Length)
        $fsmd5.Close()

        AutoRoot-Log "[+] TAR.MD5 creado: $md5Path"
        AutoRoot-Log "[+] MD5: $md5hex"
        return @{ Tar=$tarPath; TarMd5=$md5Path; ImgName=$tarEntryName }

    } catch { AutoRoot-Log "[!] Error creando TAR: $_" }
    return $null
}

# ---- Flash via Heimdall CLI (automatico) ----
function Flash-WithHeimdall($imgPath, $partitionFlag) {
    $heimdall = $null
    foreach ($c in @((Join-Path $script:TOOLS_DIR "heimdall.exe"),".\heimdall.exe","heimdall")) {
        if (Test-Path $c) { $heimdall = $c; break }
        if (Get-Command $c -ErrorAction SilentlyContinue) { $heimdall = $c; break }
    }
    if (-not $heimdall) {
        AutoRoot-Log "[!] heimdall.exe no encontrado en .\tools\"
        return $false
    }
    AutoRoot-Log "[~] Flash via Heimdall: --$partitionFlag"
    AutoRoot-Log "[~] Asegurate que el equipo este en DOWNLOAD MODE"
    AutoRoot-Log "[~] (Vol- + Power o: adb reboot download)"
    $heimArgs = "flash --$partitionFlag `"$imgPath`" --no-reboot"
    AutoRoot-Log "[~] CMD: heimdall $heimArgs"
    $exit = Invoke-HeimdallLive $heimArgs
    return ($exit -eq 0)
}

# ---- Abrir Odin con el .tar.md5 listo para flashear ----
# Logica: SIEMPRE extrae a carpeta temporal nueva (nombre unico por timestamp+random)
#   - Si existe un Odin3.exe directo en tools\, se copia a una carpeta temporal
#     nueva para tener instancia limpia con su propio Odin3.ini
#   - Si solo existe Odin3.zip, se extrae siempre al temp nuevo
#   - Al cerrar Odin, un Job de background borra TODA la carpeta temporal
#   - Cada ejecucion es independiente: sin residuos de la anterior
function Open-OdinWithBoot($tarMd5Path) {

    # --- Paso 1: Crear carpeta temporal UNICA para esta ejecucion ---
    # Siempre nueva, independiente de ejecuciones anteriores
    $runId       = (Get-Date -Format "yyyyMMdd_HHmmss") + "_" + ([System.IO.Path]::GetRandomFileName() -replace "\.",""  )
    $odinTempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "rnx_odin_$runId")
    New-Item $odinTempDir -ItemType Directory -Force | Out-Null
    AutoRoot-Log "[~] Carpeta Odin temporal: $odinTempDir"

    $odin = $null

    # Buscar Odin3.exe directo en tools\ o raiz
    $odinDirect = $null
    foreach ($c in @((Join-Path $script:TOOLS_DIR "Odin3.exe"), ".\Odin3.exe")) {
        if (Test-Path $c) { $odinDirect = (Resolve-Path $c).Path; break }
    }

    if ($odinDirect) {
        # Copiar Odin3.exe a la carpeta temporal para instancia limpia
        AutoRoot-Log "[~] Copiando Odin3.exe a instancia temporal..."
        try {
            $odinSrcDir = Split-Path $odinDirect
            # Copiar todos los archivos del directorio de Odin (DLLs, etc.)
            Get-ChildItem $odinSrcDir -File | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $odinTempDir $_.Name) -Force -EA SilentlyContinue
            }
            $odin = Join-Path $odinTempDir "Odin3.exe"
            if (Test-Path $odin) {
                AutoRoot-Log "[+] Odin3.exe copiado a instancia temporal OK"
            } else {
                # Fallback: usar directo si la copia fallo
                $odin = $odinDirect
                AutoRoot-Log "[~] Copia fallo - usando Odin3.exe directo (sin autolimpieza)"
                $odinTempDir = $null
            }
        } catch {
            $odin = $odinDirect
            AutoRoot-Log "[~] Error copiando Odin: $_ - usando directo"
            $odinTempDir = $null
        }
    } else {
        # Sin Odin3.exe directo - buscar ZIP y extraer siempre de nuevo
        $odinZip = Join-Path $script:TOOLS_DIR "Odin3.zip"
        if (Test-Path $odinZip) {
            AutoRoot-Log "[~] Extrayendo Odin3.zip a instancia temporal..."
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
                [System.IO.Compression.ZipFile]::ExtractToDirectory($odinZip, $odinTempDir)
                AutoRoot-Log "[+] ZIP extraido OK en: $odinTempDir"
            } catch {
                AutoRoot-Log "[!] Error extrayendo ZIP: $_"
            }
            $found = Get-ChildItem $odinTempDir -Recurse -Filter "Odin3.exe" -EA SilentlyContinue | Select-Object -First 1
            if ($found) {
                $odin = $found.FullName
                AutoRoot-Log "[+] Odin3.exe encontrado: $odin"
            } else {
                AutoRoot-Log "[!] Odin3.exe no encontrado en el ZIP"
            }
        } else {
            AutoRoot-Log "[!] Ni Odin3.exe ni Odin3.zip encontrados en .\tools"
        }
    }

    # --- Paso 2: Suprimir EULA via registro + Odin3.ini en la carpeta temporal ---
    try {
        $odinRegPath = "HKCU:\Software\Odin3"
        if (-not (Test-Path $odinRegPath)) { New-Item -Path $odinRegPath -Force | Out-Null }
        Set-ItemProperty -Path $odinRegPath -Name "EULA"         -Value 1    -Type DWord  -Force -EA SilentlyContinue
        Set-ItemProperty -Path $odinRegPath -Name "AgreeEULA"    -Value 1    -Type DWord  -Force -EA SilentlyContinue
        Set-ItemProperty -Path $odinRegPath -Name "AcceptLicense" -Value "1" -Type String -Force -EA SilentlyContinue
        AutoRoot-Log "[+] EULA Odin suprimida via registro"
    } catch { AutoRoot-Log "[~] Registro EULA no aplicado: $_" }

    # Escribir Odin3.ini en la carpeta temporal para suprimir EULA al abrir
    if ($odin -and (Test-Path (Split-Path $odin))) {
        try {
            $odinIni = Join-Path (Split-Path $odin) "Odin3.ini"
            [System.IO.File]::WriteAllText($odinIni,
                "[Setting]`r`nAgreeEULA=1`r`nEULA=1`r`nAcceptLicense=1`r`n",
                [System.Text.Encoding]::ASCII)
            AutoRoot-Log "[+] Odin3.ini generado en instancia temporal"
        } catch { }
    }

    # --- Paso 3: Copiar ruta del .tar.md5 al portapapeles ---
    $clipOk = $false
    try {
        [System.Windows.Forms.Clipboard]::SetText($tarMd5Path)
        $clipOk = $true
        AutoRoot-Log "[+] Portapapeles: $([System.IO.Path]::GetFileName($tarMd5Path))  (Ctrl+V en Odin)"
    } catch {
        try { $tarMd5Path | & clip.exe; $clipOk = $true; AutoRoot-Log "[+] Portapapeles OK (clip.exe)" }
        catch { AutoRoot-Log "[~] Portapapeles no disponible: $_" }
    }

    if (-not $odin) {
        AutoRoot-Log "[!] No se encontro Odin3.exe ni Odin3.zip en .\tools"
        AutoRoot-Log "[~] Abre Odin manualmente y carga en slot AP:"
        AutoRoot-Log "    $tarMd5Path$(if ($clipOk) { '  <- ya en portapapeles, Ctrl+V' })"
        # Limpiar carpeta temporal si no se llego a usar
        if ($odinTempDir -and (Test-Path $odinTempDir)) {
            Remove-Item $odinTempDir -Recurse -Force -EA SilentlyContinue
        }
        Start-Process explorer.exe (Split-Path $tarMd5Path) -EA SilentlyContinue
        return
    }

    # --- Paso 4: Lanzar Odin desde la carpeta temporal ---
    AutoRoot-Log "[~] Abriendo Odin3 (instancia temporal: $runId)..."
    $odinDir  = Split-Path $odin
    $odinProc = $null
    try {
        $psi                  = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName         = $odin
        $psi.WorkingDirectory = $odinDir
        $psi.UseShellExecute  = $true
        $odinProc = [System.Diagnostics.Process]::Start($psi)
        AutoRoot-Log "[+] Odin3 abierto (PID: $($odinProc.Id))"
    } catch {
        try {
            $odinProc = Start-Process $odin -WorkingDirectory $odinDir -PassThru -EA Stop
            AutoRoot-Log "[+] Odin3 abierto fallback (PID: $($odinProc.Id))"
        } catch { AutoRoot-Log "[!] No se pudo abrir Odin3.exe: $_" }
    }

    # --- Paso 5: Job de autodestruccion - borra TODA la carpeta temporal al cerrar Odin ---
    # Se ejecuta siempre que haya carpeta temporal, independientemente de si fue
    # extraido del ZIP o copiado desde el directo
    if ($odinProc -and $odinTempDir -and (Test-Path $odinTempDir)) {
        $cleanupDir = $odinTempDir   # captura en scope local para el job
        $null = Start-Job -ScriptBlock {
            param($procId, $dirPath)
            # Esperar a que Odin cierre
            try {
                $p = Get-Process -Id $procId -EA SilentlyContinue
                if ($p) { $p.WaitForExit() }
            } catch {}
            # Espera adicional para que Odin libere todos los archivos
            Start-Sleep -Seconds 3
            # Borrar toda la carpeta temporal
            try {
                Remove-Item -Path $dirPath -Recurse -Force -EA SilentlyContinue
            } catch {}
            # Segunda pasada por si quedaron archivos bloqueados
            Start-Sleep -Seconds 2
            if (Test-Path $dirPath) {
                try { Remove-Item -Path $dirPath -Recurse -Force -EA SilentlyContinue } catch {}
            }
        } -ArgumentList $odinProc.Id, $cleanupDir
        AutoRoot-Log "[~] Autolimpieza activada - carpeta se borra al cerrar Odin"
    }

    # --- Paso 6: Instrucciones ---
    AutoRoot-Log ""
    AutoRoot-Log "================================================"
    AutoRoot-Log "  ODIN ABIERTO - SIGUE ESTOS PASOS:"
    AutoRoot-Log "================================================"
    AutoRoot-Log "  1. Clic en [ AP ] en Odin"
    AutoRoot-Log "  2. Pega con  Ctrl+V  en el dialogo de archivo"
    AutoRoot-Log "     (la ruta ya esta en tu portapapeles)"
    AutoRoot-Log "     Archivo: $([System.IO.Path]::GetFileName($tarMd5Path))"
    AutoRoot-Log "  3. Equipo en DOWNLOAD MODE"
    AutoRoot-Log "     Vol- + Power  o  adb reboot download"
    AutoRoot-Log "  4. Clic en [ Start ] en Odin"
    AutoRoot-Log "================================================"
    AutoRoot-Log "  Ruta: $tarMd5Path"
    AutoRoot-Log "================================================"

    Start-Process explorer.exe (Split-Path $tarMd5Path) -EA SilentlyContinue
}

# ---- Verificar root post-flash ----
function Verify-RootPost {
    AutoRoot-Log "[~] Esperando que el equipo reinicie (30s)..."
    for ($i = 30; $i -gt 0; $i -= 5) {
        Start-Sleep -Seconds 5
        [System.Windows.Forms.Application]::DoEvents()
        $dev = (& adb devices 2>$null) | Where-Object { $_ -match "	device" }
        if ($dev) { break }
        AutoRoot-Log "[~] Esperando ADB... ($i s)"
    }
    $rootCheck = (& adb shell "su -c id" 2>$null)
    if ($rootCheck -match "uid=0") {
        AutoRoot-Log ""
        AutoRoot-Log "[OK] ============================================"
        AutoRoot-Log "[OK]   ROOT CONFIRMADO - Magisk activo         "
        AutoRoot-Log "[OK] ============================================"
        $Global:lblRoot.Text      = "ROOT        : SI (MAGISK)"
        $Global:lblRoot.ForeColor = [System.Drawing.Color]::Lime
        return $true
    } else {
        AutoRoot-Log "[!] Root no detectado aun - puede necesitar reinicio adicional"
        AutoRoot-Log "[~] Abre Magisk en el telefono para completar la instalacion"
        return $false
    }
}

# ---- HANDLER PRINCIPAL DEL BOTON ----
$btnRemFRP.Text = "AUTOROOT MAGISK"
$btnRemFRP.ForeColor = [System.Drawing.Color]::Magenta
$btnRemFRP.FlatAppearance.BorderColor = [System.Drawing.Color]::Magenta

# Bypass Bancario: dorado para diferenciarlo del grupo Orange
$btnsA2[1].Text = "BYPASS BANCARIO"
$btnsA2[1].ForeColor = [System.Drawing.Color]::FromArgb(255,215,0)
$btnsA2[1].BackColor = [System.Drawing.Color]::FromArgb(40,35,10)
$btnsA2[1].FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255,215,0)
$btnsA2[1].Font = New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold)

$btnRemFRP.Add_Click({
    $btn = $btnRemFRP

    # --- PASO 0: Mensaje inicial y verificaciones ---
    $Global:logAdb.Clear()
    AutoRoot-Log "=============================================="
    AutoRoot-Log "   AUTOROOT MAGISK 1-CLICK  -  RNX TOOL PRO"
    AutoRoot-Log "=============================================="
    AutoRoot-Log ""
    AutoRoot-Log "[*] REQUISITOS:"
    AutoRoot-Log "    1. Bootloader DESBLOQUEADO (KG: Prenormal)"
    AutoRoot-Log "    2. Equipo conectado con USB Debugging activado"
    AutoRoot-Log "    3. magiskboot.exe (Windows x64) en .\tools\"
    AutoRoot-Log "    4. magisk27.apk (y magisk24.apk para modelos legacy) en .\tools\"
    AutoRoot-Log "    5. lz4.exe en .\tools\"
    AutoRoot-Log "    6. heimdall.exe en .\tools\ (o Odin3.exe)"
    AutoRoot-Log "    (la version de Magisk se elige automaticamente segun el modelo)"
    AutoRoot-Log ""

    # Verificar ADB activo usando la capa de servicios
    try {
        Assert-DeviceReady -Mode ADB -MinBattery 50
    } catch {
        AutoRoot-Log "[!] $_"
        AutoRoot-Log "[~] Conecta el equipo con USB Debugging activado."
        AutoRoot-Log "[~] Si el bootloader esta abierto y estas en recovery,"
        AutoRoot-Log "[~] activa ADB desde: Ajustes > Opciones desarrollador > Depuracion USB"
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }

    # Loguear estado del dispositivo antes de la operacion
    Write-RNXLogSection "AUTOROOT MAGISK"
    Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "ADB" }

    # --- PASO 1: Leer info del dispositivo directamente con adb shell getprop ---
    # (Invoke-ADBGetprop puede devolver vacio si el wrapper filtra la salida;
    #  se lee directo para garantizar que los datos aparezcan en el log)
    AutoRoot-Log "[1] Leyendo informacion del dispositivo..."
    AutoRoot-SetStatus $btn "LEYENDO INFO..."
    [System.Windows.Forms.Application]::DoEvents()

    function AR-Prop($prop) {
        try {
            $r = (& adb shell getprop $prop 2>$null)
            if ($r -is [array]) { $r = ($r -join "").Trim() } else { $r = "$r".Trim() }
            # Filtrar ruido del daemon ADB
            $r = ($r -split "`n") | Where-Object { $_ -notmatch "daemon|starting|successfully|List of devices|^\s*$" } | Select-Object -First 1
            return if ($r) { $r.Trim() } else { "" }
        } catch { return "" }
    }

    $devModel    = AR-Prop "ro.product.model"
    $devBuild    = AR-Prop "ro.build.display.id"
    $devAndroid  = AR-Prop "ro.build.version.release"
    $devPatch    = AR-Prop "ro.build.version.security_patch"
    $devCodename = AR-Prop "ro.product.device"
    $devCsc      = AR-Prop "ro.csc.sales_code"
    if (-not $devCsc) { $devCsc = AR-Prop "ro.csc.country.code" }
    $oemLock     = AR-Prop "ro.boot.flash.locked"
    try {
        $devSerial = ((& adb get-serialno 2>$null) | Where-Object { $_ -notmatch "daemon|starting|^\s*$" } | Select-Object -First 1).Trim()
    } catch { $devSerial = "" }

    # Mostrar siempre, incluso si vacio (para diagnostico)
    AutoRoot-Log "    MODELO      : $(if($devModel)  {$devModel}  else {'(no disponible)'})"
    AutoRoot-Log "    BUILD       : $(if($devBuild)  {$devBuild}  else {'(no disponible)'})"
    AutoRoot-Log "    ANDROID     : $(if($devAndroid){$devAndroid} else {'(no disponible)'})"
    AutoRoot-Log "    PARCHE SEG. : $(if($devPatch)  {$devPatch}  else {'(no disponible)'})"
    AutoRoot-Log "    CODENAME    : $(if($devCodename){$devCodename} else {'(no disponible)'})"
    AutoRoot-Log "    CSC         : $(if($devCsc)    {$devCsc}    else {'(no disponible)'})"
    AutoRoot-Log "    SERIAL      : $(if($devSerial) {$devSerial} else {'(no disponible)'})"
    AutoRoot-Log "    OEM LOCK    : $(if($oemLock -eq '1'){'LOCKED - Abrir BL primero!'} else {'UNLOCKED OK'})"
    AutoRoot-Log ""
    [System.Windows.Forms.Application]::DoEvents()

    # --- SELECCION AUTOMATICA DE VERSION DE MAGISK ---
    $magiskbootExe = Get-MagiskbootExe $devModel
    if (-not $magiskbootExe) {
        AutoRoot-Log "[!] No se pudo preparar magiskboot o los binarios de Magisk"
        AutoRoot-Log "[~] Verifica que tienes en .\tools\:"
        AutoRoot-Log "    magiskboot.exe   <- descarga de github.com/affggh/magiskboot_build/releases"
        AutoRoot-Log "    magisk27.apk     <- Magisk v27 (ya lo tienes)"
        AutoRoot-Log "    magisk24.apk     <- solo para modelos legacy (A21s/A13/A51 5G)"
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    AutoRoot-Log ""

    if ($oemLock -eq "1") {
        AutoRoot-Log "[!] ERROR: El bootloader esta BLOQUEADO."
        AutoRoot-Log "[!] No es posible flashear el boot parcheado."
        AutoRoot-Log "[~] Abre el bootloader primero desde: Ajustes > Info tel. > Num. compilacion (x7) > Dev options > OEM unlock"
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }

    # --- PASO 2: Seleccionar archivo AP firmware ---
    AutoRoot-Log "[2] Selecciona el archivo AP_*.tar.md5 del firmware Samsung..."
    AutoRoot-SetStatus $btn "SELECCIONAR AP..."
    [System.Windows.Forms.Application]::DoEvents()

    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Title  = "Selecciona el archivo AP del firmware Samsung (AP_*.tar.md5)"
    $fd.Filter = "Samsung AP Firmware|AP_*.tar.md5;AP_*.tar;AP_*.md5|Todos los tar|*.tar;*.md5;*.tar.md5|Todos|*.*"
    $fd.InitialDirectory = $script:SCRIPT_ROOT

    if ($fd.ShowDialog() -ne "OK") {
        AutoRoot-Log "[~] Cancelado por el usuario."
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    $apFile = $fd.FileName
    $apName = [System.IO.Path]::GetFileName($apFile)
    $apSizeMB = [math]::Round((Get-Item $apFile).Length / 1MB, 1)
    AutoRoot-Log "[+] AP seleccionado: $apName ($apSizeMB MB)"

    # Validar nombre del AP contra el modelo del telefono
    if ($apName -match "AP_([A-Z0-9]+)_") {
        $apBuildRaw    = $Matches[1]
        $devModelClean = $devModel -replace "[^A-Z0-9]",""
        # Extraer sufijo de firmware del build del dispositivo
        # Ej: "AP3A.240905.015.A2.G990EXXSIGYI3" -> "G990EXXSIGYI3"
        $devFwSuffix   = if ($devBuild -match "\.([A-Z0-9]{8,})$") { $Matches[1] } else { $devBuild -replace "[^A-Z0-9]","" }
        $match = $false
        if ($apBuildRaw -imatch [regex]::Escape($devModelClean))    { $match = $true }
        if ($apBuildRaw -eq $devFwSuffix)                           { $match = $true }
        if ($devFwSuffix -and $apBuildRaw -imatch [regex]::Escape($devFwSuffix)) { $match = $true }
        if ($match) {
            AutoRoot-Log "[+] VALIDACION: Firmware compatible con el dispositivo conectado"
            AutoRoot-Log "    AP build  : $apBuildRaw"
            AutoRoot-Log "    Dev build : $devBuild"
        } else {
            AutoRoot-Log "[!] ADVERTENCIA: El nombre del AP no coincide exactamente con el build del dispositivo"
            AutoRoot-Log "    AP build  : $apBuildRaw"
            AutoRoot-Log "    Dev build : $devBuild"
            AutoRoot-Log "[~] Puede ser de una version diferente."
            $cont = [System.Windows.Forms.MessageBox]::Show(
                "El firmware puede no coincidir exactamente con el dispositivo.`n`nAP:  $apBuildRaw`nDev: $devBuild`n`nContinuar de todas formas?",
                "Advertencia de compatibilidad",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($cont -ne "Yes") {
                AutoRoot-Log "[~] Cancelado."
                AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
                return
            }
        }
    }
    AutoRoot-Log ""

    # --- PASO 3: Escaneo rapido del TAR ---
    AutoRoot-Log "[3] Escaneando contenido del TAR..."
    AutoRoot-SetStatus $btn "ESCANEANDO TAR..."

    $scanResult = Find-BootInTar $apFile
    AutoRoot-Log "    init_boot encontrado : $($scanResult.InitBoot)"
    AutoRoot-Log "    boot encontrado      : $($scanResult.Boot)"

    if (-not $scanResult.Target) {
        AutoRoot-Log "[!] No se encontro boot.img.lz4 ni init_boot.img.lz4 en el AP"
        AutoRoot-Log "[!] Verifica que sea un firmware Samsung valido (AP_*.tar.md5)"
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }

    $targetFile  = $scanResult.Target
    $isInitBoot  = ($targetFile -imatch "init_boot")
    $partName    = if ($isInitBoot) { "INIT_BOOT" } else { "BOOT" }

    AutoRoot-Log "[+] Archivo objetivo: $targetFile"
    AutoRoot-Log "[+] Particion Samsung: $partName"
    if ($scanResult.InitBoot -and $scanResult.Boot) {
        AutoRoot-Log "[+] Encontrados boot e init_boot -> usando init_boot"
    } elseif ($isInitBoot) {
        AutoRoot-Log "[+] Solo init_boot encontrado -> usando init_boot"
    } else {
        AutoRoot-Log "[+] Solo boot encontrado -> usando boot.img"
    }
    AutoRoot-Log ""

    # --- PASO 4: Extraccion quirurgica ---
    AutoRoot-Log "[4] Extrayendo solo el archivo necesario del firmware..."
    AutoRoot-SetStatus $btn "EXTRAYENDO BOOT..."

    $stamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $workDir = [System.IO.Path]::Combine($script:SCRIPT_ROOT, "BACKUPS", "AUTOROOT", $stamp)
    New-Item $workDir -ItemType Directory -Force | Out-Null

    $extractedLz4 = Extract-SingleFromTar $apFile $targetFile $workDir
    if (-not $extractedLz4) {
        AutoRoot-Log "[!] Error extrayendo el boot del firmware."
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }

    # --- PASO 5: Descomprimir LZ4 ---
    AutoRoot-Log ""
    AutoRoot-Log "[5] Descomprimiendo LZ4..."
    AutoRoot-SetStatus $btn "DESCOMPRIMIENDO..."

    $imgBase = [System.IO.Path]::GetFileName($extractedLz4) -replace "\.lz4$",""
    $imgPath = [System.IO.Path]::Combine($workDir, $imgBase)
    $lz4ok   = Expand-LZ4 $extractedLz4 $imgPath

    if (-not $lz4ok) {
        AutoRoot-Log "[!] Error descomprimiendo LZ4."
        AutoRoot-Log "[~] Verifica que lz4.exe este en .\tools\"
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    $imgSz = [math]::Round((Get-Item $imgPath).Length/1MB,2)
    AutoRoot-Log "[+] Imagen descomprimida: $imgBase ($imgSz MB)"
    AutoRoot-Log ""

    # --- PASO 6: Parcheo via Magisk App en el dispositivo ---
    # magiskboot.exe en Windows no puede leer propiedades del sistema Android
    # (KEEPVERITY, PREINITDEVICE, estado AVB) -> parcheo incorrecto -> bootloop.
    # La solucion es usar Magisk App directamente en el dispositivo (ARM64 nativo)
    # que detecta y aplica correctamente todos los parametros del modelo especifico.
    # Funciona para cualquier modelo: G990E (Android 15), A125M (Android 11-12), etc.
    AutoRoot-Log "[6] Parcheando boot via Magisk App en el dispositivo..."
    AutoRoot-SetStatus $btn "PARCHEANDO..."

    # Instalar Magisk APK si no esta instalado
    $apkPath  = if ($magiskbootExe.IsLegacy) { $script:MAGISK_APK_24 } else { $script:MAGISK_APK_27 }
    $apkLabel = if ($magiskbootExe.IsLegacy) { "Magisk 24 (legacy)" } else { "Magisk 27" }
    $magiskPkg = (& adb shell "pm list packages com.topjohnwu.magisk" 2>$null) -join ""
    if ($magiskPkg -notmatch "com.topjohnwu.magisk") {
        AutoRoot-Log "[~] Instalando $apkLabel en el dispositivo..."
        $instOut = (& adb install -r "$apkPath" 2>&1) -join ""
        if ($instOut -imatch "Success") {
            AutoRoot-Log "[+] $apkLabel instalado OK"
            Start-Sleep -Seconds 2
        } else {
            AutoRoot-Log "[!] Error instalando Magisk: $instOut"
            AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
            return
        }
    } else {
        AutoRoot-Log "[+] Magisk App ya instalada"
    }

    # Limpiar parches previos para no confundir la busqueda
    & adb shell "rm -f /sdcard/magisk_patched*.img /sdcard/Download/magisk_patched*.img" 2>$null | Out-Null

    # Subir boot.img al dispositivo
    # adb push reporta velocidad en stderr, NO es un error - verificar con ls
    $remoteBootPath = "/sdcard/rnx_boot_toparchear.img"
    $imgSzMB = [math]::Round((Get-Item $imgPath).Length/1MB,1)
    AutoRoot-Log "[~] Subiendo boot.img al dispositivo ($imgSzMB MB)..."
    $pushRaw = (& adb push "$imgPath" $remoteBootPath 2>&1)
    $pushRaw | ForEach-Object { $l = "$_".Trim(); if ($l) { AutoRoot-Log "    [push] $l" } }
    $remoteCheck = (& adb shell "ls $remoteBootPath 2>/dev/null" 2>$null) -join ""
    if (-not $remoteCheck -or $remoteCheck -notmatch "rnx_boot_toparchear") {
        AutoRoot-Log "[!] El archivo no llego al dispositivo - verifica la conexion ADB"
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    AutoRoot-Log "[+] boot.img subido OK: $remoteBootPath"

    # Abrir Magisk App en el dispositivo
    AutoRoot-Log "[~] Abriendo Magisk App..."
    & adb shell "am start -n com.topjohnwu.magisk/.ui.MainActivity" 2>$null | Out-Null
    Start-Sleep -Seconds 2
    [System.Windows.Forms.Application]::DoEvents()

    # Instrucciones en el log (siempre visibles)
    AutoRoot-Log ""
    AutoRoot-Log "================================================"
    AutoRoot-Log "  PASOS EN EL TELEFONO:"
    AutoRoot-Log "  1. Toca [ Instalar ] en la seccion Magisk"
    AutoRoot-Log "  2. Toca [ Seleccionar y parchear un archivo ]"
    AutoRoot-Log "  3. Navega a Almacenamiento interno"
    AutoRoot-Log "  4. Selecciona: rnx_boot_toparchear.img"
    AutoRoot-Log "  5. Toca [ EMPECEMOS ] y espera 'Listo!'"
    AutoRoot-Log "================================================"
    AutoRoot-Log ""

    # Dialogo bloqueante - el usuario confirma cuando Magisk termino
    $instrMsg = "Magisk App esta abierta en el telefono.`n`n" +
        "PASOS EN EL TELEFONO:`n" +
        "  1. Toca [ Instalar ] en la seccion Magisk`n" +
        "  2. Toca [ Seleccionar y parchear un archivo ]`n" +
        "  3. Navega a Almacenamiento interno`n" +
        "  4. Selecciona: rnx_boot_toparchear.img`n" +
        "  5. Toca [ EMPECEMOS ] y espera 'Listo!'`n`n" +
        "Presiona OK SOLO CUANDO Magisk muestre 'Listo!' / '!Listo!'"
    [System.Windows.Forms.MessageBox]::Show(
        $instrMsg, "PASO 6 - Parchear con Magisk App",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

    # Buscar el archivo parcheado - Magisk lo guarda en /sdcard/Download/ (Android 13+)
    # o en /sdcard/ (Android 11-12). Buscar en ambas rutas.
    function Find-MagiskPatched {
        $candidates = @(
            "/sdcard/Download/magisk_patched*.img",
            "/sdcard/magisk_patched*.img",
            "/storage/emulated/0/Download/magisk_patched*.img",
            "/storage/emulated/0/magisk_patched*.img"
        )
        foreach ($pattern in $candidates) {
            $result = (& adb shell "ls $pattern 2>/dev/null" 2>$null) |
                Where-Object { "$_" -imatch "magisk_patched" } | Select-Object -First 1
            if ($result) { return "$result".Trim() }
        }
        # Fallback: find recursivo en ruta real del almacenamiento
        $result2 = (& adb shell "find /storage/emulated/0 -name 'magisk_patched*.img' 2>/dev/null" 2>$null) |
            Where-Object { "$_" -imatch "magisk_patched" } | Select-Object -First 1
        if ($result2) { return "$result2".Trim() }
        return $null
    }

    AutoRoot-Log "[~] Buscando boot parcheado en el dispositivo..."
    AutoRoot-Log "    (busca en /sdcard/Download/ y /sdcard/)"
    AutoRoot-SetStatus $btn "DESCARGANDO BOOT..."
    $patchedRemote = $null

    # 5 intentos automaticos con 3 segundos entre cada uno
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $patchedRemote = Find-MagiskPatched
        if ($patchedRemote) { break }
        AutoRoot-Log "[~] No encontrado, reintentando ($($attempt+1)/5)..."
        Start-Sleep -Seconds 3
        [System.Windows.Forms.Application]::DoEvents()
    }

    # Si no se encontro, dar opcion de reintentar indefinidamente
    while (-not $patchedRemote) {
        $retryRes = [System.Windows.Forms.MessageBox]::Show(
            "No se encontro el archivo parcheado.`n`n" +
            "Magisk lo guarda en:/sdcard/Download/magisk_patched-XXXXX.img`n`n" +
            "- OK: buscar de nuevo`n- Cancelar: abortar",
            "Archivo no encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($retryRes -ne "OK") { break }
        AutoRoot-Log "[~] Buscando de nuevo..."
        for ($r = 0; $r -lt 3; $r++) {
            $patchedRemote = Find-MagiskPatched
            if ($patchedRemote) { break }
            Start-Sleep -Seconds 3
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    if (-not $patchedRemote) {
        AutoRoot-Log "[!] Boot parcheado no encontrado"
        AutoRoot-Log "[~] Verifica: adb shell find /sdcard -name 'magisk_patched*'"
        & adb shell "rm -f $remoteBootPath" 2>$null | Out-Null
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    AutoRoot-Log "[+] Encontrado: $patchedRemote"

    # Descargar el boot parcheado al PC
    # Nombrar el archivo segun el tipo real: init_boot o boot
    $patchedImgName = if ($isInitBoot) { "magisk_patched_init_boot.img" } else { "magisk_patched_boot.img" }
    $patchedImg = [System.IO.Path]::Combine($workDir, $patchedImgName)
    AutoRoot-Log "[~] Descargando boot parcheado al PC..."
    & adb pull $patchedRemote $patchedImg 2>&1 | Out-Null
    if (-not (Test-Path $patchedImg)) {
        AutoRoot-Log "[!] Error descargando el boot parcheado"
        & adb shell "rm -f $remoteBootPath $patchedRemote" 2>$null | Out-Null
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    $pSz = [math]::Round((Get-Item $patchedImg).Length/1MB,2)
    AutoRoot-Log "[+] Boot parcheado listo: $pSz MB"
    & adb shell "rm -f $remoteBootPath $patchedRemote" 2>$null | Out-Null
    AutoRoot-Log "[+] Archivos temporales eliminados del dispositivo"
    AutoRoot-Log ""

    # --- PASO 7: Crear .tar y .tar.md5 para flash ---
    AutoRoot-Log "[7] Preparando archivos para flash..."
    AutoRoot-SetStatus $btn "PREPARANDO TAR..."

    $flashDir  = [System.IO.Path]::Combine($workDir, "flash")
    New-Item $flashDir -ItemType Directory -Force | Out-Null
    $tarResult = Build-OdinTar $patchedImg $flashDir $isInitBoot

    if (-not $tarResult) {
        AutoRoot-Log "[!] Error creando el archivo TAR."
        AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
        return
    }
    AutoRoot-Log ""

    # --- PASO 8: Flash ---
    AutoRoot-Log "[8] Iniciando flash del boot parcheado..."
    AutoRoot-Log "[!] IMPORTANTE: El equipo debe estar en DOWNLOAD MODE"
    AutoRoot-Log "[~] Reiniciando a Download Mode via ADB..."
    & adb reboot download 2>$null
    AutoRoot-Log "[~] Esperando que entre en Download Mode (15s)..."
    Start-Sleep -Seconds 4
    [System.Windows.Forms.Application]::DoEvents()

    # Intentar con Heimdall primero (CLI, automatico)
    $heimdallAvail = $false
    foreach ($c in @((Join-Path $script:TOOLS_DIR "heimdall.exe"),".\heimdall.exe","heimdall")) {
        if ((Test-Path $c) -or (Get-Command $c -ErrorAction SilentlyContinue)) {
            $heimdallAvail = $true; break
        }
    }

    if ($heimdallAvail) {
        AutoRoot-Log "[~] Usando Heimdall (automatico)..."
        AutoRoot-SetStatus $btn "FLASHEANDO..."

        # Esperar Download Mode - timeout reducido a 16s para saltar al fallback Odin mas rapido
        AutoRoot-Log "[~] Esperando entrada a Download Mode (hasta 16s)..."
        $devDetected = $false
        for ($w = 0; $w -lt 8; $w++) {
            Start-Sleep -Seconds 2
            [System.Windows.Forms.Application]::DoEvents()
            $det = Invoke-HeimdallAdv "detect" 2>$null
            if ($det -imatch "Device detected") {
                AutoRoot-Log "[+] Dispositivo detectado en Download Mode ($($w*2)s)"
                $devDetected = $true; break
            }
            if ($w % 2 -eq 0) { AutoRoot-Log "[~] Esperando Download Mode... ($($w*2)s)" }
        }
        if (-not $devDetected) {
            AutoRoot-Log "[!] Heimdall no detecto el dispositivo en 16s - saltando a Odin..."
            Open-OdinWithBoot $tarResult.TarMd5
            AutoRoot-Log "[~] Si el equipo ya esta en Download Mode, el flash manual funciona"
        }
        if ($devDetected) {

        # Heimdall mapea: BOOT para boot.img, INIT_BOOT para init_boot.img
        # En SM-G990E la particion fisica se llama BOOT aunque el archivo sea init_boot
        $heimPartFlag = $partName
        AutoRoot-Log "[~] Particion Heimdall: --$heimPartFlag"
        AutoRoot-Log "[~] Imagen a flashear : $([System.IO.Path]::GetFileName($patchedImg))"
        $flashOk = Flash-WithHeimdall $patchedImg $heimPartFlag

        if ($flashOk) {
            AutoRoot-Log ""
            AutoRoot-Log "[OK] FLASH COMPLETADO via Heimdall"
            AutoRoot-Log "[~] Reiniciando sistema..."
            Invoke-Heimdall "flash --REBOOT" | Out-Null
            Start-Sleep -Seconds 2
            $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  AUTOROOT OK  |  Reiniciando..."
            # Verificar root post-flash
            AutoRoot-SetStatus $btn "VERIFICANDO..."
            Verify-RootPost
        } else {
            AutoRoot-Log "[!] Heimdall fallo - abriendo Odin como alternativa..."
            Open-OdinWithBoot $tarResult.TarMd5
        }
        } # fin $devDetected
    } else {
        AutoRoot-Log "[~] Heimdall no disponible - usando Odin (modo semi-manual)..."
        Open-OdinWithBoot $tarResult.TarMd5
    }

    # --- Resumen final ---
    AutoRoot-Log ""
    AutoRoot-Log "=============================================="
    AutoRoot-Log "  RESUMEN AUTOROOT"
    AutoRoot-Log "=============================================="
    AutoRoot-Log "  Dispositivo : $devModel"
    AutoRoot-Log "  Build       : $devBuild"
    AutoRoot-Log "  Particion   : $partName"
    AutoRoot-Log "  Magiskboot  : $([System.IO.Path]::GetFileName($magiskbootExe.Exe))"
    AutoRoot-Log "  Boot img    : $([System.IO.Path]::GetFileName($patchedImg))"
    AutoRoot-Log "  TAR Odin    : $([System.IO.Path]::GetFileName($tarResult.TarMd5))"
    AutoRoot-Log "  Carpeta     : $workDir"
    AutoRoot-Log "=============================================="
    AutoRoot-Log ""
    AutoRoot-Log "[~] Si el equipo queda en RECOVERY MODE:"
    AutoRoot-Log "    Entra a: Wipe > Factory Reset > Yes"
    AutoRoot-Log "    Luego:   Reboot System"
    AutoRoot-Log ""
    AutoRoot-Log "[~] Archivos generados en:"
    AutoRoot-Log "    $workDir"
    # Abrir carpeta de trabajo automaticamente
    Start-Process explorer.exe $workDir -ErrorAction SilentlyContinue

    AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
    $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  AUTOROOT completado  |  Ver log"
})

#==========================================================================
# BYPASS BANCARIO  -  Sistema completo de ocultacion de root
# Shamiko + LSPosed + Zygisk-Next + DenyList
# ARCHIVOS en .\tools\modules\ : Paso_1.zip Paso_2.zip Paso_3.zip Magisk-Delta-V27.zip
# ARCHIVOS en .\tools\          : magisk27.apk  magisk24.apk  magisk_delta.apk
#==========================================================================

function Bypass-Log($msg) { AdbLog $msg }
function Bypass-SetStatus($btn,$txt) {
    $btn.Text=$txt; $btn.Enabled=($txt -eq "BYPASS BANCARIO")
    [System.Windows.Forms.Application]::DoEvents()
}
function AdbRoot($cmd) {
    $r=(& adb shell "su -c '$cmd'" 2>$null)
    if ($r -is [array]) { return ($r -join "`n").Trim() }
    return "$r".Trim()
}
function Set-MagiskSetting($key, $value) {
    # Crea un script sh en el dispositivo que ejecuta el SQL sin problemas de comillas
    $script = "magisk --sqlite `'INSERT OR REPLACE INTO settings (key,value) VALUES(`"$key`",$value)`'"
    $tmpFile = [System.IO.Path]::GetTempFileName() + ".sh"
    $script | Set-Content -Path $tmpFile -Encoding ASCII -NoNewline
    & adb push "$tmpFile" "/data/local/tmp/rnx_set.sh" 2>$null | Out-Null
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    $r = (& adb shell "su -c 'sh /data/local/tmp/rnx_set.sh'" 2>$null)
    if ($r -is [array]) { $r = ($r -join "").Trim() } else { $r = "$r".Trim() }
    return $r
}
function Get-MagiskSetting($key) {
    $script = "magisk --sqlite `'SELECT value FROM settings WHERE key=`"$key`"`'"
    $tmpFile = [System.IO.Path]::GetTempFileName() + ".sh"
    $script | Set-Content -Path $tmpFile -Encoding ASCII -NoNewline
    & adb push "$tmpFile" "/data/local/tmp/rnx_get.sh" 2>$null | Out-Null
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    $r = (& adb shell "su -c 'sh /data/local/tmp/rnx_get.sh'" 2>$null)
    if ($r -is [array]) { $r = ($r -join "").Trim() } else { $r = "$r".Trim() }
    # Output de magisk --sqlite tiene formato "value=X"
    if ($r -match "value=(.+)") { return $Matches[1].Trim() }
    if ($r) { return $r } else { return "?" }
}
function Wait-AdbReconnect($timeoutSec) {
    Bypass-Log "[~] Esperando reconexion ADB (max $timeoutSec s)..."
    $elapsed=0
    while ($elapsed -lt $timeoutSec) {
        Start-Sleep -Seconds 3; $elapsed+=3
        [System.Windows.Forms.Application]::DoEvents()
        $devs=(& adb devices 2>$null) -join ""
        if ($devs -match "`tdevice") {
            Bypass-Log "[+] ADB reconectado ($elapsed s)"
            Start-Sleep -Seconds 4; [System.Windows.Forms.Application]::DoEvents()
            return $true
        }
        if ($elapsed % 15 -eq 0) { Bypass-Log "[~] Esperando... ($elapsed s)" }
    }
    Bypass-Log "[!] Timeout ($timeoutSec s)"; return $false
}
function Get-MagiskInfo {
    # magisk -c devuelve algo como "27000" o "27000:MAGISK:R"
    $ver = ""
    $verRaw = ((& adb shell "magisk -c" 2>$null) -join "").Trim()
    if ($verRaw -match "^(\d+)") { $ver = $Matches[1] }   # solo los digitos iniciales
    if (-not $ver) {
        $ver = ((& adb shell "getprop ro.magisk.version" 2>$null) -join "").Trim()
        if ($ver -match "^(\d+)") { $ver = $Matches[1] }
    }
    $vn = 0
    $verDisplay = $ver
    if ($ver -match "^(\d+)") {
        $vn = [int]$Matches[1]
        if ($vn -gt 1000) { $verDisplay = [string][int]([math]::Floor($vn / 1000)); $vn = [int]$verDisplay }
    }
    $isDelta = $false
    $dc = ((& adb shell "magisk -c 2>/dev/null" 2>$null) -join "")
    if ($dc -imatch "kitsune|delta") { $isDelta = $true }

    # Verifica APK instalado (binario puede existir sin APK)
    $apkInstalled = $false
    $pkgCheck = (& adb shell "pm list packages com.topjohnwu.magisk" 2>$null) -join ""
    if ($pkgCheck -imatch "com.topjohnwu.magisk") { $apkInstalled = $true }
    if (-not $apkInstalled) {
        $pkgDelta = (& adb shell "pm list packages io.github.huskydg.magisk" 2>$null) -join ""
        if ($pkgDelta -imatch "io.github.huskydg.magisk") { $apkInstalled = $true; $isDelta = $true }
    }

    return @{ Version=$verDisplay; VerNum=$vn; IsDelta=$isDelta; BinaryInstalled=($vn -gt 0); ApkInstalled=$apkInstalled; Installed=($vn -gt 0 -and $apkInstalled) }
}
function Install-Apk($apkPath,$label) {
    if (-not (Test-Path $apkPath)) { Bypass-Log "[!] APK no encontrado: $apkPath"; return $false }
    Bypass-Log "[~] Instalando $label..."
    $r=(& adb install -r "$apkPath" 2>&1) -join ""
    if ($r -imatch "Success") { Bypass-Log "[+] $label OK"; return $true }
    Bypass-Log "[!] Error: $r"; return $false
}
function Uninstall-Pkg($pkg,$label) {
    Bypass-Log "[~] Desinstalando $label..."
    $r=(& adb shell "pm uninstall $pkg" 2>$null) -join ""
    if ($r -imatch "Success") { Bypass-Log "[+] $label desinstalado"; return $true }
    Bypass-Log "[!] Error: $r"; return $false
}
function Install-MagiskModule($zipPath,$moduleName) {
    if (-not (Test-Path $zipPath)) { Bypass-Log "[!] No encontrado: $zipPath"; return $false }
    $rem="/sdcard/rnx_modules/$([System.IO.Path]::GetFileName($zipPath))"
    Bypass-Log "[~] Subiendo $moduleName..."
    & adb shell "mkdir -p /sdcard/rnx_modules" 2>$null | Out-Null
    # adb push reporta velocidad en stderr - NO es un error
    # Verificar exito comprobando que el archivo existe en el dispositivo
    & adb push "$zipPath" "$rem" 2>&1 | ForEach-Object { if ("$_" -match "KB/s|MB/s|bytes") { Bypass-Log "    [push] $_" } }
    $pushCheck = (& adb shell "ls $rem 2>/dev/null" 2>$null) -join ""
    if (-not $pushCheck -or $pushCheck -notmatch [regex]::Escape([System.IO.Path]::GetFileName($rem))) {
        Bypass-Log "[!] Push fallido - archivo no llego al dispositivo"
        return $false
    }
    Bypass-Log "[+] Subido OK"
    Bypass-Log "[~] Instalando modulo $moduleName..."
    $inst=AdbRoot "magisk --install-module $rem"
    AdbRoot "rm -f $rem" | Out-Null
    if ($inst -imatch "Done|Success|installed") { Bypass-Log "[+] $moduleName instalado"; return $true }
    # Verificar directamente en /data/adb/modules
    $idMap=@{shamiko="zygisk_shamiko";lsposed="zygisk_lsposed";zygisk="zygisksu";delta="magisk_delta"}
    $modId=""
    foreach ($k in $idMap.Keys) { if ($moduleName -imatch $k) { $modId=$idMap[$k]; break } }
    if ($modId) {
        $chk=AdbRoot "ls /data/adb/modules/$modId 2>/dev/null"
        if ($chk) { Bypass-Log "[+] $moduleName verificado en modules/$modId"; return $true }
    }
    Bypass-Log "[~] Respuesta: $inst"; Bypass-Log "[+] Asumiendo OK (confirmar al reiniciar)"
    return $true
}
function Configure-MagiskDenyList {
    # Solo busca apps bancarias y las agrega a DenyList
    # Zygisk y DenyList ya activados por el flujo principal antes de llamar esta funcion
    $bankKw=@("yape","bcp","bbva","interbank","scotiabank","bim","ripley","falabella","bcpbankapp","mibanco","intercorp","scotiam")
    Bypass-Log "[~] Buscando apps bancarias instaladas..."
    $allPkgs=(& adb shell "pm list packages" 2>$null) -join "`n"
    $allPkgs=$allPkgs -replace "package:",""
    $found=@()
    foreach ($kw in $bankKw) {
        $ms=($allPkgs -split "`n" | Where-Object { $_ -imatch $kw -and $_.Trim() -ne "" })
        foreach ($p in $ms) { $p=$p.Trim(); if ($p -and $found -notcontains $p) { $found+=$p } }
    }
    if ($found.Count -eq 0) {
        Bypass-Log "[!] No se encontraron apps bancarias - agregar manualmente en Magisk > DenyList"
    } else {
        Bypass-Log "[+] Apps encontradas: $($found.Count)"
        foreach ($pkg in $found) {
            Bypass-Log "    -> $pkg"
            AdbRoot "magisk --denylist add $pkg" | Out-Null
            AdbRoot "magisk --denylist add $pkg $pkg" | Out-Null
            Bypass-Log "    [OK] $pkg -> DenyList"
        }
    }
    $dlRaw = AdbRoot "magisk --denylist ls 2>/dev/null"
    $dc = ($dlRaw -split "[`n`r]+" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { ($_ -split "/")[0].Trim() } | Select-Object -Unique).Count
    Bypass-Log "[+] DenyList configurada: $dc entradas"
    return $found
}

$btnsA2[1].Add_Click({
    $btn=$btnsA2[1]
    $Global:logAdb.Clear()
    Bypass-Log "=============================================="
    Bypass-Log "   BYPASS BANCARIO  -  RNX TOOL PRO"
    Bypass-Log "   Shamiko + LSPosed + Zygisk-Next"
    Bypass-Log "=============================================="
    Bypass-Log ""
    Bypass-Log "[*] TARGET: Yape, BCP, BBVA, Interbank, Scotiabank, BIM, Ripley, Falabella"
    Bypass-Log ""
    $toolsDir   = $script:TOOLS_DIR
    $modulesDir = $script:MODULES_DIR
    $zipPaso1=Join-Path $modulesDir "Paso_1.zip"
    $zipPaso2=Join-Path $modulesDir "Paso_2.zip"
    $zipPaso3=Join-Path $modulesDir "Paso_3.zip"
    $zipDelta=Join-Path $modulesDir "Magisk-Delta-V27.zip"
    $apkM27=Join-Path $toolsDir "magisk27.apk"
    $apkM24=Join-Path $toolsDir "magisk24.apk"
    $apkDelta=Join-Path $toolsDir "magisk_delta.apk"

    Bypass-Log "[1] Verificando ADB..."
    Bypass-SetStatus $btn "VERIFICANDO..."
    $adbCheck = $false
    try { $adbCheck = ((& adb devices 2>$null) -join "" -match "`tdevice") } catch {}
    if (-not $adbCheck) {
        Bypass-Log "[!] Sin equipo ADB conectado."
        Bypass-Log "[~] Conecta el equipo con USB Debugging activo."
        Bypass-Log "[~] NOTA: Requiere AUTOROOT MAGISK previo."
        Bypass-Log ""
        Bypass-Log "[~] Si ves error de virus/antivirus en el log:"
        Bypass-Log "    Windows Defender bloquea adb.exe (falso positivo)."
        Bypass-Log "    Solucion: Win Security > Historial > Permitir adb.exe"
        Bypass-Log "    O: Win Security > Exclusiones > Agregar carpeta C:\RNX_TOOL\"
        Bypass-SetStatus $btn "BYPASS BANCARIO"; return
    }
    $devModelRaw = $null
    try { $devModelRaw = (& adb shell getprop ro.product.model 2>$null) } catch {}
    $devModel = if ($devModelRaw -and $devModelRaw -isnot [System.Management.Automation.ErrorRecord]) {
        if ($devModelRaw -is [array]) { ($devModelRaw -join "").Trim() } else { "$devModelRaw".Trim() }
    } else { "" }
    $isLegacy = $false
    if ($devModel -ne "") {
        foreach ($leg in $script:MAGISK_LEGACY_MODELS) {
            if ($devModel.ToUpper() -eq $leg.ToUpper()) { $isLegacy = $true; break }
        }
    }
    $modelDisp = if ($devModel) { $devModel } else { "(no detectado)" }
    Bypass-Log "[+] Modelo: $modelDisp $(if($isLegacy){'[LEGACY]'} else {'[ESTANDAR]'})"
    Bypass-Log ""

    Bypass-Log "[2] Verificando root..."
    Bypass-SetStatus $btn "CHEQUEANDO ROOT..."
    if ((AdbRoot "id") -notmatch "uid=0") {
        Bypass-Log "[!] Sin root. Ejecuta AUTOROOT MAGISK primero."
        Bypass-SetStatus $btn "BYPASS BANCARIO"; return
    }
    Bypass-Log "[+] Root OK"
    Bypass-Log ""

    Bypass-Log "[3] Detectando Magisk..."
    Bypass-SetStatus $btn "DETECTANDO MAGISK..."
    $mInfo=Get-MagiskInfo
    Bypass-Log "[~] Binario: $(if($mInfo.BinaryInstalled){'OK v'+$mInfo.Version} else {'NO ENCONTRADO'})  |  APK: $(if($mInfo.ApkInstalled){'INSTALADO'} else {'NO INSTALADO'})"

    # Si el binario no esta -> instalar APK completo
    if (-not $mInfo.BinaryInstalled) {
        Bypass-Log "[!] Magisk no detectado - instalando APK..."
        if ($isLegacy) { Install-Apk $apkM24 "Magisk 24.1" | Out-Null }
        else { Install-Apk $apkM27 "Magisk 27" | Out-Null }
        Start-Sleep -Seconds 3; $mInfo=Get-MagiskInfo
    } else {
        # Binario OK -> siempre reinstalar APK para asegurar que este fresco y funcional
        Bypass-Log "[~] Reinstalando APK de Magisk (forzado)..."
        Bypass-SetStatus $btn "INSTALANDO MAGISK APK..."
        if ($isLegacy) { Install-Apk $apkM24 "Magisk 24.1" | Out-Null }
        else { Install-Apk $apkM27 "Magisk 27" | Out-Null }
        Start-Sleep -Seconds 2; $mInfo=Get-MagiskInfo
    }

    Bypass-Log "[+] Magisk v$($mInfo.Version) | APK: $(if($mInfo.ApkInstalled){'OK'} else {'FALLO - instalar manualmente'}) | Delta: $($mInfo.IsDelta)"
    Bypass-Log ""

    # RAMA LEGACY: Magisk 24 -> migrar a Delta
    if ($isLegacy -and $mInfo.VerNum -lt 25 -and -not $mInfo.IsDelta) {
        Bypass-Log "================================================"
        Bypass-Log "  RUTA LEGACY: Migrando Magisk 24 -> Delta v27"
        Bypass-Log "================================================"
        $missing=@()
        if (-not (Test-Path $zipDelta))  { $missing+="tools\modules\Magisk-Delta-V27.zip" }
        if (-not (Test-Path $apkDelta))  { $missing+="tools\magisk_delta.apk" }
        if ($missing.Count -gt 0) {
            foreach ($m in $missing) { Bypass-Log "[!] Falta: $m" }
            Bypass-SetStatus $btn "BYPASS BANCARIO"; return
        }
        Bypass-Log "[A1] Instalando Delta como modulo de Magisk 24..."
        Bypass-SetStatus $btn "DELTA MODULO..."
        if (-not (Install-MagiskModule $zipDelta "Magisk-Delta-V27")) {
            Bypass-Log "[!] Fallo instalacion modulo Delta"
            Bypass-SetStatus $btn "BYPASS BANCARIO"; return
        }
        Bypass-Log ""
        Bypass-Log "[A2] Instalando Magisk Delta APK..."
        Bypass-SetStatus $btn "DELTA APK..."
        Install-Apk $apkDelta "Magisk Delta v27" | Out-Null
        Bypass-Log ""
        Bypass-Log "[A3] Desinstalando Magisk 24 original..."
        Bypass-SetStatus $btn "DESINSTALANDO..."
        Uninstall-Pkg "com.topjohnwu.magisk" "Magisk 24" | Out-Null
        Bypass-Log ""
        Bypass-Log "[A4] Reiniciando para activar Delta..."
        Bypass-SetStatus $btn "REINICIANDO..."
        & adb reboot 2>$null; Start-Sleep -Seconds 8
        [System.Windows.Forms.Application]::DoEvents()
        if (-not (Wait-AdbReconnect 180)) {
            Bypass-Log "[!] Reconexion fallida. Reconecta manualmente y reintenta."
            Bypass-SetStatus $btn "BYPASS BANCARIO"; return
        }
        $mInfo=Get-MagiskInfo
        Bypass-Log "[+] Post-reboot: v$($mInfo.Version) | Delta: $($mInfo.IsDelta)"
        if (-not $mInfo.IsDelta -and $mInfo.VerNum -lt 25) {
            Bypass-Log "[!] Delta no activo. Espera y reintenta."
            Bypass-SetStatus $btn "BYPASS BANCARIO"; return
        }
        Bypass-Log "[OK] Migracion a Delta completada"
        Bypass-Log ""
    }

    # RAMA PRINCIPAL: flujo identico al proceso manual verificado en imagenes
    # 1. Instalar 3 modulos
    # 2. Activar Zygisk + DenyList via broadcast (mismo mecanismo que la UI de Magisk)
    # 3. Agregar apps a DenyList
    # 4. Desactivar Zygisk (DenyList queda activa aunque aparezca gris)
    # 5. Reiniciar
    Bypass-Log "================================================"
    Bypass-Log "  BYPASS BANCARIO - MODO SEMI-MANUAL"
    Bypass-Log "================================================"
    Bypass-Log ""

    # Verificar que los zips existen
    $modOk = $true
    foreach ($pair in @(@($zipPaso1,"Paso_1.zip (Shamiko)"),@($zipPaso2,"Paso_2.zip (LSPosed)"),@($zipPaso3,"Paso_3.zip (Zygisk Next)"))) {
        if (-not (Test-Path $pair[0])) { Bypass-Log "[!] Falta: $($pair[1]) en tools\modules\"; $modOk = $false }
    }
    if (-not $modOk) { Bypass-SetStatus $btn "BYPASS BANCARIO"; return }

    # -------------------------------------------------------
    # PASO 1: Subir los 3 zips al dispositivo
    # -------------------------------------------------------
    Bypass-Log "[1] Subiendo modulos al dispositivo..."
    & adb shell "mkdir -p /sdcard/rnx_modules" 2>$null | Out-Null
    Bypass-SetStatus $btn "SUBIENDO ZIPS..."

    foreach ($pair in @(@($zipPaso1,"Paso_1.zip"),@($zipPaso2,"Paso_2.zip"),@($zipPaso3,"Paso_3.zip"))) {
        $zipPath = $pair[0]; $zipName = $pair[1]
        Bypass-Log "[~] Subiendo $zipName..."
        & adb push "$zipPath" "/sdcard/rnx_modules/$zipName" 2>&1 | ForEach-Object {
            if ("$_" -match "KB/s|MB/s|bytes") { Bypass-Log "    $_" }
        }
        $chk = (& adb shell "[ -f /sdcard/rnx_modules/$zipName ] && echo OK || echo FAIL" 2>$null) -join ""
        if ($chk -imatch "OK") { Bypass-Log "[+] $zipName subido OK" }
        else { Bypass-Log "[!] Error subiendo $zipName"; Bypass-SetStatus $btn "BYPASS BANCARIO"; return }
    }
    Bypass-Log ""
    Bypass-Log "[+] Los 3 modulos estan en: /sdcard/rnx_modules/"
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 2: Abrir Magisk en pestana Modulos + mostrar instrucciones
    # -------------------------------------------------------
    Bypass-Log "[~] Abriendo Magisk en el celular (pestana Modulos)..."
    # Abre Magisk y navega a la pestana Modulos (tab index 1 = Modules en Magisk 24+)
    & adb shell "am start -n com.topjohnwu.magisk/.ui.MainActivity" 2>$null | Out-Null
    Start-Sleep -Milliseconds 1000
    # Simula tap en el icono de Modulos (segundo icono de la barra inferior)
    # Primero obtiene resolucion de pantalla para calcular coordenadas
    $screenSize = (& adb shell "wm size" 2>$null) -join ""
    $tapX = 540; $tapY = 900   # coordenadas por defecto para 1080p
    if ($screenSize -match "(\d+)x(\d+)") {
        $sw = [int]$Matches[1]; $sh = [int]$Matches[2]
        # El icono Modulos es el 2do de 4 en la barra inferior, a ~37.5% del ancho, ~96% del alto
        $tapX = [int]($sw * 0.375)
        $tapY = [int]($sh * 0.962)
    }
    & adb shell "input tap $tapX $tapY" 2>$null | Out-Null
    Start-Sleep -Milliseconds 600
    [System.Windows.Forms.Application]::DoEvents()
    Bypass-Log "[+] Magisk abierto - ve a la pestana MODULOS si no se abrio sola"
    Bypass-Log ""

    # Armar instrucciones con saltos CRLF que Windows Forms requiere
    $nl = "`r`n"
    $instrucciones  = "-------------------------------------------------------$nl"
    $instrucciones += "  MODULOS LISTOS EN: /sdcard/rnx_modules/$nl"
    $instrucciones += "  (Magisk ya se abrio en el celular)$nl"
    $instrucciones += "-------------------------------------------------------$nl"
    $instrucciones += "$nl"
    $instrucciones += "  Sigue estos pasos en el celular:$nl"
    $instrucciones += "$nl"
    $instrucciones += "  [1]  En Magisk toca la pestana MODULOS (icono puzzle)$nl"
    $instrucciones += "$nl"
    $instrucciones += "  [2]  Toca >> Instalar desde almacenamiento$nl"
    $instrucciones += "$nl"
    $instrucciones += "  [3]  Navega a: /sdcard/rnx_modules/$nl"
    $instrucciones += "$nl"
    $instrucciones += "  [4]  Instala los zips EN ESTE ORDEN:$nl"
    $instrucciones += "         - Paso_1.zip  (Shamiko)$nl"
    $instrucciones += "         - Paso_2.zip  (LSPosed)$nl"
    $instrucciones += "         - Paso_3.zip  (Zygisk Next)$nl"
    $instrucciones += "$nl"
    $instrucciones += "  [5]  Instala los 3 SIN reiniciar entre cada uno.$nl"
    $instrucciones += "       Si Magisk pide reinicio, toca 'Mas tarde'$nl"
    $instrucciones += "       hasta tener los 3 instalados.$nl"
    $instrucciones += "$nl"
    $instrucciones += "  [6]  Con los 3 listos, vuelve aqui y presiona$nl"
    $instrucciones += "       el boton verde de abajo.$nl"
    $instrucciones += "$nl"
    $instrucciones += "-------------------------------------------------------$nl"
    $instrucciones += "  IMPORTANTE: Zygisk debe estar ACTIVADO en Magisk$nl"
    $instrucciones += "              durante todo el proceso de instalacion$nl"
    $instrucciones += "-------------------------------------------------------$nl"

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "RNX TOOL PRO - Flashear Modulos en Magisk"
    $dlg.ClientSize = New-Object System.Drawing.Size(560, 460)
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(18,18,18)
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.StartPosition = "CenterScreen"
    $dlg.TopMost = $true

    $lbTitulo = New-Object Windows.Forms.Label
    $lbTitulo.Text = "FLASHEAR MODULOS MANUALMENTE EN MAGISK"
    $lbTitulo.Location = New-Object System.Drawing.Point(14,12)
    $lbTitulo.Size = New-Object System.Drawing.Size(532,20)
    $lbTitulo.ForeColor = [System.Drawing.Color]::Lime
    $lbTitulo.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $dlg.Controls.Add($lbTitulo)

    $txtInstr = New-Object Windows.Forms.TextBox
    $txtInstr.Multiline = $true
    $txtInstr.ReadOnly = $true
    $txtInstr.Text = $instrucciones
    $txtInstr.Location = New-Object System.Drawing.Point(14,38)
    $txtInstr.Size = New-Object System.Drawing.Size(532,370)
    $txtInstr.BackColor = [System.Drawing.Color]::FromArgb(25,25,25)
    $txtInstr.ForeColor = [System.Drawing.Color]::White
    $txtInstr.Font = New-Object System.Drawing.Font("Consolas",9)
    $txtInstr.ScrollBars = "Vertical"
    $dlg.Controls.Add($txtInstr)

    $btnOK = New-Object Windows.Forms.Button
    $btnOK.Text = "YA FLASHEE LOS 3 MODULOS - CONTINUAR"
    $btnOK.Location = New-Object System.Drawing.Point(14,416)
    $btnOK.Size = New-Object System.Drawing.Size(340,36)
    $btnOK.FlatStyle = "Flat"
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(0,120,0)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $btnOK.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.Controls.Add($btnOK)

    $btnCancel = New-Object Windows.Forms.Button
    $btnCancel.Text = "CANCELAR"
    $btnCancel.Location = New-Object System.Drawing.Point(366,416)
    $btnCancel.Size = New-Object System.Drawing.Size(180,36)
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(80,20,20)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $btnCancel.FlatAppearance.BorderColor = [System.Drawing.Color]::OrangeRed
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.Controls.Add($btnCancel)

    $dlg.AcceptButton = $btnOK
    $dlg.CancelButton = $btnCancel

    Bypass-Log "[~] Esperando confirmacion del usuario..."
    Bypass-SetStatus $btn "ESPERANDO..."
    $resultado = $dlg.ShowDialog()

    if ($resultado -ne [System.Windows.Forms.DialogResult]::OK) {
        Bypass-Log "[!] Cancelado por el usuario."
        Bypass-SetStatus $btn "BYPASS BANCARIO"; return
    }
    Bypass-Log "[+] Usuario confirmo - continuando automatico..."
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 3: Activar Zygisk=1 + DenyList=1 en DB
    # -------------------------------------------------------
    Bypass-Log "[2] Activando Zygisk y DenyList en DB..."
    $zv1 = Set-MagiskSetting "zygisk" "1"
    $dl1 = Set-MagiskSetting "denylist" "1"
    Bypass-Log "[+] Zygisk: '$zv1'  DenyList: '$dl1'"
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 4: Agregar apps bancarias a DenyList
    # -------------------------------------------------------
    Bypass-Log "[3] Configurando DenyList con apps bancarias..."
    Bypass-SetStatus $btn "DENYLIST..."
    $foundApps = Configure-MagiskDenyList
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 5: Shamiko blacklist mode
    # -------------------------------------------------------
    Bypass-Log "[4] Shamiko blacklist mode..."
    & adb shell "su -c 'mkdir -p /data/adb/shamiko && rm -f /data/adb/shamiko/whitelist'" 2>$null | Out-Null
    $wl = (& adb shell "su -c '[ -f /data/adb/shamiko/whitelist ] && echo EXISTE || echo AUSENTE'" 2>$null) -join ""
    Bypass-Log "[+] whitelist: $($wl.Trim())  (AUSENTE = blacklist mode)"
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 6: Desactivar Zygisk (DenyList queda activa)
    # -------------------------------------------------------
    Bypass-Log "[5] Desactivando Zygisk (DenyList queda activa aunque aparezca gris)..."
    $zv2 = Set-MagiskSetting "zygisk" "0"
    $dl2 = Set-MagiskSetting "denylist" "1"
    Bypass-Log "[+] Zygisk: '$zv2'  DenyList: '$dl2'  (correcto: 0 y 1)"
    Bypass-Log ""

    # Limpiar flags disable
    Bypass-Log "[6] Limpiando flags disable de modulos..."
    foreach ($mid in @("zygisk_shamiko","zygisk_lsposed","zygisksu")) {
        & adb shell "su -c 'rm -f /data/adb/modules/$mid/disable'" 2>$null | Out-Null
        Bypass-Log "    [OK] $mid"
    }
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 7: Ocultar Magisk (renombrar app para que no sea detectable)
    # METODO: "Ocultar la app" de Magisk - renombra el paquete APK a uno
    #         aleatorio (ej: com.rnx.manager) y cambia el icono.
    #         La app sigue funcionando con el nuevo nombre/icono.
    # -------------------------------------------------------
    Bypass-Log "[7] Ocultando Magisk..."
    Bypass-SetStatus $btn "OCULTANDO MAGISK..."
    Bypass-Log "    METODO: Magisk 'Ocultar la app' (renombrado de paquete)"
    Bypass-Log "    El APK se reinstala con nombre de paquete aleatorio."
    Bypass-Log "    Apps bancarias no pueden detectarlo por nombre de paquete."
    Bypass-Log ""

    # Intentar hide automatico via CLI
    $hideResult = AdbRoot "magisk --hide enable 2>/dev/null || echo NO_SUPPORTED"
    $hideOk = $false
    if ($hideResult -notmatch "NO_SUPPORTED|error|fail") {
        Bypass-Log "[+] Magisk hide activado automaticamente via CLI"
        $hideOk = $true
    } else {
        AdbRoot "pm hide com.topjohnwu.magisk 2>/dev/null" | Out-Null
        $pmHide = AdbRoot "pm list packages -d com.topjohnwu.magisk 2>/dev/null"
        if ($pmHide -imatch "com.topjohnwu.magisk") {
            Bypass-Log "[+] Magisk ocultado del launcher (pm hide fallback)"
            $hideOk = $true
        }
    }

    if (-not $hideOk) {
        Bypass-Log "[~] Hide automatico no disponible - ACCION MANUAL (30 seg):"
        Bypass-Log "       1. Abre Magisk en el telefono"
        Bypass-Log "       2. Ve a: Configuracion (engranaje)"
        Bypass-Log "       3. Toca: 'Ocultar la app Magisk'"
        Bypass-Log "       4. Ingresa un nombre cualquiera (ej: 'Gestor')"
        Bypass-Log "       5. Toca OK y acepta la reinstalacion"
        Bypass-Log "       -> La app reaparece con el nuevo nombre e icono"
    }

    Bypass-Log ""
    Bypass-Log "    COMO REVERTIR (hacer Magisk visible de nuevo):"
    Bypass-Log "    OPCION A - Desde la app renombrada:"
    Bypass-Log "       1. Busca el icono con el nombre que elegiste (ej: 'Gestor')"
    Bypass-Log "       2. Configuracion -> 'Restaurar app Magisk'"
    Bypass-Log "       3. La app vuelve a llamarse 'Magisk' con icono original"
    Bypass-Log "    OPCION B - Via ADB (si no encuentras la app):"
    Bypass-Log "       adb shell pm list packages | findstr magisk"
    Bypass-Log "       (el paquete aleatorio aparece listado)"
    Bypass-Log "       adb shell pm unhide <nombre.paquete.aleatorio>"
    Bypass-Log "    OPCION C - Via ADB root:"
    Bypass-Log "       adb shell su -c 'pm unhide com.topjohnwu.magisk'"
    Bypass-Log ""

    # -------------------------------------------------------
    # PASO 8: Reiniciar
    # -------------------------------------------------------
    Bypass-Log "[8] Reiniciando..."
    Bypass-SetStatus $btn "REINICIANDO..."
    & adb reboot 2>$null; Start-Sleep -Seconds 8
    [System.Windows.Forms.Application]::DoEvents()

    if (Wait-AdbReconnect 150) {
        Start-Sleep -Seconds 8
        [System.Windows.Forms.Application]::DoEvents()
        $rootFinal = AdbRoot "id"

        # Estado de modulos post-reboot
        $modLines = @()
        foreach ($checkMod in @("zygisk_shamiko","zygisk_lsposed","zygisksu")) {
            $isDis = (& adb shell "su -c '[ -f /data/adb/modules/$checkMod/disable ] && echo SUSPENDIDO || echo ACTIVO'" 2>$null) -join ""
            $modLines += "$checkMod -> $($isDis.Trim())"
        }

        $denylistDB = Get-MagiskSetting "denylist"
        $zygiskDB   = Get-MagiskSetting "zygisk"
        $znStatus   = AdbRoot "cat /data/adb/modules/zygisksu/status 2>/dev/null || grep '^version' /data/adb/modules/zygisksu/module.prop 2>/dev/null"

        Bypass-Log ""
        Bypass-Log "============================================="
        Bypass-Log "  RESUMEN BYPASS BANCARIO"
        Bypass-Log "============================================="
        Bypass-Log "  Dispositivo   : $devModel"
        Bypass-Log "  Root final    : $rootFinal"
        Bypass-Log "  Zygisk DB     : $zygiskDB  (debe ser 0)"
        Bypass-Log "  DenyList DB   : $denylistDB  (debe ser 1)"
        Bypass-Log ""
        Bypass-Log "  Estado modulos:"
        foreach ($ml in $modLines) { Bypass-Log "    $ml" }
        Bypass-Log ""
        Bypass-Log "  Zygisk Next   : $($znStatus.Trim())"
        Bypass-Log "  Apps ocultas  : $($foundApps.Count)"
        foreach ($app in $foundApps) { Bypass-Log "    * $app" }
        Bypass-Log "============================================="
        Bypass-Log ""
        Bypass-Log "[OK] BYPASS COMPLETADO"
        Bypass-Log ""
        Bypass-Log "[~] VERIFICACION:"
        Bypass-Log "    1. Magisk > Modulos: 3 modulos activos"
        Bypass-Log "    2. Magisk > Zygisk OFF -> NORMAL"
        Bypass-Log "    3. Abre Yape/BCP -> no detecta root"
        $Global:lblRoot.ForeColor = [System.Drawing.Color]::Lime
        $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  BYPASS OK  |  $devModel"
    } else {
        Bypass-Log "[~] Verificacion no disponible - reconecta ADB manualmente"
    }
    Bypass-SetStatus $btn "BYPASS BANCARIO"
})
$btnsA2[2].Add_Click({
    # ============================================================
    # FIX LOGO SAMSUNG - Flashea logo de arranque via ADB/Fastboot
    # ============================================================
    $btn = $btnsA2[2]
    $btn.Enabled = $false; $btn.Text = "EJECUTANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    $Global:logAdb.Clear()
    AdbLog "=============================================="
    AdbLog "   FIX LOGO SAMSUNG  -  RNX TOOL PRO"
    AdbLog "   $(Get-Date -Format 'dd/MM/yyyy  HH:mm:ss')"
    AdbLog "=============================================="
    AdbLog ""
    AdbLog "[~] Selecciona la imagen de logo (logo.img / up_param.img)"
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter = "Logo Image (*.img;*.bin)|*.img;*.bin|Todos|*.*"
    $fd.Title  = "Selecciona logo.img o up_param.img de Samsung"
    if ($fd.ShowDialog() -ne "OK") {
        AdbLog "[~] Cancelado."
        $btn.Enabled = $true; $btn.Text = "FIX LOGO SAMSUNG"; return
    }
    $imgPath = $fd.FileName
    $imgName = [System.IO.Path]::GetFileName($imgPath)
    AdbLog "[+] Archivo : $imgName"
    AdbLog ""
    $fbExe  = Get-FastbootExe
    $fbOut  = if ($fbExe) { (& $fbExe devices 2>$null) -join "" } else { "" }
    $adbOut = (& adb devices 2>$null) -join ""
    if ($fbOut -imatch "\tfastboot") {
        AdbLog "[+] Modo Fastboot detectado"
        AdbLog "[~] Flasheando logo via fastboot..."
        try {
            $ec = Invoke-FastbootLive "flash logo `"$imgPath`""
            if ($ec -eq 0) { AdbLog ""; AdbLog "[OK] Logo flasheado correctamente via Fastboot." }
            else { AdbLog "[!] Flash termino con codigo: $ec" }
        } catch { AdbLog "[!] Error: $_" }
    } elseif ($adbOut -imatch "`tdevice") {
        AdbLog "[+] Modo ADB detectado"
        AdbLog "[~] Copiando imagen al dispositivo..."
        try {
            & adb push "$imgPath" "/sdcard/logo_rnx.img" 2>$null | Out-Null
            AdbLog "[+] Imagen copiada a /sdcard/logo_rnx.img"
            AdbLog "[~] Reiniciando a fastboot para flashear..."
            & adb reboot bootloader 2>$null
            AdbLog "[~] Esperando modo Fastboot (12s)..."
            Start-Sleep -Seconds 12; [System.Windows.Forms.Application]::DoEvents()
            $ec2 = Invoke-FastbootLive "flash logo /sdcard/logo_rnx.img"
            if ($ec2 -eq 0) { AdbLog ""; AdbLog "[OK] Logo flasheado correctamente." }
            else { AdbLog "[!] Fallo el flash (cod: $ec2)" }
        } catch { AdbLog "[!] Error: $_" }
    } else {
        AdbLog "[!] No se detecta dispositivo ADB ni Fastboot."
        AdbLog "    Conecta el equipo y reintenta."
    }
    $btn.Enabled = $true; $btn.Text = "FIX LOGO SAMSUNG"
})
#==========================================================================
# ACTIVAR SIM 2 SAMSUNG - logica EFS backup + modificacion via ADB root
# (funcionalidad transferida del boton EFS BACKUP/MOD de Utilidades Firmware)
#==========================================================================
$btnsA2[3].Add_Click({
    $btn = $btnsA2[3]
    $btn.Enabled = $false; $btn.Text = "EJECUTANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $Global:logAdb.Clear()
        AdbLog ""
        AdbLog "[*] =========================================="
        AdbLog "[*]   ACTIVAR SIM 2 SAMSUNG  -  RNX TOOL PRO"
        AdbLog "[*]   EFS Backup + Modificacion (ADB Root)"
        AdbLog "[*] =========================================="
        AdbLog ""

        # Verificar ADB
        $s = (& adb shell getprop ro.serialno 2>$null).Trim()
        if (-not $s) { AdbLog "[!] No hay equipo conectado via ADB"; return }
        AdbLog "[+] Dispositivo: $s"

        # Verificar root
        AdbLog "[~] Verificando root..."
        $root = (& adb shell "su -c id" 2>$null)
        if ($root -match "uid=0") {
            AdbLog "[+] ROOT : OK"
            $Global:lblRoot.Text      = "ROOT        : SI"
            $Global:lblRoot.ForeColor = [System.Drawing.Color]::Lime
        } else {
            AdbLog "[!] ROOT : NO detectado"
            $Global:lblRoot.Text      = "ROOT        : NO"
            $Global:lblRoot.ForeColor = [System.Drawing.Color]::Red
            AdbLog "[!] Esta operacion requiere root (Magisk/SuperSU)"
            return
        }

        # Crear carpeta BACKUPS
        if (-not (Test-Path "BACKUPS")) { New-Item -ItemType Directory -Name "BACKUPS" | Out-Null }
        $date   = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $backup = "BACKUPS\efs_sim2_$date.img"

        # Backup EFS
        AdbLog "[~] Creando backup de EFS..."
        & adb shell "su -c 'dd if=/dev/block/by-name/efs of=/sdcard/efs_sim2.img'" 2>$null
        & adb pull /sdcard/efs_sim2.img $backup 2>$null

        if (Test-Path $backup) {
            $sz = [math]::Round((Get-Item $backup).Length / 1KB, 1)
            $sha256bak = (Get-FileHash $backup -Algorithm SHA256).Hash.ToLower()
            AdbLog "[+] Backup guardado  : $backup ($sz KB)"
            AdbLog "[+] SHA256 backup    : $($sha256bak.Substring(0,16))..."
            AdbLog "[+] SHA256 completo  : $sha256bak"
        } else {
            AdbLog "[!] No se pudo crear backup - particion EFS no encontrada"
            AdbLog "[!] Verifica que el dispositivo tenga particion EFS"
            return
        }

        # Modificacion EFS Samsung SIM 2 - renombrar archivos sensibles
        AdbLog ""
        AdbLog "[~] Modificando EFS (activando SIM 2)..."
        & adb shell "su -c 'mount -o rw,remount /efs'" 2>$null

        $efs_ops = @(
            @("mv /efs/esim.prop",    "/efs/000000000"),
            @("mv /efs/factory.prop", "/efs/000000000000"),
            @("mv /efs/wv.keys",      "/efs/0000000"),
            @("mv /efs/mps_code.dat", "/efs/000000000000_mps"),
            @("mv /efs/mep_mode",     "/efs/00000000")
        )
        foreach ($op in $efs_ops) {
            $cmd = "$($op[0]) $($op[1]) 2>/dev/null || echo SKIP"
            $res = (& adb shell "su -c '$cmd'" 2>$null).Trim()
            $opStatus = if ($res -match "SKIP") { "[SKIP]" } else { "[OK]  " }
            AdbLog "  $opStatus $($op[0]) -> $($op[1])"
        }

        # Verificacion post-modificacion
        AdbLog ""
        AdbLog "[~] Verificacion post-modificacion..."
        $efsLs = (& adb shell "su -c 'ls /efs/'" 2>$null) -join " "
        AdbLog "[+] Contenido /efs/ : $efsLs"

        AdbLog ""
        AdbLog "[+] EFS modificado correctamente"
        AdbLog "[~] Reiniciando dispositivo..."
        & adb reboot 2>$null
        AdbLog "[OK] LISTO - equipo reiniciando"
        AdbLog "[~] La SIM 2 deberia ser reconocida al iniciar"

    } catch { AdbLog "[!] Error inesperado: $_" }
    finally { $btn.Enabled = $true; $btn.Text = "ACTIVAR SIM 2 SAMSUNG" }
})
$btnsA3[0].Add_Click({
    # ============================================================
    # BLOQUEAR OTA - version estable sin contaminacion de scope
    # ============================================================
    $btn = $btnsA3[0]
    $btn.Enabled = $false
    $btn.Text    = "BLOQUEANDO OTA..."
    [System.Windows.Forms.Application]::DoEvents()

    $Global:logAdb.Clear()
    AdbLog "=============================================="
    AdbLog "   OTA BLOCKER  -  RNX TOOL PRO"
    AdbLog "   $(Get-Date -Format 'dd/MM/yyyy  HH:mm:ss')"
    AdbLog "=============================================="
    AdbLog ""

    # Helper de log con timestamp (scriptblock, NO function - no contamina scope global)
    $otaLog = { param($m); AdbLog ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m) }

    # Helper de bloqueo (scriptblock inline)
    # IMPORTANTE: para Xiaomi/HyperOS NUNCA se usa pm uninstall --user 0
    # porque puede dejar el sistema sin servicios criticos y entrar en bootloop.
    # Solo se usa pm disable-user (reversible) + pm clear (limpia cache).
    # pm suspend solo se aplica a Samsung como fallback adicional.
    $otaBlock = {
        param($pkg, $agr)
        try {
            # Intento 1: disable-user (reversible, seguro en todos los sistemas)
            $r1 = (& adb shell pm disable-user --user 0 $pkg 2>&1) -join ""
            if ($r1 -imatch "disabled|success") {
                # Limpiar cache del paquete deshabilitado
                try { & adb shell pm clear $pkg 2>$null | Out-Null } catch {}
                return "disabled"
            }
            # Intento 2: solo para Samsung (NO Xiaomi/HyperOS) - pm suspend como fallback
            # Para Xiaomi NO se hace pm uninstall porque puede romper el sistema
            if ($agr -eq "samsung_only") {
                $r3 = (& adb shell cmd package suspend $pkg 2>&1) -join ""
                if ($r3 -imatch "suspend|success|done") { return "disabled" }
            }
        } catch {}
        return "failed"
    }

    # -- Listas OTA por marca ------------------------------------------
    $OTA_UNIVERSAL = @(
        "com.android.updater","com.android.ota",
        "com.google.android.modulemetadata","com.google.android.configupdater",
        "com.google.android.gms.update","com.google.android.update"
    )
    $OTA_SAMSUNG = @(
        "com.wssyncmldm","com.sec.android.soagent","com.samsung.sdm",
        "com.samsung.sdm.sdmviewer","com.ws.dm","com.samsung.android.fota",
        "com.samsung.android.fotaclient","com.samsung.android.mdm",
        "com.sec.android.preloadinstaller","com.samsung.android.sm.policy",
        "com.sec.android.systemupdate","com.samsung.android.sdm.policy"
    )
    $OTA_XIAOMI = @(
        "com.android.updater","com.miui.updater","com.miui.fota",
        "com.xiaomi.mipush.sdk","com.miui.systemAdSolution","com.miui.cloudservice",
        "com.miui.analytics","com.xiaomi.xmsf","com.xiaomi.discover","com.miui.msa.global"
    )
    $OTA_OPPO    = @("com.coloros.sau","com.oplus.ota","com.oppo.ota","com.coloros.ota","com.realme.ota","com.coloros.packageinstaller")
    $OTA_MOTOROLA= @("com.motorola.ccc.ota","com.motorola.android.fota","com.motorola.MotoDMClient","com.motorola.targetnotif")
    $OTA_HUAWEI  = @("com.huawei.android.hwouc","com.huawei.android.hwota","com.hihonor.ouc","com.huawei.iconnect")
    $OTA_VIVO    = @("com.vivo.updater","com.vivo.daemonService","com.bbk.updater","com.vivo.pushclient")
    $OTA_ASUS    = @("com.asus.dm","com.asus.fota","com.asus.systemupdate")
    $OTA_SONY    = @("com.sonymobile.updatecenter","com.sonymobile.updater")
    $OTA_ONEPLUS = @("com.oneplus.ota","net.oneplus.odm")

    # -- ETAPA 0: Verificar ADB ----------------------------------------
    & $otaLog "[0/7] Verificando ADB..."
    $adbOK = $false
    try { $adbOK = ((& adb devices 2>$null) -join "" -match "`tdevice") } catch {}
    if (-not $adbOK) {
        & $otaLog "[!] Sin ADB. Conecta el equipo con USB Debugging activado."
        $btn.Enabled = $true; $btn.Text = "BLOQUEAR OTA"; return
    }

    $serial  = ""; $model = ""; $android = ""; $sdkRaw = ""; $oneui = ""; $hyperos = ""
    try { $serial  = (& adb get-serialno 2>$null).Trim() } catch {}
    try { $model   = (& adb shell getprop ro.product.model         2>$null).Trim() } catch {}
    try { $android = (& adb shell getprop ro.build.version.release 2>$null).Trim() } catch {}
    try { $sdkRaw  = (& adb shell getprop ro.build.version.sdk     2>$null).Trim() } catch {}
    try { $oneui   = (& adb shell getprop ro.build.version.oneui   2>$null).Trim() } catch {}
    try { $hyperos = (& adb shell getprop ro.mi.os.version.name    2>$null).Trim() } catch {}

    # Cast seguro del SDK
    $sdk = 0
    if ($sdkRaw -match "^\d+$") { $sdk = [int]$sdkRaw }

    & $otaLog "[+] Modelo: $model  |  Android: $android  (SDK $sdk)"
    if ($oneui)   { & $otaLog "[+] One UI  : $oneui" }
    if ($hyperos) { & $otaLog "[+] HyperOS : $hyperos" }
    AdbLog ""

    # -- ETAPA 1: Snapshot ---------------------------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[1/7] Capturando lista de paquetes..."
    $allPkgs = @()
    try { $allPkgs = (& adb shell pm list packages 2>$null) -replace "package:","" } catch {}
    $allPkgs = $allPkgs | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    $disabledBefore = 0
    try {
        $disabledBefore = ((& adb shell pm list packages -d 2>$null) -replace "package:","" |
                           ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }).Count
    } catch {}
    & $otaLog "[+] Paquetes: $($allPkgs.Count)  |  Ya deshabilitados: $disabledBefore"
    AdbLog ""

    # -- ETAPA 2: Detectar fabricante y modo ---------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[2/7] Detectando fabricante..."
    $mfrRaw = ""; $brand = ""
    try { $mfrRaw = (& adb shell getprop ro.product.manufacturer 2>$null).Trim().ToLower() } catch {}
    try { $brand  = (& adb shell getprop ro.product.brand        2>$null).Trim().ToLower() } catch {}

    $useAgressive = $false
    $OTA_BRAND    = @()
    $brandLabel   = "Desconocido"

    if ($mfrRaw -match "samsung") {
        $OTA_BRAND = $OTA_SAMSUNG
        $isOneUI78 = ($oneui -match "^[78]" -or $sdk -ge 35)
        if ($isOneUI78) {
            $brandLabel = "Samsung One UI 7/8 (Android 15/16)"
            & $otaLog "[!] One UI 7/8 / Android 15+ -> bloqueo SDM activado"
        } else { $brandLabel = "Samsung" }
    } elseif ($mfrRaw -match "xiaomi|redmi|poco") {
        $OTA_BRAND    = $OTA_XIAOMI
        $useAgressive = $true
        $hyperVer = ""
        try { $hyperVer = (& adb shell getprop ro.mi.os.version.incremental 2>$null).Trim() } catch {}
        if ($hyperos -imatch "HyperOS" -and $hyperVer -match "^2") {
            $brandLabel = "Xiaomi HyperOS 2 - modo agresivo"
            & $otaLog "[!] HyperOS 2 -> disable + uninstall fallback"
        } elseif ($hyperos -imatch "HyperOS") {
            $brandLabel = "Xiaomi HyperOS 1 - modo agresivo"
        } else { $brandLabel = "Xiaomi/MIUI - modo agresivo" }
    } elseif ($mfrRaw -match "oppo|realme")  { $OTA_BRAND = $OTA_OPPO;     $brandLabel = "OPPO/ColorOS" }
    elseif ($mfrRaw -match "motorola")        { $OTA_BRAND = $OTA_MOTOROLA; $brandLabel = "Motorola" }
    elseif ($mfrRaw -match "huawei|honor")    { $OTA_BRAND = $OTA_HUAWEI;   $brandLabel = "Huawei/Honor" }
    elseif ($mfrRaw -match "vivo")            { $OTA_BRAND = $OTA_VIVO;     $brandLabel = "Vivo/BBK" }
    elseif ($mfrRaw -match "asus")            { $OTA_BRAND = $OTA_ASUS;     $brandLabel = "ASUS" }
    elseif ($mfrRaw -match "sony")            { $OTA_BRAND = $OTA_SONY;     $brandLabel = "Sony" }
    elseif ($mfrRaw -match "oneplus")         { $OTA_BRAND = $OTA_ONEPLUS;  $brandLabel = "OnePlus" }

    if ($brandLabel -eq "Desconocido") {
        if ($brand -match "samsung")               { $OTA_BRAND = $OTA_SAMSUNG; $brandLabel = "Samsung (brand)" }
        elseif ($brand -match "xiaomi|redmi|poco") { $OTA_BRAND = $OTA_XIAOMI;  $useAgressive = $true; $brandLabel = "Xiaomi (brand)" }
    }

    & $otaLog "[+] Fabricante : $mfrRaw  |  Lista: $brandLabel"
    & $otaLog "[+] Modo agresivo: $(if($useAgressive){'SI'}else{'NO'})"

    # Combinar listas sin duplicados - HashSet para O(1) lookup
    $OTA_TARGET = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in ($OTA_UNIVERSAL + $OTA_BRAND)) {
        $p = $p.Trim()
        if ($p -and $seen.Add($p)) { $OTA_TARGET.Add($p) }
    }
    & $otaLog "[+] Total a evaluar: $($OTA_TARGET.Count)"
    AdbLog ""

    # -- ETAPA 3: Bloquear paquetes ------------------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[3/7] Bloqueando paquetes OTA..."
    AdbLog ""

    $cntFound=0; $cntDisabled=0; $cntUninstalled=0; $cntSkipped=0; $cntNotFound=0; $cntFailed=0

    # HashSet para lookups O(1) - inmune a \r\n residuales de ADB
    $disabledSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        (& adb shell pm list packages -d 2>$null) -replace "package:","" |
        ForEach-Object { $t = $_.Trim(); if ($t) { $disabledSet.Add($t) | Out-Null } }
    } catch {}

    $allPkgsSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $allPkgs) { $allPkgsSet.Add($p) | Out-Null }

    foreach ($pkg in $OTA_TARGET) {
        if (-not $allPkgsSet.Contains($pkg)) {
            & $otaLog "  [--] No encontrado  : $pkg"
            $cntNotFound++; continue
        }
        $cntFound++
        if ($disabledSet.Contains($pkg)) {
            & $otaLog "  [>>] Ya deshabilitado: $pkg"
            $cntSkipped++; continue
        }
        $result = & $otaBlock $pkg "no"
        # Para Samsung: permitir suspend como fallback adicional (no uninstall)
        if ($result -eq "failed" -and ($mfrRaw -match "samsung" -or $brand -match "samsung")) {
            $result = & $otaBlock $pkg "samsung_only"
        }
        switch ($result) {
            "disabled"    { & $otaLog "  [OK] Deshabilitado  : $pkg"; $cntDisabled++ }
            "uninstalled" { & $otaLog "  [OK] Desinstalado   : $pkg  (fallback)"; $cntUninstalled++ }
            "failed"      {
                & $otaLog "  [!!] Fallo          : $pkg"
                $cntFailed++
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    AdbLog ""

    # -- ETAPA 4: Escaneo dinamico -------------------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[4/7] Escaneo dinamico..."
    $dynPattern = "\.ota\.|\.fota\.|\.fotaclient|\.updater$|\.update$|systemupdate|fotaagent|wssync|soagent|\.sdm\.|sdmviewer"
    $dynFound = 0
    foreach ($p in $allPkgs) {
        if (-not $p) { continue }
        if ($p -imatch $dynPattern -and $seen.Add($p)) {
            & $otaLog "  [~~] Detectado dinamico: $p"
            $dynFound++
            if ($disabledSet.Contains($p)) {
                & $otaLog "  [>>] Ya deshabilitado : $p"; $cntSkipped++
            } else {
                $r2 = & $otaBlock $p "no"
                switch ($r2) {
                    "disabled"    { & $otaLog "  [OK] Deshabilitado    : $p"; $cntDisabled++ }
                    "uninstalled" { & $otaLog "  [OK] Desinstalado     : $p"; $cntUninstalled++ }
                    "failed"      { & $otaLog "  [!!] Fallo            : $p"; $cntFailed++ }
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    if ($dynFound -eq 0) { & $otaLog "[+] Sin paquetes OTA adicionales detectados." }
    AdbLog ""

    # -- ETAPA 5: Settings globales ------------------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[5/7] Aplicando settings globales..."
    foreach ($pair in @(
        @("ota_disable_automatic_update","1"), @("auto_update_system","0"),
        @("auto_update_time","0"),             @("auto_update_wifi_only","0"),
        @("package_verifier_enable","0"),      @("verifier_verify_adb_installs","0")
    )) {
        try {
            $r = (& adb shell settings put global $pair[0] $pair[1] 2>&1) -join ""
            if (-not $r) { & $otaLog "  [OK] $($pair[0]) = $($pair[1])" }
            else          { & $otaLog "  [~]  $($pair[0]) -> $r" }
        } catch {}
        [System.Windows.Forms.Application]::DoEvents()
    }

    # Refuerzo Samsung One UI 7/8
    if ($sdk -ge 35 -and ($mfrRaw -match "samsung" -or $brand -match "samsung")) {
        & $otaLog ""; & $otaLog "[~] Refuerzo Samsung One UI 7/8 -- limpiando cache SDM..."
        foreach ($cmd in @("pm clear com.wssyncmldm","pm clear com.sec.android.soagent",
                           "pm clear com.samsung.sdm","pm clear com.sec.android.systemupdate")) {
            try {
                $rc = (& adb shell $cmd 2>&1) -join ""
                & $otaLog "  $(if($rc -imatch 'Success'){'[OK]'}else{'[~]'}) $($cmd -replace 'pm clear ','')"
            } catch {}
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    # Refuerzo HyperOS - SOLO pm clear (seguro, no afecta servicios del sistema)
    # Se elimino cmd package suspend porque puede dejar el equipo en bootloop
    # en HyperOS 1 y 2 cuando afecta servicios del sistema criticos.
    if ($useAgressive) {
        & $otaLog ""; & $otaLog "[~] Refuerzo HyperOS -- limpiando cache OTA (pm clear)..."
        foreach ($pkg in @("com.android.updater","com.miui.updater","com.miui.fota")) {
            if ($allPkgsSet.Contains($pkg)) {
                try { & adb shell pm clear $pkg 2>$null | Out-Null } catch {}
                & $otaLog "  [OK] cache limpiado: $pkg"
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    AdbLog ""

    # -- ETAPA 6: Verificacion post-bloqueo ----------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[6/7] Verificacion post-bloqueo..."
    $disabledNowSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        (& adb shell pm list packages -d 2>$null) -replace "package:","" |
        ForEach-Object { $t = $_.Trim(); if ($t) { $disabledNowSet.Add($t) | Out-Null } }
    } catch {}
    $allNowSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        (& adb shell pm list packages 2>$null) -replace "package:","" |
        ForEach-Object { $t = $_.Trim(); if ($t) { $allNowSet.Add($t) | Out-Null } }
    } catch {}
    $cntVerified=0; $cntStillActive=0
    foreach ($pkg in $OTA_TARGET) {
        if (-not $allPkgsSet.Contains($pkg)) { continue }
        if     ($disabledNowSet.Contains($pkg))  { $cntVerified++ }
        elseif (-not $allNowSet.Contains($pkg))  { $cntVerified++ }
        else { & $otaLog "  [!!] Activo aun: $pkg"; $cntStillActive++ }
    }
    & $otaLog "[+] Verificados OK: $cntVerified  |  Activos aun: $cntStillActive"
    AdbLog ""

    # -- ETAPA 7: Estado final -----------------------------------------
    AdbLog "----------------------------------------------"
    & $otaLog "[7/7] Estado final..."
    $disabledAfter = $disabledNowSet.Count
    & $otaLog "[+] Deshabilitados antes: $disabledBefore  |  Ahora: $disabledAfter  |  Nuevos: $($disabledAfter - $disabledBefore)"
    AdbLog ""

    AdbLog "=============================================="
    AdbLog "  RESUMEN OTA BLOCKER"
    AdbLog "=============================================="
    AdbLog "  Dispositivo  : $model  ($serial)"
    AdbLog "  Android      : $android  (SDK $sdk)  [$brandLabel]"
    AdbLog "  Evaluados         : $($cntFound + $cntNotFound)"
    AdbLog "  Deshabilitados OK : $cntDisabled"
    AdbLog "  Desinstalados OK  : $cntUninstalled"
    AdbLog "  Ya bloqueados     : $cntSkipped"
    AdbLog "  No encontrados    : $cntNotFound"
    AdbLog "  Fallidos          : $cntFailed"
    AdbLog "  Dinamicos extra   : $dynFound"
    AdbLog ""
    $totalOK = $cntDisabled + $cntUninstalled
    if ($totalOK -gt 0)                             { AdbLog "[OK] $totalOK paquetes OTA bloqueados exitosamente." }
    elseif ($cntSkipped -gt 0 -and $totalOK -eq 0) { AdbLog "[OK] Todos los OTA ya estaban bloqueados." }
    else                                             { AdbLog "[~]  Sin paquetes OTA activos encontrados." }
    if ($cntFailed -gt 0)      { AdbLog "[~]  $cntFailed fallaron (puede requerir root)." }
    if ($cntStillActive -gt 0) { AdbLog "[!]  $cntStillActive siguen activos -- usa root para bloqueo total." }
    if ($useAgressive)         { AdbLog "[~]  HyperOS: si OTA reaparece tras reinicio, repetir." }
    if ($sdk -ge 35 -and ($mfrRaw -match "samsung" -or $brand -match "samsung")) {
        AdbLog "[~]  Samsung: SDM puede reactivarse tras Smart Switch restore."
    }
    AdbLog "[~]  Reinicia el dispositivo para aplicar todos los cambios."
    AdbLog "=============================================="

    $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  OTA BLOQUEADO  |  $model"
    $btn.Enabled = $true
    $btn.Text    = "BLOQUEAR OTA"
})

$btnsA3[1].Add_Click({
    # ============================================================
    # REMOVER ADWARE v2 - escaner permisos, buscador, whitelist, turbo
    # ============================================================
    $btn = $btnsA3[1]
    $btn.Enabled = $false; $btn.Text = "ANALIZANDO..."
    [System.Windows.Forms.Application]::DoEvents()

    $mwLog2 = { param($m); AdbLog ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m) }

    $adbOK = $false
    try { $adbOK = ((& adb devices 2>$null) -join "" -match "`tdevice") } catch {}
    if (-not $adbOK) {
        AdbLog "[!] Sin ADB. Conecta el equipo con USB Debugging activado."
        $btn.Enabled = $true; $btn.Text = "REMOVER ADWARE"; return
    }

    $model  = ""; $serial = ""
    try { $model  = (& adb shell getprop ro.product.model 2>$null).Trim() } catch {}
    try { $serial = (& adb get-serialno 2>$null).Trim() } catch {}

    # ---- WHITELIST: paquetes del sistema que NUNCA se marcan ni borran ----
    $sysWhitelist = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            "com.google.android.gms","com.google.android.gsf","com.google.android.googlequicksearchbox",
            "com.google.android.apps.photos","com.google.android.youtube","com.google.android.apps.maps",
            "com.google.android.inputmethod.latin","com.google.android.tts","com.google.android.webview",
            "com.google.android.packageinstaller","com.google.android.permissioncontroller",
            "com.google.android.play.games","com.google.android.gmscore",
            "com.google.android.syncadapters.contacts",
            "com.samsung.android.contacts","com.samsung.android.messaging","com.samsung.android.dialer",
            "com.samsung.android.app.galaxystore","com.samsung.android.lool",
            "com.samsung.android.mobileservice","com.samsung.android.providers.contacts",
            "com.samsung.android.app.clockpackage","com.samsung.android.app.notes",
            "com.samsung.android.calendar","com.samsung.android.incallui",
            "com.samsung.android.app.smartcapture","com.samsung.android.app.spage",
            "com.samsung.android.app.settings.bixby","com.samsung.android.knox.containeragent",
            "com.android.settings","com.android.systemui","com.android.phone",
            "com.android.providers.telephony","com.android.providers.contacts",
            "com.android.providers.media","com.android.providers.downloads",
            "com.android.launcher3","com.android.inputmethod.latin",
            "com.android.packageinstaller","com.android.permissioncontroller",
            "android","com.android.server.telecom"
        ),
        [System.StringComparer]::OrdinalIgnoreCase
    )

    # ---- PERMISOS PELIGROSOS con peso de score ----
    $dangerPerms = @{
        "RECORD_AUDIO"=3; "READ_SMS"=3; "RECEIVE_SMS"=3; "SEND_SMS"=2
        "READ_CALL_LOG"=3; "PROCESS_OUTGOING_CALLS"=2
        "ACCESS_FINE_LOCATION"=2; "ACCESS_BACKGROUND_LOCATION"=3
        "CAMERA"=1; "READ_CONTACTS"=1; "WRITE_CONTACTS"=1
        "GET_ACCOUNTS"=1; "READ_PHONE_STATE"=1
        "INSTALL_PACKAGES"=3; "REQUEST_INSTALL_PACKAGES"=2
        "SYSTEM_ALERT_WINDOW"=2; "BIND_ACCESSIBILITY_SERVICE"=3
        "BIND_DEVICE_ADMIN"=3; "RECEIVE_BOOT_COMPLETED"=1
    }

    # ---- FIRMAS Y KEYWORDS conocidas ----
    $autoMark = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            "com.clean.master","com.cleanmaster.mguard","com.junk.clean","com.boost.speed",
            "com.ram.cleaner","com.super.cleaner","com.phone.cleaner","com.best.cleaner",
            "com.antivirus.clean","com.cm.antivirus","com.qihoo360.mobilesafe",
            "com.shield.antivirus","com.mobile.protect","com.security.shield",
            "com.ufo.vpn","com.thunder.vpn","com.free.vpn","com.turbo.vpn","com.snap.vpn",
            "com.apus.launcher","com.go.launcher.ex","com.android.spy","com.spyphone.app",
            "com.mspy.android","com.phonespector","com.system.update.service",
            "com.flash.player.service","com.superantivirus.security","com.superantivirus.cleaner",
            "com.super.antivirus","com.nq.antivirus","com.nq.mobilesafe","am.mobile.security",
            "com.shieldav.free","com.shield.security.antivirus","com.iclean.phone",
            "com.cleanphone.free","com.power.cleaner","com.virus.remover.cleaner",
            "com.mobiapp.superantivirus"
        ),
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $autoKw = @("cleaner","booster","antivirus","virus","spyware","stalker","flashplayer",
                "systemupdate","superclean","cleanphone","mobilesafe","virusremov",
                "virusscann","mspy","spyphone","keylogger","rootkit","trojan","malware","adware")

    # ---- OBTENER LISTA DE APPS ----
    & $mwLog2 "[~] Obteniendo apps instaladas..."
    [System.Windows.Forms.Application]::DoEvents()

    $pkgLines = @()
    try { $pkgLines = (& adb shell pm list packages -3 -f 2>$null) |
          ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } } catch {}

    $appList = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($line in $pkgLines) {
        if ($line -match "^package:(.+)=([^\s]+)$") {
            $apkPath = $Matches[1].Trim(); $pkgName = $Matches[2].Trim()
            if ($pkgName -and -not $sysWhitelist.Contains($pkgName)) {
                $appList.Add(@{ pkg=$pkgName; apk=$apkPath; score=0; permFlags=[System.Collections.Generic.List[string]]::new() })
            }
        } elseif ($line -match "^package:([^\s]+)$") {
            $p = $Matches[1].Trim()
            if ($p -and -not $sysWhitelist.Contains($p)) {
                $appList.Add(@{ pkg=$p; apk=""; score=0; permFlags=[System.Collections.Generic.List[string]]::new() })
            }
        }
    }

    if ($appList.Count -eq 0) {
        AdbLog "[!] No se encontraron apps de terceros."
        $btn.Enabled = $true; $btn.Text = "REMOVER ADWARE"; return
    }

    # ---- ESCANER DE PERMISOS ----
    & $mwLog2 "[~] Escaneando permisos ($($appList.Count) apps)..."
    $ii = 0
    foreach ($app in $appList) {
        $ii++
        if ($ii % 10 -eq 0) { $btn.Text = "ESCANEANDO... $ii/$($appList.Count)"; [System.Windows.Forms.Application]::DoEvents() }
        $pkg = $app.pkg; $score = 0

        if ($autoMark.Contains($pkg)) { $score += 10 }
        foreach ($kw in $autoKw) { if ($pkg -imatch $kw) { $score += 5; break } }

        try {
            $permRaw = (& adb shell "dumpsys package $pkg 2>/dev/null | grep 'granted=true'" 2>$null) -join " "
            foreach ($perm in $dangerPerms.Keys) {
                if ($permRaw -imatch $perm) {
                    $score += $dangerPerms[$perm]
                    $app.permFlags.Add($perm) | Out-Null
                }
            }
        } catch {}
        $app.score = $score
    }

    # ---- MAPA pkg->app y lista ordenada por score ----
    $appMap = @{}
    foreach ($app in $appList) { $appMap[$app.pkg] = $app }
    $allItems = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($app in ($appList | Sort-Object { $_.score } -Descending)) { $allItems.Add($app) }

    # ============================================================
    # CONSTRUIR VENTANA
    # ============================================================
    $win = New-Object Windows.Forms.Form
    $win.Text          = "REMOVER ADWARE / MALWARE  -  RNX TOOL PRO  |  $model  ($serial)"
    $win.ClientSize    = New-Object System.Drawing.Size(940, 630)
    $win.BackColor     = [System.Drawing.Color]::FromArgb(18,18,18)
    $win.FormBorderStyle = "FixedSingle"
    $win.StartPosition = "CenterScreen"
    $win.TopMost       = $true

    $lblHeader = New-Object Windows.Forms.Label
    $lblHeader.Text      = "  [!] = sospechosa   |   score = nivel de riesgo (permisos + firma)   |   apps del sistema excluidas automaticamente"
    $lblHeader.Location  = New-Object System.Drawing.Point(0, 6)
    $lblHeader.Size      = New-Object System.Drawing.Size(940, 18)
    $lblHeader.ForeColor = [System.Drawing.Color]::Cyan
    $lblHeader.Font      = New-Object System.Drawing.Font("Segoe UI",8)
    $win.Controls.Add($lblHeader)

    $lblSearch = New-Object Windows.Forms.Label
    $lblSearch.Text = "Buscar:"; $lblSearch.Location = New-Object System.Drawing.Point(12,30)
    $lblSearch.Size = New-Object System.Drawing.Size(44,22)
    $lblSearch.ForeColor = [System.Drawing.Color]::FromArgb(160,160,160)
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI",8)
    $win.Controls.Add($lblSearch)

    $txtSearch = New-Object Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(58,28); $txtSearch.Size = New-Object System.Drawing.Size(340,22)
    $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(35,35,35); $txtSearch.ForeColor = [System.Drawing.Color]::White
    $txtSearch.Font = New-Object System.Drawing.Font("Consolas",9); $txtSearch.BorderStyle = "FixedSingle"
    $win.Controls.Add($txtSearch)

    $lblCount = New-Object Windows.Forms.Label
    $lblCount.Location = New-Object System.Drawing.Point(410,32); $lblCount.Size = New-Object System.Drawing.Size(520,18)
    $lblCount.ForeColor = [System.Drawing.Color]::FromArgb(120,120,120)
    $lblCount.Font = New-Object System.Drawing.Font("Segoe UI",8)
    $win.Controls.Add($lblCount)

    $clb = New-Object Windows.Forms.CheckedListBox
    $clb.Location = New-Object System.Drawing.Point(12,56); $clb.Size = New-Object System.Drawing.Size(916,512)
    $clb.BackColor = [System.Drawing.Color]::FromArgb(25,25,25); $clb.ForeColor = [System.Drawing.Color]::White
    $clb.Font = New-Object System.Drawing.Font("Consolas",9); $clb.BorderStyle = "FixedSingle"; $clb.CheckOnClick = $true
    $win.Controls.Add($clb)

    # Estado de checks persistente entre filtros
    $checkState = @{}

    $script:MakeLabel = {
        param($app)
        $tag = if     ($app.score -ge 10) { "[!!]" } elseif ($app.score -ge 5) { "[! ]" } else { "[  ]" }
        $pkg = $app.pkg
        $pkgPad = if ($pkg.Length -lt 55) { $pkg.PadRight(55) } else { $pkg.Substring(0,52) + "..." }
        $scoreStr = if ($app.score -gt 0) { "  score:$($app.score.ToString().PadLeft(2))" } else { "          " }
        $permStr = ""
        if ($app.permFlags.Count -gt 0) {
            $abbrevMap = @{
                "RECORD_AUDIO"="MIC"; "READ_SMS"="SMS_R"; "RECEIVE_SMS"="SMS_IN"; "SEND_SMS"="SMS_W"
                "ACCESS_FINE_LOCATION"="GPS"; "ACCESS_BACKGROUND_LOCATION"="GPS_BG"
                "READ_CALL_LOG"="CALLS"; "BIND_ACCESSIBILITY_SERVICE"="A11Y"
                "BIND_DEVICE_ADMIN"="ADMIN"; "INSTALL_PACKAGES"="INST_PKG"
                "REQUEST_INSTALL_PACKAGES"="REQ_INST"; "SYSTEM_ALERT_WINDOW"="OVERLAY"
                "CAMERA"="CAM"; "READ_CONTACTS"="CONT_R"; "PROCESS_OUTGOING_CALLS"="CALLS_OUT"
                "GET_ACCOUNTS"="ACCTS"; "READ_PHONE_STATE"="PHONE"; "RECEIVE_BOOT_COMPLETED"="BOOT"
            }
            $flags = $app.permFlags | ForEach-Object { if ($abbrevMap.ContainsKey($_)) { $abbrevMap[$_] } else { $_ } }
            $shown = $flags | Select-Object -First 4
            $extra = if ($app.permFlags.Count -gt 4) { "+$($app.permFlags.Count - 4)" } else { "" }
            $permStr = "  [" + ($shown -join ",") + $(if ($extra) { ",$extra" } else { "" }) + "]"
        }
        return "$tag $pkgPad$scoreStr$permStr"
    }

    $script:PopulateCLB = {
        param($filter)
        $clb.Items.Clear()
        $shown = 0
        $filterLow = if ($filter) { $filter.ToLower() } else { "" }
        foreach ($app in $allItems) {
            if ($filterLow) {
                $matchPkg   = $app.pkg -imatch [regex]::Escape($filter)
                $matchPerms = ($app.permFlags -join " ") -imatch [regex]::Escape($filter)
                $matchScore = $filter -match "^\d+$" -and $app.score -ge [int]$filter
                if (-not ($matchPkg -or $matchPerms -or $matchScore)) { continue }
            }
            $label     = & $script:MakeLabel $app
            $isChecked = if ($checkState.ContainsKey($app.pkg)) { $checkState[$app.pkg] } else { $app.score -ge 5 }
            if (-not $checkState.ContainsKey($app.pkg)) { $checkState[$app.pkg] = $isChecked }
            $clb.Items.Add($label, $isChecked) | Out-Null; $shown++
        }
        $marked   = 0; for ($i=0; $i -lt $clb.Items.Count; $i++) { if ($clb.GetItemChecked($i)) { $marked++ } }
        $highRisk = ($allItems | Where-Object { $_.score -ge 5 }).Count
        $lblCount.Text = "$($allItems.Count) apps  |  mostrando: $shown  |  seleccionadas: $marked  |  riesgo alto [!!]/[! ]: $highRisk  |  whitelist excluidas"
    }

    & $script:PopulateCLB ""

    $clb.Add_ItemCheck({
        $lbl = $clb.Items[$_.Index].ToString()
        $pkg = ($lbl -replace "^\[.{2,3}\]\s+","" -replace "\s*\[.*","").Trim()
        $checkState[$pkg] = ($_.NewValue -eq "Checked")
        $delta   = if ($_.NewValue -eq "Checked") { 1 } else { -1 }
        $marked  = 0; for ($i=0; $i -lt $clb.Items.Count; $i++) { if ($clb.GetItemChecked($i)) { $marked++ } }
        $marked += $delta
        $highRisk = ($allItems | Where-Object { $_.score -ge 5 }).Count
        $lblCount.Text = "$($allItems.Count) apps  |  mostrando: $($clb.Items.Count)  |  seleccionadas: $marked  |  riesgo alto: $highRisk  |  whitelist excluidas"
    })

    $txtSearch.Add_TextChanged({ & $script:PopulateCLB $txtSearch.Text.Trim() })

    # ---- BOTONES ----
    $btnY = 576

    $btnSelAll = New-Object Windows.Forms.Button
    $btnSelAll.Text="MARCAR TODAS"; $btnSelAll.Location=New-Object System.Drawing.Point(12,$btnY)
    $btnSelAll.Size=New-Object System.Drawing.Size(115,28); $btnSelAll.FlatStyle="Flat"
    $btnSelAll.ForeColor=[System.Drawing.Color]::White; $btnSelAll.BackColor=[System.Drawing.Color]::FromArgb(40,40,40)
    $btnSelAll.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(80,80,80)
    $btnSelAll.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $btnSelAll.Add_Click({
        for ($i=0; $i -lt $clb.Items.Count; $i++) {
            $clb.SetItemChecked($i,$true)
            $pkg=($clb.Items[$i].ToString() -replace "^\[.{2,3}\]\s+","" -replace "\s*\[.*","").Trim()
            $checkState[$pkg]=$true
        }
    })
    $win.Controls.Add($btnSelAll)

    $btnNone = New-Object Windows.Forms.Button
    $btnNone.Text="DESMARCAR"; $btnNone.Location=New-Object System.Drawing.Point(135,$btnY)
    $btnNone.Size=New-Object System.Drawing.Size(100,28); $btnNone.FlatStyle="Flat"
    $btnNone.ForeColor=[System.Drawing.Color]::White; $btnNone.BackColor=[System.Drawing.Color]::FromArgb(40,40,40)
    $btnNone.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(80,80,80)
    $btnNone.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $btnNone.Add_Click({
        for ($i=0; $i -lt $clb.Items.Count; $i++) {
            $clb.SetItemChecked($i,$false)
            $pkg=($clb.Items[$i].ToString() -replace "^\[.{2,3}\]\s+","" -replace "\s*\[.*","").Trim()
            $checkState[$pkg]=$false
        }
    })
    $win.Controls.Add($btnNone)

    $btnOnlySusp = New-Object Windows.Forms.Button
    $btnOnlySusp.Text="SOLO [!]"; $btnOnlySusp.Location=New-Object System.Drawing.Point(243,$btnY)
    $btnOnlySusp.Size=New-Object System.Drawing.Size(90,28); $btnOnlySusp.FlatStyle="Flat"
    $btnOnlySusp.ForeColor=[System.Drawing.Color]::Orange; $btnOnlySusp.BackColor=[System.Drawing.Color]::FromArgb(40,30,10)
    $btnOnlySusp.FlatAppearance.BorderColor=[System.Drawing.Color]::Orange
    $btnOnlySusp.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $btnOnlySusp.Add_Click({
        for ($i=0; $i -lt $clb.Items.Count; $i++) {
            $isSusp=($clb.Items[$i].ToString() -match "^\[!.")   # matchea [!!] y [! ]
            $clb.SetItemChecked($i,$isSusp)
            $pkg=($clb.Items[$i].ToString() -replace "^\[.{2,3}\]\s+","" -replace "\s*\[.*","").Trim()
            $checkState[$pkg]=$isSusp
        }
    })
    $win.Controls.Add($btnOnlySusp)

    # MODO TURBO
    $script:turboMode = $false
    $btnTurbo = New-Object Windows.Forms.Button
    $btnTurbo.Text="!! TURBO !!"; $btnTurbo.Location=New-Object System.Drawing.Point(341,$btnY)
    $btnTurbo.Size=New-Object System.Drawing.Size(105,28); $btnTurbo.FlatStyle="Flat"
    $btnTurbo.ForeColor=[System.Drawing.Color]::Red; $btnTurbo.BackColor=[System.Drawing.Color]::FromArgb(40,10,10)
    $btnTurbo.FlatAppearance.BorderColor=[System.Drawing.Color]::OrangeRed
    $btnTurbo.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $btnTurbo.Add_Click({
        $targets = @($allItems | Where-Object { $_.score -ge 5 } | Sort-Object { $_.score } -Descending)
        if ($targets.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No hay apps con score >= 5.","Turbo - sin targets",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }
        # Dialogo propio con lista scrollable
        $td = New-Object Windows.Forms.Form
        $td.Text = "!! TURBO - Confirmar eliminacion !!"; $td.ClientSize = New-Object System.Drawing.Size(560,420)
        $td.BackColor = [System.Drawing.Color]::FromArgb(18,18,18); $td.FormBorderStyle = "FixedDialog"
        $td.StartPosition = "CenterScreen"; $td.TopMost = $true

        $tdLbl = New-Object Windows.Forms.Label
        $tdLbl.Text = "  Se eliminaran $($targets.Count) apps con score >= 5 SIN confirmacion adicional:"
        $tdLbl.Location = New-Object System.Drawing.Point(0,10); $tdLbl.Size = New-Object System.Drawing.Size(560,20)
        $tdLbl.ForeColor = [System.Drawing.Color]::OrangeRed; $tdLbl.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
        $td.Controls.Add($tdLbl)

        $tdList = New-Object Windows.Forms.TextBox
        $tdList.Multiline = $true; $tdList.ReadOnly = $true; $tdList.ScrollBars = "Vertical"
        $tdList.Location = New-Object System.Drawing.Point(12,36); $tdList.Size = New-Object System.Drawing.Size(536,320)
        $tdList.BackColor = [System.Drawing.Color]::FromArgb(28,10,10); $tdList.ForeColor = [System.Drawing.Color]::OrangeRed
        $tdList.Font = New-Object System.Drawing.Font("Consolas",8)
        $nl = "`r`n"
        $lines = $targets | ForEach-Object {
            $permShort = if ($_.permFlags.Count -gt 0) { "  [" + (($_.permFlags | Select-Object -First 3) -join ",") + $(if($_.permFlags.Count -gt 3){"+..."}) + "]" } else {""}
            "  score:$($_.score.ToString().PadLeft(3))  $($_.pkg)$permShort"
        }
        $tdList.Text = ($lines -join $nl)
        $td.Controls.Add($tdList)

        $tdWarn = New-Object Windows.Forms.Label
        $tdWarn.Text = "  Esta accion es irreversible. Las apps de sistema se deshabilitaran, las de usuario se eliminaran."
        $tdWarn.Location = New-Object System.Drawing.Point(0,362); $tdWarn.Size = New-Object System.Drawing.Size(560,18)
        $tdWarn.ForeColor = [System.Drawing.Color]::FromArgb(160,80,80); $tdWarn.Font = New-Object System.Drawing.Font("Segoe UI",8)
        $td.Controls.Add($tdWarn)

        $tdOK = New-Object Windows.Forms.Button
        $tdOK.Text = "CONFIRMAR - ELIMINAR $($targets.Count) APPS"
        $tdOK.Location = New-Object System.Drawing.Point(12,385); $tdOK.Size = New-Object System.Drawing.Size(310,28)
        $tdOK.FlatStyle = "Flat"; $tdOK.ForeColor = [System.Drawing.Color]::White
        $tdOK.BackColor = [System.Drawing.Color]::FromArgb(120,20,20)
        $tdOK.FlatAppearance.BorderColor = [System.Drawing.Color]::OrangeRed
        $tdOK.Font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
        $tdOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $td.Controls.Add($tdOK)

        $tdCancel = New-Object Windows.Forms.Button
        $tdCancel.Text = "CANCELAR"; $tdCancel.Location = New-Object System.Drawing.Point(334,385)
        $tdCancel.Size = New-Object System.Drawing.Size(214,28); $tdCancel.FlatStyle = "Flat"
        $tdCancel.ForeColor = [System.Drawing.Color]::FromArgb(160,160,160)
        $tdCancel.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
        $tdCancel.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80,80,80)
        $tdCancel.Font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
        $tdCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $td.Controls.Add($tdCancel)

        $td.AcceptButton = $tdOK; $td.CancelButton = $tdCancel
        $res = $td.ShowDialog()
        if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $script:uninstallResult = $targets | ForEach-Object { $_.pkg }
        $script:turboMode = $true
        $win.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $win.Close()
    })
    $win.Controls.Add($btnTurbo)

    $script:uninstallResult = @()

    $btnUninstall = New-Object Windows.Forms.Button
    $btnUninstall.Text="DESINSTALAR SELECCIONADAS"; $btnUninstall.Location=New-Object System.Drawing.Point(454,$btnY)
    $btnUninstall.Size=New-Object System.Drawing.Size(228,28); $btnUninstall.FlatStyle="Flat"
    $btnUninstall.ForeColor=[System.Drawing.Color]::Lime; $btnUninstall.BackColor=[System.Drawing.Color]::FromArgb(10,40,10)
    $btnUninstall.FlatAppearance.BorderColor=[System.Drawing.Color]::Lime
    $btnUninstall.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $btnUninstall.Add_Click({
        $selected = @()
        for ($i=0; $i -lt $clb.Items.Count; $i++) {
            if ($clb.GetItemChecked($i)) {
                $selected += ($clb.Items[$i].ToString() -replace "^\[.{2,3}\]\s+","" -replace "\s*\[.*","").Trim()
            }
        }
        if ($selected.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No hay apps seleccionadas.","Sin seleccion",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Se desinstalaran $($selected.Count) app(s).`n`nConfirmar?",
            "Confirmar desinstalacion",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -ne "Yes") { return }
        $script:uninstallResult = $selected
        $win.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $win.Close()
    })
    $win.Controls.Add($btnUninstall)

    $btnClose = New-Object Windows.Forms.Button
    $btnClose.Text="CERRAR"; $btnClose.Location=New-Object System.Drawing.Point(690,$btnY)
    $btnClose.Size=New-Object System.Drawing.Size(116,28); $btnClose.FlatStyle="Flat"
    $btnClose.ForeColor=[System.Drawing.Color]::FromArgb(160,160,160); $btnClose.BackColor=[System.Drawing.Color]::FromArgb(35,35,35)
    $btnClose.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(80,80,80)
    $btnClose.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $btnClose.Add_Click({ $win.Close() })
    $win.Controls.Add($btnClose)

    $btn.Text = "REMOVER ADWARE"
    $win.ShowDialog() | Out-Null
    $btn.Enabled = $true; $btn.Text = "REMOVER ADWARE"

    if ($script:uninstallResult.Count -eq 0) { return }

    $Global:logAdb.Clear()
    AdbLog "=============================================="
    AdbLog "   DESINSTALACION EN BLOQUE  -  RNX TOOL PRO"
    AdbLog "   $(Get-Date -Format 'dd/MM/yyyy  HH:mm:ss')"
    if ($script:turboMode) { AdbLog "   !! MODO TURBO !!" }
    AdbLog "=============================================="
    AdbLog "[~] Apps a procesar: $($script:uninstallResult.Count)"
    AdbLog ""

    $cntOK = 0; $cntFail = 0
    foreach ($pkg in $script:uninstallResult) {
        AdbLog "[~] Procesando: $pkg"
        if ($appMap.ContainsKey($pkg) -and $appMap[$pkg].score -gt 0) {
            AdbLog "    Score: $($appMap[$pkg].score)  Permisos: $(($appMap[$pkg].permFlags -join ', '))"
        }
        try { & adb shell am force-stop $pkg 2>$null | Out-Null } catch {}
        try { & adb shell cmd appops set $pkg SYSTEM_ALERT_WINDOW deny 2>$null | Out-Null } catch {}
        try { & adb shell pm clear $pkg 2>$null | Out-Null } catch {}
        $r = ""
        try { $r = (& adb shell pm uninstall --user 0 $pkg 2>&1) -join "" } catch {}
        if ($r -imatch "Success|DELETE_SUCCEEDED") {
            AdbLog "[OK] Removida       : $pkg"; $cntOK++
        } else {
            $r2 = ""
            try { $r2 = (& adb shell pm disable-user --user 0 $pkg 2>&1) -join "" } catch {}
            if ($r2 -imatch "disabled|success") {
                AdbLog "[OK] Deshabilitada  : $pkg  (sistema)"; $cntOK++
            } else {
                AdbLog "[!!] Fallo           : $pkg  ->  $($r.Trim())"; $cntFail++
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    AdbLog ""
    AdbLog "=============================================="
    AdbLog "  RESUMEN DESINSTALACION"
    AdbLog "=============================================="
    AdbLog "  Procesadas    : $($script:uninstallResult.Count)"
    AdbLog "  Removidas OK  : $cntOK"
    AdbLog "  Fallidas      : $cntFail"
    AdbLog ""
    if ($cntOK -gt 0) { AdbLog "[OK] $cntOK apps eliminadas exitosamente." }
    if ($cntFail -gt 0) {
        AdbLog "[!]  $cntFail apps fallaron. Requieren root para remocion completa."
        AdbLog "[~]  Usa AUTOROOT MAGISK y repite."
    }
    AdbLog "[~]  Reinicia el dispositivo para aplicar los cambios."
    AdbLog "=============================================="

    $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  DESINSTALACION OK: $cntOK  |  $model"
})

$btnsA3[2].Add_Click({ AdbLog "[>] $($btnsA3[2].Text) : pendiente" })
$btnsA3[3].Add_Click({ AdbLog "[>] $($btnsA3[3].Text) : pendiente" })

# ---- CLONAR DISPOSITIVO (stub - futuro: adb backup full + transferencia) ----
# ---- INSTALAR MAGISK (seleccion v24 / v27 con autodeteccion por modelo) ----
$btnsA2[4].Add_Click({
    $btn = $btnsA2[4]

    $Global:logAdb.Clear()
    AdbLog "=============================================="
    AdbLog "   INSTALAR MAGISK  -  RNX TOOL PRO"
    AdbLog "   $(Get-Date -Format 'dd/MM/yyyy  HH:mm:ss')"
    AdbLog "=============================================="
    AdbLog ""

    # Verificar ADB
    if (-not (Check-ADB)) {
        AdbLog "[!] No hay dispositivo ADB conectado."
        AdbLog "    Habilita Depuracion USB y reconecta el equipo."
        return
    }

    # Leer modelo para autodeteccion de version
    $instModel  = (& adb shell getprop ro.product.model  2>$null).Trim()
    $instSerial = (& adb get-serialno 2>$null).Trim()
    AdbLog "[+] Dispositivo : $instModel  ($instSerial)"
    AdbLog ""
    [System.Windows.Forms.Application]::DoEvents()

    # Autodetectar si es modelo legacy (tabla de AUTOROOT)
    $isLegacyModel = $false
    foreach ($leg in $script:MAGISK_LEGACY_MODELS) {
        if ($instModel.Trim().ToUpper() -eq $leg.ToUpper()) { $isLegacyModel = $true; break }
    }
    $autoSelIdx = if ($isLegacyModel) { 0 } else { 1 }
    $autoLabel  = if ($isLegacyModel) { "v24 (legacy detectado: $instModel)" } else { "v27 (recomendado)" }
    AdbLog "[*] Autodeteccion  : Magisk $autoLabel"
    AdbLog ""

    # ---- Dropdown de version ----
    $dlgForm = New-Object Windows.Forms.Form
    $dlgForm.Text            = "Seleccionar version de Magisk"
    $dlgForm.ClientSize      = New-Object System.Drawing.Size(380, 175)
    $dlgForm.BackColor       = [System.Drawing.Color]::FromArgb(28,28,28)
    $dlgForm.FormBorderStyle = "FixedDialog"
    $dlgForm.StartPosition   = "CenterScreen"
    $dlgForm.MaximizeBox     = $false; $dlgForm.MinimizeBox = $false
    $dlgForm.TopMost         = $true

    $lblDev = New-Object Windows.Forms.Label
    $lblDev.Text      = "Dispositivo: $instModel"
    $lblDev.Location  = New-Object System.Drawing.Point(14, 12)
    $lblDev.Size      = New-Object System.Drawing.Size(352, 16)
    $lblDev.ForeColor = [System.Drawing.Color]::FromArgb(160,160,160)
    $lblDev.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
    $dlgForm.Controls.Add($lblDev)

    $lblSel = New-Object Windows.Forms.Label
    $lblSel.Text      = "Version de Magisk a instalar:"
    $lblSel.Location  = New-Object System.Drawing.Point(14, 34)
    $lblSel.Size      = New-Object System.Drawing.Size(352, 18)
    $lblSel.ForeColor = [System.Drawing.Color]::Cyan
    $lblSel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $dlgForm.Controls.Add($lblSel)

    $cmbVer = New-Object Windows.Forms.ComboBox
    $cmbVer.Location      = New-Object System.Drawing.Point(14, 58)
    $cmbVer.Size          = New-Object System.Drawing.Size(352, 26)
    $cmbVer.DropDownStyle = "DropDownList"
    $cmbVer.BackColor     = [System.Drawing.Color]::FromArgb(45,45,45)
    $cmbVer.ForeColor     = [System.Drawing.Color]::Cyan
    $cmbVer.Font          = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    @(
        "Magisk v24  (legacy - A21s / A13 / A51 5G / kernel antiguo)",
        "Magisk v27  (ultima version - recomendado)"
    ) | ForEach-Object { $cmbVer.Items.Add($_) | Out-Null }
    $cmbVer.SelectedIndex = $autoSelIdx
    $dlgForm.Controls.Add($cmbVer)

    if ($isLegacyModel) {
        $lblNote = New-Object Windows.Forms.Label
        $lblNote.Text      = "  Modelo legacy detectado -> v24 preseleccionada"
        $lblNote.Location  = New-Object System.Drawing.Point(14, 84)
        $lblNote.Size      = New-Object System.Drawing.Size(352, 15)
        $lblNote.ForeColor = [System.Drawing.Color]::FromArgb(255,180,0)
        $lblNote.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)
        $dlgForm.Controls.Add($lblNote)
    }

    $btnOk = New-Object Windows.Forms.Button
    $btnOk.Text      = "INSTALAR"
    $btnOk.Location  = New-Object System.Drawing.Point(14, 128)
    $btnOk.Size      = New-Object System.Drawing.Size(170, 34)
    $btnOk.FlatStyle = "Flat"
    $btnOk.ForeColor = [System.Drawing.Color]::Cyan
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(20,40,55)
    $btnOk.FlatAppearance.BorderColor = [System.Drawing.Color]::Cyan
    $btnOk.Font      = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlgForm.Controls.Add($btnOk)

    $btnCan = New-Object Windows.Forms.Button
    $btnCan.Text      = "CANCELAR"
    $btnCan.Location  = New-Object System.Drawing.Point(196, 128)
    $btnCan.Size      = New-Object System.Drawing.Size(170, 34)
    $btnCan.FlatStyle = "Flat"
    $btnCan.ForeColor = [System.Drawing.Color]::Gray
    $btnCan.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
    $btnCan.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
    $btnCan.Font      = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $btnCan.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlgForm.Controls.Add($btnCan)

    $dlgForm.AcceptButton = $btnOk; $dlgForm.CancelButton = $btnCan
    $dlgResult = $dlgForm.ShowDialog()

    if ($dlgResult -ne [System.Windows.Forms.DialogResult]::OK) {
        AdbLog "[~] Instalacion cancelada."; return
    }

    $selIdx   = $cmbVer.SelectedIndex
    $verLabel = if ($selIdx -eq 0) { "v24" } else { "v27" }
    $apkName  = if ($selIdx -eq 0) { "magisk24.apk" } else { "magisk27.apk" }
    AdbLog "[+] Version elegida : Magisk $verLabel"
    AdbLog "[+] APK             : $apkName"
    AdbLog ""

    # Buscar APK en rutas predeterminadas
    $apkCandidates = @(
        (Join-Path $script:TOOLS_DIR $apkName),
        (Join-Path $script:SCRIPT_ROOT $apkName),
        (Join-Path $script:SCRIPT_ROOT "tools\$apkName"),
        (Join-Path $script:SCRIPT_ROOT "modules\$apkName")
    )
    $apkPath = $null
    foreach ($c in $apkCandidates) {
        if (Test-Path $c -EA SilentlyContinue) { $apkPath = $c; break }
    }

    if (-not $apkPath) {
        AdbLog "[~] $apkName no encontrado en rutas predeterminadas."
        AdbLog "[~] Selecciona manualmente la APK de Magisk $verLabel ..."
        $fdApk = New-Object System.Windows.Forms.OpenFileDialog
        $fdApk.Filter = "APK de Magisk (*.apk)|*.apk|Todos|*.*"
        $fdApk.Title  = "Selecciona Magisk $verLabel APK"
        if ($fdApk.ShowDialog() -ne "OK") { AdbLog "[~] Cancelado."; return }
        $apkPath = $fdApk.FileName
    }

    AdbLog "[+] Ruta APK : $apkPath"
    AdbLog "[~] Instalando via ADB (adb install -r)..."
    AdbLog ""

    $btn.Enabled = $false; $btn.Text = "INSTALANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = "adb"
        $psi.Arguments              = "install -r `"$apkPath`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi; $p.Start() | Out-Null
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $combined = ($out + "`n" + $err).Trim()
        foreach ($line in ($combined -split "`n")) {
            $l = $line.Trim(); if ($l) { AdbLog "  $l" }
        }
        AdbLog ""
        if ($combined -imatch "Success") {
            AdbLog "[OK] Magisk $verLabel instalado correctamente."
            AdbLog "[~] Abre la app Magisk en el equipo."
            AdbLog "[~] Si es primera instalacion, toca 'Instalar' para"
            AdbLog "[~] completar el setup al sistema de archivos."
            $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  Magisk $verLabel instalado  |  $instModel"
        } elseif ($combined -imatch "INSTALL_FAILED") {
            AdbLog "[!] Instalacion fallida - revisa el log."
        } else {
            AdbLog "[~] Proceso finalizado (cod: $($p.ExitCode))"
        }
    } catch { AdbLog "[!] Error: $_" }
    finally { $btn.Enabled = $true; $btn.Text = "INSTALAR MAGISK" }
})

# ---- RESTAURAR BACKUP (stub - futuro: selector .adb + adb restore) ----
$btnsA2[5].Add_Click({
    $btn = $btnsA2[5]
    $btn.Enabled = $false; $btn.Text = "EJECUTANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    $Global:logAdb.Clear()
    AdbLog "=============================================="
    AdbLog "   RESTAURAR BACKUP  -  RNX TOOL PRO"
    AdbLog "   $(Get-Date -Format 'dd/MM/yyyy  HH:mm:ss')"
    AdbLog "=============================================="
    AdbLog ""
    AdbLog "[~] Funcion en construccion."
    AdbLog "[~] Planificado: selector de archivo .adb y"
    AdbLog "[~] restauracion automatica via adb restore."
    AdbLog ""
    if (-not (Check-ADB)) { $btn.Enabled=$true; $btn.Text="RESTAURAR BACKUP"; return }
    $model  = (& adb shell getprop ro.product.model 2>$null).Trim()
    $serial = (& adb get-serialno 2>$null).Trim()
    AdbLog "[+] Dispositivo destino: $model  ($serial)"
    AdbLog ""
    AdbLog "[i] Pasos planificados:"
    AdbLog "    1. Seleccion del archivo .adb de backup"
    AdbLog "    2. Confirmacion en el dispositivo"
    AdbLog "    3. Restauracion de apps + datos + configuracion"
    AdbLog "[~] PROXIMAMENTE en RNX TOOL PRO."
    AdbLog "=============================================="
    $btn.Enabled=$true; $btn.Text="RESTAURAR BACKUP"
})

