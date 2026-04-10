

#==========================================================================
# TAB 1: SAMSUNG FLASHER
#==========================================================================
$tabOdin           = New-Object Windows.Forms.TabPage
$tabOdin.Text      = "SAMSUNG FLASHER"
$tabOdin.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$tabs.TabPages.Add($tabOdin)

$script:BL_FILE  = ""; $script:AP_FILE  = ""; $script:CP_FILE  = ""
$script:CSC_FILE = ""; $script:PIT_FILE = ""; $script:AP_PARTS = @()
$script:BL_IMGS  = @(); $script:AP_IMGS  = @()
$script:CP_IMGS  = @(); $script:CSC_IMGS = @()

# LOG HELPERS — definidos en 09_logger.ps1 (OdinLog, AdbLog, GenLog, FbLog)

#==========================================================================
# MOTORES HEIMDALL  (3 versiones)
#==========================================================================
function Invoke-Heimdall($hargs) {
    try {
        $psi=New-Object System.Diagnostics.ProcessStartInfo; $psi.FileName="heimdall"; $psi.Arguments=$hargs
        $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
        $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
        $p=New-Object System.Diagnostics.Process; $p.StartInfo=$psi; $p.Start()|Out-Null
        $out=$p.StandardOutput.ReadToEnd(); $p.WaitForExit(); return $out
    } catch { return "" }
}
function Invoke-HeimdallAdv($hargs) {
    try {
        $psi=New-Object System.Diagnostics.ProcessStartInfo; $psi.FileName="heimdall"; $psi.Arguments=$hargs
        $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
        $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
        $p=New-Object System.Diagnostics.Process; $p.StartInfo=$psi; $p.Start()|Out-Null
        $out=$p.StandardOutput.ReadToEnd(); $err=$p.StandardError.ReadToEnd()
        $p.WaitForExit(); return $out+$err
    } catch { return "" }
}
function Invoke-HeimdallLive($hargs) {
    # Lee stdout Y stderr en paralelo con eventos asincronos.
    # Heimdall escribe info critica (Target/Binary/Status) en stderr
    # durante el handshake  -  antes de que empiece el flash.
    # Leer stderr solo al final causa perdida de esos datos.
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = "heimdall"
        $psi.Arguments              = $hargs
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi

        # Handler asincrono para STDERR  -  captura handshake info en tiempo real
        $errLines = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        $p.add_ErrorDataReceived({
            param($sender, $e)
            if ($e.Data -ne $null) { $errLines.Enqueue($e.Data) }
        })

        $p.Start() | Out-Null
        $p.BeginErrorReadLine()   # activa el evento asincrono para stderr

        # Leer stdout linea a linea en el hilo principal
        while (-not $p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            if ($line) { OdinLog "  $line" }

            # Vaciar la cola de stderr mientras leemos stdout
            $eq = ""
            while ($errLines.TryDequeue([ref]$eq)) {
                if ($eq.Trim()) { OdinLog "  [INFO] $eq" }
            }
        }

        $p.WaitForExit()

        # Vaciar cualquier linea de stderr que quedo en la cola
        $eq = ""
        while ($errLines.TryDequeue([ref]$eq)) {
            if ($eq.Trim()) { OdinLog "  [INFO] $eq" }
        }

        return $p.ExitCode
    } catch { return -1 }
}

#==========================================================================
# DETECCION MULTI-CPU v2.3  -  WMI-FIRST + PnP + FriendlyName + COM
#
# VID/PID completo de referencia:
#   VID_04E8 = Samsung Electronics
#     PID_685D = Exynos DL Mode (S8/S9/S10/A50/A51/A52/Note8/Note9...)
#     PID_685E = Exynos DL Mode variante B (A30/A20/M20/M30...)
#     PID_6860 = Exynos DL Mode (S20/S21/Note20/A53/A33/A72/M52...)
#     PID_6861 = Exynos DL Mode variante (A52s/A73/Galaxy Z...)
#     PID_6863 = Exynos DL Mode (S22 Exynos 2200  -  protocolo v4 parcial)
#     PID_D001 = Qualcomm HS-USB QDLoader 9008 (EDL mode)
#     PID_6601 = Qualcomm DL Mode via Samsung driver (A52 4G/5G, A71, A72...)
#     PID_685B = Qualcomm DL Mode variante (A50s/A51/A70/A71...)
#     PID_6877 = Samsung generico DL Mode (modelos budget Snapdragon)
#   VID_0E8D = MediaTek genuino
#     PID_0003 = PreLoader DL Mode (A04, A04s, M22, M32, A13 MTK...)
#     PID_2000 = BROM DL Mode MediaTek
#   VID_2717 = Spreadtrum/UNISOC (Galaxy A03 core, algunos M)
#   VID_0FCE = Sony (ignorar)
#   VID_1004 = LGE (ignorar)
#==========================================================================
function Get-SamsungCPUInfo {
    $r = @{
        CPU      = "UNKNOWN"
        MODE     = "NONE"
        PORT     = ""
        USB_NAME = ""
        VID      = ""
        USBPID   = ""
        HEIMDALL = $false   # true solo si heimdall detect confirma
        PROTO    = "v3"     # v3=Heimdall-compatible / v4=moderno / MTK=no-heimdall
    }

    # -- PASO 1: WMI Win32_PnPEntity  -  fuente mas confiable, incluye
    #   dispositivos sin driver instalado (Status=Unknown/Error)
    #   Esto detecta el equipo ANTES que Get-PnpDevice en muchos casos
    # -----------------------------------------------------------------
    $wmiDevs = @()
    try {
        $wmiDevs = Get-WmiObject Win32_PnPEntity -ErrorAction SilentlyContinue |
                   Where-Object {
                       $_.DeviceID -imatch "VID_04E8|VID_0E8D|VID_2717" -or
                       $_.Name     -imatch "Samsung|MediaTek|PreLoader|SPRD|Spreadtrum|Download Mode"
                   }
    } catch {}

    foreach ($d in $wmiDevs) {
        $iid = $d.DeviceID
        $fn  = if ($d.Name)        { $d.Name }        else { "" }
        $desc= if ($d.Description) { $d.Description } else { "" }
        $combined = "$fn $desc"

        # MediaTek (VID_0E8D)  -  no compatible con Heimdall
        if ($iid -imatch "VID_0E8D") {
            $r.CPU = "MTK"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "MTK"
            $r.VID = "0E8D"; $r.USB_NAME = $fn
            if ($iid -imatch "PID_([0-9A-F]{4})") { $r.USBPID = $Matches[1] }
            break
        }
        # Spreadtrum/UNISOC  -  no compatible con Heimdall
        if ($iid -imatch "VID_2717") {
            $r.CPU = "SPD/UNISOC"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "MTK"
            $r.VID = "2717"; $r.USB_NAME = $fn; break
        }
        # Samsung VID_04E8
        if ($iid -imatch "VID_04E8") {
            $r.VID = "04E8"; $r.USB_NAME = $fn
            if ($iid -imatch "PID_([0-9A-F]{4})") { $r.USBPID = $Matches[1] }
            $usbpidVal = $r.USBPID.ToUpper()

            # Qualcomm EDL  -  HS-USB QDLoader 9008
            if ($usbpidVal -eq "D001") {
                $r.CPU = "QUALCOMM"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "v3"; break
            }
            # Qualcomm DL Mode via Samsung driver
            if ($usbpidVal -match "^(6601|685B|6877)$") {
                $r.CPU = "QUALCOMM"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "v3"; break
            }
            # Exynos DL Mode  -  totalmente compatibles con Heimdall v3
            if ($usbpidVal -match "^(685D|685E|6860|6861)$") {
                $r.CPU = "EXYNOS"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "v3"; break
            }
            # Exynos DL Mode S22  -  protocolo v4 parcial (Heimdall inestable)
            if ($usbpidVal -match "^(6863|6864)$") {
                $r.CPU = "EXYNOS"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "v4"; break
            }
            # Fallback por nombre si PID no identificado
            if ($combined -imatch "Download|DL Mode") { $r.MODE = "DOWNLOAD_MODE" }
            if ($combined -imatch "Exynos")   { $r.CPU = "EXYNOS" }
            if ($combined -imatch "Qualcomm") { $r.CPU = "QUALCOMM" }
        }
        # Sin VID reconocido pero nombre sugiere Samsung DL
        if ($combined -imatch "MediaTek|PreLoader") {
            if ($r.CPU -eq "UNKNOWN") { $r.CPU = "MTK"; $r.PROTO = "MTK"; $r.USB_NAME = $fn }
        }
        if ($combined -imatch "Spreadtrum|SPRD") {
            if ($r.CPU -eq "UNKNOWN") { $r.CPU = "SPD/UNISOC"; $r.PROTO = "MTK"; $r.USB_NAME = $fn }
        }
    }

    # -- PASO 2: Get-PnpDevice como segunda fuente (complementa WMI)
    #   Captura dispositivos que WMI puede omitir por permisos
    # -----------------------------------------------------------------
    if ($r.CPU -eq "UNKNOWN" -or $r.MODE -eq "NONE") {
        try {
            $pnp = Get-PnpDevice -ErrorAction SilentlyContinue |
                   Where-Object { $_.Status -in @("OK","Error","Unknown","Degraded") }
            foreach ($d in $pnp) {
                $fn  = "$($d.FriendlyName)"
                $iid = "$($d.InstanceId)"
                if (-not $iid) { continue }

                if ($iid -imatch "VID_0E8D" -and $r.CPU -eq "UNKNOWN") {
                    $r.CPU = "MTK"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "MTK"
                    $r.VID = "0E8D"; $r.USB_NAME = $fn
                    if ($iid -imatch "PID_([0-9A-F]{4})") { $r.USBPID = $Matches[1] }
                }
                elseif ($iid -imatch "VID_2717" -and $r.CPU -eq "UNKNOWN") {
                    $r.CPU = "SPD/UNISOC"; $r.MODE = "DOWNLOAD_MODE"; $r.PROTO = "MTK"
                    $r.VID = "2717"; $r.USB_NAME = $fn
                }
                elseif ($iid -imatch "VID_04E8") {
                    if ($r.VID -eq "") { $r.VID = "04E8"; $r.USB_NAME = $fn }
                    if ($iid -imatch "PID_([0-9A-F]{4})" -and $r.USBPID -eq "") { $r.USBPID = $Matches[1] }
                    $usbpidVal = if ($r.USBPID) { $r.USBPID.ToUpper() } else { "" }
                    if ($usbpidVal -eq "D001"                     -and $r.CPU -eq "UNKNOWN") { $r.CPU="QUALCOMM"; $r.MODE="DOWNLOAD_MODE"; $r.PROTO="v3" }
                    elseif ($usbpidVal -match "^(6601|685B|6877)$" -and $r.CPU -eq "UNKNOWN") { $r.CPU="QUALCOMM"; $r.MODE="DOWNLOAD_MODE"; $r.PROTO="v3" }
                    elseif ($usbpidVal -match "^(685D|685E|6860|6861)$" -and $r.CPU -eq "UNKNOWN") { $r.CPU="EXYNOS"; $r.MODE="DOWNLOAD_MODE"; $r.PROTO="v3" }
                    elseif ($usbpidVal -match "^(6863|6864)$"      -and $r.CPU -eq "UNKNOWN") { $r.CPU="EXYNOS"; $r.MODE="DOWNLOAD_MODE"; $r.PROTO="v4" }
                    elseif ($fn -imatch "Download|DL")  { if ($r.MODE -eq "NONE") { $r.MODE="DOWNLOAD_MODE" } }
                    elseif ($fn -imatch "Exynos")       { if ($r.CPU -eq "UNKNOWN") { $r.CPU="EXYNOS" } }
                    elseif ($fn -imatch "Qualcomm")     { if ($r.CPU -eq "UNKNOWN") { $r.CPU="QUALCOMM" } }
                }
                elseif ($fn -imatch "MediaTek|PreLoader" -and $r.CPU -eq "UNKNOWN") {
                    $r.CPU = "MTK"; $r.PROTO = "MTK"; $r.USB_NAME = $fn
                    $r.MODE = "DOWNLOAD_MODE"
                }
                elseif ($fn -imatch "Spreadtrum|SPRD" -and $r.CPU -eq "UNKNOWN") {
                    $r.CPU = "SPD/UNISOC"; $r.PROTO = "MTK"; $r.USB_NAME = $fn
                    $r.MODE = "DOWNLOAD_MODE"
                }
            }
        } catch {}
    }

    # -- PASO 3: Heimdall detect  -  SOLO como confirmacion adicional
    #   Si WMI/PnP ya confirmo DL Mode, no es obligatorio que heimdall responda.
    #   Si heimdall dice "Device detected" tambien marcamos modo.
    #   NOTA: en MTK y v4 Heimdall devuelve error aunque el equipo este conectado.
    # -----------------------------------------------------------------
    try {
        $hdet = Invoke-HeimdallAdv "detect"
        if ($hdet -imatch "Device detected") {
            $r.HEIMDALL = $true
            if ($r.MODE -eq "NONE") { $r.MODE = "DOWNLOAD_MODE" }
        }
    } catch {}

    # Si detectamos VID_04E8 sin PID reconocido y heimdall confirma,
    # es un Samsung v3 generico (Qualcomm budget o Exynos no listado)
    if ($r.HEIMDALL -and $r.CPU -eq "UNKNOWN" -and $r.VID -eq "04E8") {
        $r.CPU = "SAMSUNG-GENERICO"
    }

    # -- PASO 4: COM port scan (para protocolo Odin handshake manual)
    # -----------------------------------------------------------------
    try {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames()
        foreach ($pt in $ports) {
            try {
                $sp = New-Object System.IO.Ports.SerialPort $pt, 115200
                $sp.ReadTimeout = 300; $sp.WriteTimeout = 300; $sp.Open()
                Start-Sleep -Milliseconds 150
                if ($sp.IsOpen) { $r.PORT = $pt; $sp.Close() }
            } catch {}
        }
    } catch {}

    return $r
}

#==========================================================================
# PARSERS FIRMWARE
#==========================================================================
function Get-APPartitions($file) {
    $parts=@(); if (-not (Test-Path $file)) { return $parts }
    try { $list=tar -tf $file 2>$null; foreach ($p in $list) { if ($p -match "\.img$") { $parts+=$p.Trim() } } } catch {}
    return $parts
}
function Get-ParamBinInfo($file) {
    $r=@{MODEL="";FRP="UNKNOWN";KG="UNKNOWN";OEM="UNKNOWN"}
    if (-not (Test-Path $file)) { return $r }
    $data=[System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($file))
    if ($data -match "SM-[A-Z0-9]+") { $r.MODEL=$Matches[0] }
    if ($data -match "FRP") { $r.FRP="PRESENT" }; if ($data -match "KG") { $r.KG="LOCKED" }; if ($data -match "OEM") { $r.OEM="ON" }
    return $r
}
function Get-SbootInfo($file) {
    $r=@{SECURE="UNKNOWN";BOOT="UNKNOWN"}
    if (-not (Test-Path $file)) { return $r }
    $data=[System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($file))
    if ($data -match "SECURE") { $r.SECURE="ENABLED" }; if ($data -match "SAMSUNG") { $r.BOOT="SAMSUNG" }
    return $r
}
function Get-BinaryFromBuild($build) {
    if (-not $build -or $build -eq "UNKNOWN") { return "DESCONOCIDO" }
    try {
        if ($build -match "U(\d)") { return $Matches[1] }
        $len=$build.Length
        if ($len -ge 5) {
            $char=$build.Substring($len-5,1)
            switch ($char) { "A"{return "A (10)"}"B"{return "B (11)"}"C"{return "C (12)"}"D"{return "D (13)"}"E"{return "E (14)"}"F"{return "F (15)"}default{return $char} }
        }
    } catch {}; return "?"
}
function Get-CSCDecoded($code) {
    switch ($code) {
        "PET"{return "PERU / ENTEL"}        "PCT"{return "PERU / CLARO"}
        "PEO"{return "PERU / MOVISTAR"}     "PEP"{return "PERU / BITEL"}
        "TPA"{return "PANAMA / OPEN"}       "GTO"{return "GUATEMALA / OPEN"}
        "ARO"{return "ARGENTINA / OPEN"}    "COO"{return "COLOMBIA / OPEN"}
        "CHO"{return "CHILE / OPEN"}        "CHL"{return "CHILE / CLARO"}
        "MXO"{return "MEXICO / OPEN"}       "VTV"{return "VENEZUELA / OPEN"}
        "ZTO"{return "BRASIL / TIM"}        "ZTM"{return "BRASIL / CLARO"}
        "ZTA"{return "BRASIL / OI"}         "ZTB"{return "BRASIL / VIVO"}
        "TCE"{return "ECUADOR / OPEN"}      "BOL"{return "BOLIVIA / OPEN"}
        "DBT"{return "ALEMANIA / OPEN"}     "XEF"{return "FRANCIA / OPEN"}
        "BTU"{return "UK / OPEN"}           "XEV"{return "RUSIA / OPEN"}
        "XEO"{return "EUROPA / OPEN"}       "XSP"{return "SINGAPUR / OPEN"}
        "XTC"{return "TAILANDIA / OPEN"}    "XID"{return "INDONESIA / OPEN"}
        "XME"{return "MEDIO ESTE / OPEN"}   "TMB"{return "USA / T-MOBILE"}
        "ATT"{return "USA / AT&T"}          "SPR"{return "USA / SPRINT"}
        "VZW"{return "USA / VERIZON"}       "XAA"{return "USA / OPEN"}
        default{return "$code / REGION DESCONOCIDA"}
    }
}
function Detect-Root {
    # Solo verificar root si ADB esta activo y responde (no en Download Mode)
    try {
        $devList = (& adb devices 2>$null) -join ""
        if ($devList -notmatch "	device") { return "NO ROOT (SIN ADB)" }
        $magiskRaw = ((& adb shell magisk -v 2>$null) | Where-Object { $_ -notmatch "daemon|starting|^\s*$" } | Select-Object -First 1); $magisk = if ($magiskRaw) { $magiskRaw.Trim() } else { "" }
        $chimeraRaw = ((& adb shell "which chimera" 2>$null) | Where-Object { $_ -notmatch "daemon|starting|^\s*$" } | Select-Object -First 1); $chimera = if ($chimeraRaw) { $chimeraRaw.Trim() } else { "" }
        $suRaw      = ((& adb shell "which su"      2>$null) | Where-Object { $_ -notmatch "daemon|starting|^\s*$" } | Select-Object -First 1); $su = if ($suRaw) { $suRaw.Trim() } else { "" }
        if ($magisk  -and $magisk  -match "^[\d\.]") { return "MAGISK $magisk" }
        if ($chimera -and $chimera -match "^/")      { return "CHIMERA" }
        if ($su      -and $su      -match "^/")      { return "SU / SUPERSU" }
    } catch {}
    return "NO ROOT"
}
function Check-ADB {
    $raw = & adb shell getprop ro.serialno 2>$null
    $s   = if ($raw) { "$raw".Trim() } else { "" }
    if (-not $s) {
        if ($Global:logAdb) { AdbLog "[!] No hay equipo ADB." }
        elseif ($Global:logGen) { GenLog "[!] No hay equipo ADB." }
        return $false
    }
    return $true
}
function Get-FirmwareAutoType($file) {
    $name=[System.IO.Path]::GetFileName($file).ToUpper()
    if ($name -match "^BL")    { return "BL"  }
    if ($name -match "^AP")    { return "AP"  }
    if ($name -match "^CP")    { return "CP"  }
    if ($name -match "^CSC")   { return "CSC" }
    if ($name -match "\.PIT$") { return "PIT" }
    return "UNKNOWN"
}

