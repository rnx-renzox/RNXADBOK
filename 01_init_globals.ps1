[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::SystemAware) } catch {}

$script:LAST_SERIAL         = ""
$script:ADB_PROP_CACHE      = ""
$script:ADB_PROP_CACHE_TIME = [DateTime]::MinValue
$script:TEMP_EXTRACT        = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "RNX_FLASH_TEMP")

# Resolver raiz del script y carpeta tools UNA SOLA VEZ al arrancar.
# IMPORTANTE con dot-sourcing: $PSScriptRoot aqui apunta a la carpeta del MODULO (modules\),
# no a la raiz del proyecto. Por eso el archivo principal (RNX_TOOL_PRO.ps1) define
# $Global:RNX_ROOT antes de hacer los dot-source, y ese valor se usa aqui.
$script:SCRIPT_ROOT = if ($Global:RNX_ROOT -and (Test-Path $Global:RNX_ROOT)) {
    $Global:RNX_ROOT
} elseif ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
    # Fallback: si se ejecuta el modulo directamente o el main no definio RNX_ROOT
    # subir un nivel desde modules\ hacia la raiz
    Split-Path $PSScriptRoot -Parent
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path $MyInvocation.MyCommand.Path -Parent
} else {
    [System.IO.Directory]::GetCurrentDirectory()
}
$script:TOOLS_DIR   = Join-Path $script:SCRIPT_ROOT "tools"
$script:MODULES_DIR = Join-Path $script:TOOLS_DIR   "modules"

# Mapa completo particion -> flag heimdall
$script:PART_MAP = @{
    "boot"="BOOT"; "recovery"="RECOVERY"; "system"="SYSTEM"; "vendor"="VENDOR"
    "cache"="CACHE"; "userdata"="USERDATA"; "super"="SUPER"
    "vbmeta"="VBMETA"; "vbmeta_system"="VBMETA_SYSTEM"; "vbmeta_vendor"="VBMETA_VENDOR"
    "dtbo"="DTBO"; "odm"="ODM"; "product"="PRODUCT"; "system_ext"="SYSTEM_EXT"
    "metadata"="METADATA"; "param"="PARAM"; "up_param"="UP_PARAM"
    "keydata"="KEYDATA"; "keystorage"="KEYSTORAGE"; "sboot"="SBOOT"; "tzsw"="TZSW"
    "modem"="MODEM"; "radio"="MODEM"; "efs"="EFS"; "misc"="MISC"
    "optics"="OPTICS"; "prism"="PRISM"; "dsp"="DSP"; "bluetooth"="BLUETOOTH"
    "tz"="TZ"; "hyp"="HYP"; "abl"="ABL"; "xbl"="XBL"; "logo"="LOGO"
    "splash"="SPLASH"; "NON-HLOS"="MODEM"; "apnhlos"="APNHLOS"
}

#==========================================================================
# FUNCIONES BASICAS
#==========================================================================
function Get-TechnicalCPU {
    $plt = (adb shell getprop ro.board.platform 2>$null).Trim()
    $soc = (adb shell getprop ro.soc.model     2>$null).Trim()
    if ($soc) { return $soc.ToUpper() }
    switch -Wildcard ($plt) {
        "mt6833" { return "MT6833 (Dimensity 700)" }
        "mt6769" { return "MT6769 (Helio G85)" }
        "mt6768" { return "MT6768 (Helio G85)" }
        "mt6765" { return "MT6765 (Helio G85)" }
        "saipan" { return "MT6833 (MOTO G50)" }
        "msm*"   { return "QUALCOMM SNAPDRAGON" }
        "mt*"    { return "MEDIATEK ($plt)".ToUpper() }
        default  { return if ($plt) { $plt.ToUpper() } else { "DESCONOCIDO" } }
    }
}

# Flag global: TRUE mientras un Job ADB esta corriendo (evita llamadas solapadas)
$script:ADB_JOB_RUNNING = $false
$script:ADB_JOB         = $null

# Limpia el output de ADB quitando mensajes del daemon y lineas vacias
function Clean-AdbOutput($raw) {
    if (-not $raw) { return "" }
    $lines = ($raw -join "`n") -split "`n"
    $clean = $lines | Where-Object {
        $_ -notmatch "^\s*\*\s*(daemon|adb server)" -and
        $_ -notmatch "starting it now" -and
        $_ -notmatch "successfully started" -and
        $_ -notmatch "^List of devices" -and
        $_ -notmatch "^\s*$"
    }
    return ($clean -join "").Trim()
}

function Get-DeepDeviceStatus {
    # --- Si hay un job previo corriendo, recoger resultado si termino ---
    if ($script:ADB_JOB_RUNNING -and $script:ADB_JOB) {
        $state = $script:ADB_JOB.State
        if ($state -eq "Completed" -or $state -eq "Failed") {
            $script:ADB_JOB_RUNNING = $false
            if ($state -eq "Completed") {
                try {
                    $res = Receive-Job -Job $script:ADB_JOB -ErrorAction SilentlyContinue
                    # $res es un hashtable serializado como string por el job
                    # Los jobs PS devuelven objetos  -  accedemos por nombre
                    if ($res -and $res.serial) {
                        $s = $res.serial
                        if ($s -and $s -ne $script:LAST_SERIAL) {
                            $script:LAST_SERIAL = $s
                            $Global:lblADB.Text      = "ADB         : EN LINEA"
                            $Global:lblADB.ForeColor = [System.Drawing.Color]::Lime
                            $Global:lblDisp.Text     = "DISPOSITIVO : $($res.mfr)"
                            $Global:lblModel.Text    = "MODELO      : $($res.model)"
                            $Global:lblSerial.Text   = "SERIAL      : $s"
                            $Global:lblCPU.Text      = "CPU         : $($res.cpu)"
                            $Global:lblChip.Text     = "CHIPSET     : $($res.chip)"
                            $Global:lblRoot.Text     = "ROOT        : $($res.root)"
                            $Global:lblRoot.ForeColor= if ($res.root -eq "SI") {[System.Drawing.Color]::Lime} else {[System.Drawing.Color]::Red}
                            $Global:lblModo.Text     = "MODO        : ADB"
                            $Global:lblModo.ForeColor= [System.Drawing.Color]::Cyan
                            $Global:lblFRP.Text      = "FRP         : $($res.frp)"
                            $Global:lblFRP.ForeColor = if ($res.frp -eq "PRESENT") {[System.Drawing.Color]::Red} else {[System.Drawing.Color]::Lime}
                            $Global:lblStorage.Text  = "STORAGE     : $($res.storage)"
                            $Global:lblStorage.ForeColor = [System.Drawing.Color]::LightGray
                            $Global:lblStatus.Text   = "  RNX TOOL PRO v2.3  |  CONECTADO  |  $($res.model)"
                        }
                    } elseif ($script:LAST_SERIAL -ne "") {
                        # Antes habia equipo, ahora no responde -> desconectado
                        $script:LAST_SERIAL = ""
                        $Global:lblADB.Text      = "ADB         : DESCONECTADO"
                        $Global:lblADB.ForeColor = [System.Drawing.Color]::Orange
                        foreach ($l in @($Global:lblModel,$Global:lblDisp,$Global:lblCPU,
                                         $Global:lblSerial,$Global:lblChip,$Global:lblRoot,
                                         $Global:lblModo,$Global:lblFRP,$Global:lblStorage)) {
                            $l.Text = ($l.Text -split ":")[0] + ": -"
                            $l.ForeColor = [System.Drawing.Color]::LightGray
                        }
                        $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  ADB LISTO  |  Esperando dispositivo..."
                    }
                } catch {}
            }
            Remove-Job -Job $script:ADB_JOB -Force -ErrorAction SilentlyContinue
            $script:ADB_JOB = $null
        }
        # Job aun corriendo -> no lanzar otro, volver sin bloquear UI
        return
    }

    # --- Lanzar nuevo Job ADB en background (no bloquea la UI) ---
    $script:ADB_JOB_RUNNING = $true
    $script:ADB_JOB = Start-Job -ScriptBlock {
        # Funcion limpieza dentro del job
        function CL($raw) {
            if (-not $raw) { return "" }
            $lines = ($raw -join "`n") -split "`n"
            ($lines | Where-Object {
                $_ -notmatch "^\s*\*\s*(daemon|adb server)" -and
                $_ -notmatch "starting it now|successfully started|^List of devices|^\s*$"
            } | ForEach-Object { $_.Trim() }) -join "" | ForEach-Object { $_.Trim() }
        }

        # Revision rapida: chequear adb devices primero (sin bloqueo largo)
        $devList = (& adb devices 2>$null) -join "`n"
        $hasDevice = $devList -match "`tdevice"
        if (-not $hasDevice) {
            return @{serial=""; mfr=""; model=""; cpu=""; chip=""; root="NO"; frp=""; storage=""}
        }

        $s   = CL (& adb shell getprop ro.serialno           2>$null)
        if (-not $s) { return @{serial=""; mfr=""; model=""; cpu=""; chip=""; root="NO"; frp=""; storage=""} }

        $mfr = CL (& adb shell getprop ro.product.manufacturer 2>$null)
        $mdl = CL (& adb shell getprop ro.product.model        2>$null)
        $dev = CL (& adb shell getprop ro.product.device       2>$null)
        $mod = CL (& adb shell getprop ro.product.mod_device   2>$null)
        $plt = CL (& adb shell getprop ro.board.platform       2>$null)
        $soc = CL (& adb shell getprop ro.soc.model            2>$null)
        $frp = CL (& adb shell getprop ro.frp.pst              2>$null)
        $rid = CL (& adb shell "su -c id"                      2>$null)

        # Deteccion de storage multi-señal (solo /sys/class/ufs falla en muchos UFS)
        # Señal 1: nodo kernel UFS
        $ufsNode  = CL (& adb shell "ls /sys/class/ufs 2>/dev/null" 2>$null)
        # Señal 2: dispositivo de bloque UFS directo
        $ufsDev   = CL (& adb shell "ls /dev/block/sda 2>/dev/null" 2>$null)
        # Señal 3: propiedad del sistema (Samsung/Xiaomi exponen esto)
        $ufsType  = CL (& adb shell "getprop ro.boot.storage_type 2>/dev/null" 2>$null)
        # Señal 4: nombre del bloque mmcblk0 indica eMMC; su ausencia + sda indica UFS
        $mmcBlk   = CL (& adb shell "ls /dev/block/mmcblk0 2>/dev/null" 2>$null)
        # Señal 5: driver UFS en sysfs extendido
        $ufsHost  = CL (& adb shell "ls /sys/bus/platform/drivers/ufshcd 2>/dev/null" 2>$null)

        $isUFS = ($ufsNode -or $ufsDev -or $ufsHost -or
                  ($ufsType -imatch "ufs") -or
                  (-not $mmcBlk -and $ufsDev))
        $storageStr = if ($isUFS) { "UFS" } else { "eMMC" }

        $devId   = if ($mod -and $mod -ne $dev) { $mod.ToUpper() } else { $dev.ToUpper() }
        $model   = if ($devId -and $devId -ne $mdl.ToUpper()) { "$mdl  [$devId]" } else { $mdl }

        $cpuName = if ($soc) { $soc.ToUpper() }
                   elseif ($plt -match "mt6833") { "MT6833 (Dimensity 700)" }
                   elseif ($plt -match "mt6769|mt6768") { "MT6769 (Helio G85)" }
                   elseif ($plt -match "mt6765") { "MT6765 (Helio G85)" }
                   elseif ($plt -match "^msm")   { "QUALCOMM SNAPDRAGON" }
                   elseif ($plt -match "^mt")    { "MEDIATEK ($plt)".ToUpper() }
                   elseif ($plt)                 { $plt.ToUpper() }
                   else                          { "DESCONOCIDO" }

        $chip    = if ($cpuName -match "MT|MTK|MEDIATEK|Dimensity|Helio") { "MEDIATEK" }
                   elseif ($cpuName -match "EXYNOS") { "EXYNOS" }
                   else { "QUALCOMM" }

        return @{
            serial  = $s
            mfr     = $mfr.ToUpper()
            model   = $model
            cpu     = $cpuName
            chip    = $chip
            root    = if ($rid -match "uid=0") { "SI" } else { "NO" }
            frp     = if ($frp) { "PRESENT" } else { "NOT SET" }
            storage = $storageStr
        }
    }
}


