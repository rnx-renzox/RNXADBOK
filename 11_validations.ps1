#==========================================================================
# RNX TOOL PRO - MODULO 11: VALIDACIONES CRITICAS
#
# Capa de validacion que se ejecuta ANTES de cualquier operacion
# destructiva (flash, wipe, erase, reboot, parcheo).
#
# Objetivo: evitar bricks, datos corruptos y operaciones imposibles.
#
# Uso en botones:
#   $fbBtnFlBoot.Add_Click({
#       try {
#           Assert-DeviceReady -Mode FASTBOOT -MinBattery 40
#           Start-FastbootFlash "boot" $fbBtnFlBoot "FLASH BOOT"
#       } catch {
#           FbLog "[!] $_"
#       }
#   })
#==========================================================================

#==========================================================================
# ASSERT-DEVICEREADY
# Validacion unificada antes de operaciones criticas.
# Lanza excepcion con mensaje claro si alguna condicion falla.
# El caller solo necesita un try/catch — sin if/else anidados.
#
# Parametros:
#   -Mode        ADB | FASTBOOT | DOWNLOAD   (modo requerido del dispositivo)
#   -MinBattery  porcentaje minimo (default 30, 0 = no verificar)
#   -NeedRoot    verificar que el dispositivo tiene root accesible
#   -NeedUnlockedBL verificar bootloader desbloqueado (para flash)
#==========================================================================
function Assert-DeviceReady {
    param(
        [ValidateSet("ADB","FASTBOOT","DOWNLOAD","ANY")]
        [string]$Mode         = "ADB",
        [int]   $MinBattery   = 0,
        [switch]$NeedRoot,
        [switch]$NeedUnlockedBL
    )

    Write-RNXLog "DEBUG" "Assert-DeviceReady: Mode=$Mode MinBattery=$MinBattery NeedRoot=$NeedRoot NeedUnlockedBL=$NeedUnlockedBL" "VALIDATION"

    # ------------------------------------------------------------------
    # 1. MODO DEL DISPOSITIVO
    # Leer del sidebar (ya actualizado por el timer cada 2.5s)
    # ------------------------------------------------------------------
    if ($Mode -ne "ANY") {
        $modoTxt = if ($Global:lblModo) { $Global:lblModo.Text } else { "" }

        $modeOk = switch ($Mode) {
            "ADB"      { $modoTxt -imatch "ADB"      -and $modoTxt -notmatch "DOWNLOAD|FASTBOOT" }
            "FASTBOOT" { $modoTxt -imatch "FASTBOOT" }
            "DOWNLOAD" { $modoTxt -imatch "DOWNLOAD" }
        }

        if (-not $modeOk) {
            $modoActual = if ($modoTxt) { $modoTxt.Trim() } else { "desconocido" }
            $msg = "Modo incorrecto. Requerido: $Mode | Actual: $modoActual"
            Write-RNXLog "ERROR" $msg "VALIDATION"
            throw $msg
        }
    }

    # ------------------------------------------------------------------
    # 2. BATERIA MINIMA  (solo en modo ADB)
    # ------------------------------------------------------------------
    if ($MinBattery -gt 0 -and ($Mode -eq "ADB" -or $Mode -eq "ANY")) {
        if (Test-ADBConnected) {
            try {
                $batRaw = Invoke-ADB "shell dumpsys battery" -SilentErrors
                if ($batRaw -match "level:\s*(\d+)") {
                    $bat = [int]$Matches[1]
                    Write-RNXLog "DEBUG" "Bateria: $bat%" "VALIDATION"
                    if ($bat -lt $MinBattery) {
                        $msg = "Bateria insuficiente: $bat% (minimo requerido: $MinBattery%)"
                        Write-RNXLog "ERROR" $msg "VALIDATION"
                        throw $msg
                    }
                }
            } catch [System.Exception] {
                # Si el mensaje ya es nuestro error de bateria, re-lanzar
                if ($_.Exception.Message -match "Bateria insuficiente") { throw }
                # Si es error de ADB, continuar (no bloquear por no poder leer bateria)
                Write-RNXLog "WARN" "No se pudo leer bateria: $_" "VALIDATION"
            }
        }
    }

    # ------------------------------------------------------------------
    # 3. ROOT ACCESIBLE  (solo si se pide)
    # ------------------------------------------------------------------
    if ($NeedRoot) {
        if (-not (Test-ADBConnected)) {
            throw "Se requiere root pero no hay dispositivo ADB conectado"
        }
        $idOut = Invoke-ADB "shell su -c id" -SilentErrors
        if ($idOut -notmatch "uid=0") {
            $msg = "Se requiere root para esta operacion. Ejecuta AUTOROOT MAGISK primero."
            Write-RNXLog "ERROR" $msg "VALIDATION"
            throw $msg
        }
    }

    # ------------------------------------------------------------------
    # 4. BOOTLOADER DESBLOQUEADO  (para flash en ADB/Download)
    # ------------------------------------------------------------------
    if ($NeedUnlockedBL) {
        $oemLock = ""
        if ($Mode -eq "ADB" -or $Mode -eq "ANY") {
            $oemLock = Invoke-ADBGetprop "ro.boot.flash.locked"
        } elseif ($Mode -eq "FASTBOOT") {
            # En fastboot leer de la variable del dispositivo
            $fbOut = Invoke-FastbootSafe "getvar unlocked"
            if ($fbOut -match "unlocked:\s*(yes|no|true|false)") {
                $oemLock = if ($Matches[1] -imatch "yes|true") { "0" } else { "1" }
            }
        }
        if ($oemLock -eq "1") {
            $msg = "Bootloader BLOQUEADO. Desbloquea primero desde: Ajustes > Info del telefono > Num. compilacion (x7) > Opciones dev. > OEM unlock"
            Write-RNXLog "ERROR" $msg "VALIDATION"
            throw $msg
        }
    }

    Write-RNXLog "INFO" "Assert-DeviceReady OK: Mode=$Mode" "VALIDATION"
}

#==========================================================================
# ASSERT-FILEEXISTS
# Valida que un archivo existe y tiene tamaño razonable.
# Util antes de flash, patcheo, extraccion.
#==========================================================================
function Assert-FileExists {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Label    = "Archivo",
        [long]  $MinBytes = 1024   # 1 KB minimo por defecto
    )
    if (-not (Test-Path $Path)) {
        $msg = "$Label no encontrado: $Path"
        Write-RNXLog "ERROR" $msg "VALIDATION"
        throw $msg
    }
    $size = (Get-Item $Path).Length
    if ($size -lt $MinBytes) {
        $msg = "$Label parece corrupto: $([math]::Round($size/1KB,1)) KB (minimo: $([math]::Round($MinBytes/1KB,1)) KB)"
        Write-RNXLog "ERROR" $msg "VALIDATION"
        throw $msg
    }
    Write-RNXLog "DEBUG" "$Label OK: $([math]::Round($size/1MB,2)) MB | $Path" "VALIDATION"
}

#==========================================================================
# ASSERT-TOOLEXISTS
# Valida que un binario externo esta disponible antes de usarlo.
#==========================================================================
function Assert-ToolExists {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ToolName,
        [string]$DownloadHint = ""
    )
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        $msg = "$ToolName no encontrado en: $Path"
        if ($DownloadHint) { $msg += " | Descarga: $DownloadHint" }
        Write-RNXLog "ERROR" $msg "VALIDATION"
        throw $msg
    }
}

#==========================================================================
# GET-BATTERYINFO
# Devuelve hashtable con info de bateria. No lanza excepcion si falla.
# Uso: $bat = Get-BatteryInfo; if ($bat.Level -lt 30) { ... }
#==========================================================================
function Get-BatteryInfo {
    $result = @{ Level = -1; Status = "UNKNOWN"; AC = $false; OK = $false }
    try {
        if (-not (Test-ADBConnected)) { return $result }
        $raw = Invoke-ADB "shell dumpsys battery" -SilentErrors
        if (-not $raw) { return $result }

        if ($raw -match "level:\s*(\d+)")    { $result.Level  = [int]$Matches[1] }
        if ($raw -match "status:\s*(\d+)") {
            $result.Status = switch ([int]$Matches[1]) {
                1 { "UNKNOWN" } 2 { "CHARGING" } 3 { "DISCHARGING" }
                4 { "NOT CHARGING" } 5 { "FULL" } default { "UNKNOWN" }
            }
        }
        if ($raw -match "AC powered:\s*(true|false)") { $result.AC = ($Matches[1] -eq "true") }
        $result.OK = $true
    } catch {
        Write-RNXLog "WARN" "No se pudo leer bateria: $_" "VALIDATION"
    }
    return $result
}

#==========================================================================
# GET-DEVICESTATESUMMARY
# Resumen rapido del estado del dispositivo para loguear antes de
# operaciones criticas. No lanza excepcion.
#==========================================================================
function Get-DeviceStateSummary {
    $lines = @()
    try {
        $lines += "--- Estado dispositivo ---"
        $lines += "  ADB conectado   : $(if(Test-ADBConnected){'SI'}else{'NO'})"
        $lines += "  Modo sidebar    : $($Global:lblModo.Text.Trim())"
        $lines += "  Modelo          : $($Global:lblModel.Text.Trim())"
        $lines += "  Serial          : $($Global:lblSerial.Text.Trim())"
        $bat = Get-BatteryInfo
        if ($bat.OK) {
            $lines += "  Bateria         : $($bat.Level)% ($($bat.Status)$(if($bat.AC){', AC'}else{''}))"
        }
        $lines += "  Root            : $($Global:lblRoot.Text.Trim())"
        $lines += "--------------------------"
    } catch {}
    return $lines
}
