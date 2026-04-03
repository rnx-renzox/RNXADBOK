#==========================================================================
# RNX TOOL PRO - MODULO 10: CAPA DE SERVICIOS
#
# Wrappers centralizados para ADB, Heimdall y Fastboot.
# Responsabilidades:
#   - Validar que el ejecutable existe antes de llamarlo
#   - Capturar exit code y stderr correctamente
#   - Registrar cada llamada en el log con nivel adecuado
#   - Devolver resultado uniforme al caller
#
# IMPORTANTE: este modulo NO reemplaza las funciones de UI existentes
# (Invoke-HeimdallLive, Invoke-FastbootLive) que manejan streaming en tiempo
# real hacia los TextBox. Esas quedan en sus modulos originales.
# Este modulo agrega la capa de validacion y logging que les faltaba.
#==========================================================================

#==========================================================================
# RESOLUCION DE EJECUTABLES
# Centraliza la busqueda de cada binario en un solo lugar.
# Los modulos originales tenian logica dispersa (Get-FastbootExe en 07,
# "heimdall" hardcodeado en 03, "adb" en PATH en todos lados).
#==========================================================================

function Get-ADBExe {
    # ADB: buscar en tools\ primero, luego rutas conocidas, luego PATH
    $candidates = @(
        (Join-Path $script:TOOLS_DIR "adb.exe"),
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
        "C:\platform-tools\adb.exe",
        "C:\android\platform-tools\adb.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c -ErrorAction SilentlyContinue) { return $c }
    }
    # Fallback: confiar en PATH (comportamiento original del codigo)
    try {
        $gc = Get-Command "adb" -ErrorAction SilentlyContinue
        if ($gc) { return $gc.Source }
    } catch {}
    return $null
}

function Get-HeimdallExe {
    $candidates = @(
        (Join-Path $script:TOOLS_DIR "heimdall.exe"),
        ".\heimdall.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c -ErrorAction SilentlyContinue) { return $c }
    }
    try {
        $gc = Get-Command "heimdall" -ErrorAction SilentlyContinue
        if ($gc) { return $gc.Source }
    } catch {}
    return $null
}

# Cachear rutas al cargar el modulo para no recalcular en cada llamada
$script:SVC_ADB      = Get-ADBExe
$script:SVC_HEIMDALL = Get-HeimdallExe
# Fastboot ya tiene Get-FastbootExe en 07_tab_fastboot - reusar

#==========================================================================
# INVOKE-ADB
# Wrapper principal para llamadas ADB no-destructivas.
# Captura stdout+stderr, registra en log, devuelve string limpio.
#
# Uso:
#   $out = Invoke-ADB "shell getprop ro.product.model"
#   $out = Invoke-ADB "devices"
#   $out = Invoke-ADB @("shell", "getprop", "ro.serialno")
#==========================================================================
function Invoke-ADB {
    param(
        [Parameter(Mandatory)][object]$Arguments,   # string o string[]
        [string]$LogSource    = "ADB",
        [switch]$SilentErrors                        # no loguear si falla (para polls)
    )

    # Resolver ejecutable
    if (-not $script:SVC_ADB) { $script:SVC_ADB = Get-ADBExe }
    if (-not $script:SVC_ADB) {
        Write-RNXLog "ERROR" "adb.exe no encontrado. Coloca adb.exe en tools\" $LogSource
        return $null
    }

    # Normalizar argumentos a array
    $argArr = if ($Arguments -is [array]) {
        $Arguments
    } else {
        # split respetando comillas simples/dobles
        $Arguments -split '\s+(?=(?:[^"]*"[^"]*")*[^"]*$)' | Where-Object { $_ -ne "" }
    }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $script:SVC_ADB
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        # Pasar argumentos como array evita problemas con espacios en paths
        foreach ($a in $argArr) { $psi.ArgumentList.Add($a) }

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        $exitCode = $p.ExitCode
        $combined = ($stdout + $stderr).Trim()

        # Filtrar ruido del daemon ADB
        $clean = ($combined -split "`n") | Where-Object {
            $_ -notmatch "^\s*\*\s*(daemon|adb server)" -and
            $_ -notmatch "starting it now|successfully started|^List of devices|^\s*$"
        }
        $result = ($clean -join "`n").Trim()

        # Logging
        $cmdStr = "adb " + ($argArr -join " ")
        if ($exitCode -ne 0 -and -not $SilentErrors) {
            Write-RNXLog "ERROR" "Exit $exitCode | $cmdStr | $result" $LogSource
        } else {
            Write-RNXLog "DEBUG" "$cmdStr" $LogSource
        }

        return $result

    } catch {
        if (-not $SilentErrors) {
            Write-RNXLog "ERROR" "Excepcion ejecutando ADB: $_" $LogSource
        }
        return $null
    }
}

#==========================================================================
# INVOKE-ADB-SHELL
# Shortcut para "adb shell <cmd>" — el patron mas comun en el codigo.
#
# Uso:
#   $model = Invoke-ADBShell "getprop ro.product.model"
#   $id    = Invoke-ADBShell "su -c id"
#==========================================================================
function Invoke-ADBShell {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string]$LogSource = "ADB",
        [switch]$SilentErrors
    )
    return Invoke-ADB -Arguments @("shell", $Command) -LogSource $LogSource -SilentErrors:$SilentErrors
}

#==========================================================================
# INVOKE-ADB-GETPROP
# Wrapper especifico para getprop — limpia ruido de daemon.
#==========================================================================
function Invoke-ADBGetprop {
    param([Parameter(Mandatory)][string]$Prop)
    $raw = Invoke-ADB -Arguments @("shell", "getprop", $Prop) -SilentErrors
    if (-not $raw) { return "" }
    # Tomar solo la primera linea con contenido real
    $first = ($raw -split "`n") | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1
    return if ($first) { $first.Trim() } else { "" }
}

#==========================================================================
# TEST-ADBConnected
# Verificacion rapida: hay dispositivo ADB en linea?
# Reemplaza el patron disperso: ((& adb devices) -join "" -match "`tdevice")
#==========================================================================
function Test-ADBConnected {
    if (-not $script:SVC_ADB) { $script:SVC_ADB = Get-ADBExe }
    if (-not $script:SVC_ADB) { return $false }
    try {
        $out = & $script:SVC_ADB devices 2>$null
        return (($out -join "") -match "`tdevice")
    } catch { return $false }
}

#==========================================================================
# INVOKE-HEIMDALL-SAFE
# Wrapper para Heimdall con validacion de ejecutable y logging de exit code.
# No reemplaza Invoke-HeimdallLive (streaming UI) — solo agrega validacion.
#==========================================================================
function Invoke-HeimdallSafe {
    param(
        [Parameter(Mandatory)][string]$Arguments,
        [switch]$IncludeStderr = $true
    )

    if (-not $script:SVC_HEIMDALL) { $script:SVC_HEIMDALL = Get-HeimdallExe }
    if (-not $script:SVC_HEIMDALL) {
        Write-RNXLog "ERROR" "heimdall.exe no encontrado en tools\ ni en PATH" "HEIMDALL"
        return $null
    }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $script:SVC_HEIMDALL
        $psi.Arguments              = $Arguments
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        $exitCode = $p.ExitCode
        Write-RNXLog "DEBUG" "heimdall $Arguments | exit $exitCode" "HEIMDALL"

        if ($exitCode -ne 0) {
            $errMsg = $stderr.Trim()
            if ($errMsg) { Write-RNXLog "WARN" "heimdall stderr: $errMsg" "HEIMDALL" }
        }

        return if ($IncludeStderr) { $stdout + $stderr } else { $stdout }

    } catch {
        Write-RNXLog "ERROR" "Excepcion ejecutando heimdall: $_" "HEIMDALL"
        return $null
    }
}

#==========================================================================
# INVOKE-FASTBOOT-SAFE
# Wrapper que agrega validacion y logging a Invoke-Fastboot existente.
# Fastboot ya tiene Get-FastbootExe en 07_tab_fastboot — lo reutilizamos.
#==========================================================================
function Invoke-FastbootSafe {
    param(
        [Parameter(Mandatory)][string]$Arguments,
        [switch]$IsDestructive   # agrega log adicional si es flash/erase/wipe
    )

    $fbExe = Get-FastbootExe   # funcion de 07_tab_fastboot
    if (-not $fbExe) {
        Write-RNXLog "ERROR" "fastboot.exe no encontrado" "FASTBOOT"
        return $null
    }

    if ($IsDestructive) {
        Write-RNXLog "WARN" "OPERACION DESTRUCTIVA: fastboot $Arguments" "FASTBOOT"
    } else {
        Write-RNXLog "DEBUG" "fastboot $Arguments" "FASTBOOT"
    }

    try {
        $argArr = $Arguments -split '\s+' | Where-Object { $_ -ne "" }
        $result = & $fbExe $argArr 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-RNXLog "ERROR" "fastboot exit $exitCode | $Arguments | $result" "FASTBOOT"
        }

        if ($result -is [array]) { return ($result | ForEach-Object { "$_" }) -join "`n" }
        return "$result"

    } catch {
        Write-RNXLog "ERROR" "Excepcion ejecutando fastboot: $_" "FASTBOOT"
        return $null
    }
}

#==========================================================================
# CONFIRM-RNXACTION
# Dialogo de confirmacion unificado para operaciones destructivas.
# Centraliza los ~8 MessageBox::Show dispersos en los tabs.
#
# Uso:
#   if (-not (Confirm-RNXAction "Vas a borrar todos los datos. ¿Confirmas?")) { return }
#==========================================================================
function Confirm-RNXAction {
    param(
        [Parameter(Mandatory)][string]$Mensaje,
        [string]$Titulo  = "CONFIRMAR OPERACION",
        [string]$Icono   = "Warning"   # Warning | Question | Information
    )
    $icon = [System.Windows.Forms.MessageBoxIcon]::$Icono
    $r = [System.Windows.Forms.MessageBox]::Show(
        $Mensaje,
        $Titulo,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        $icon
    )
    $confirmed = ($r -eq "Yes")
    Write-RNXLog "INFO" "Confirmacion '$Titulo': $(if($confirmed){'ACEPTADO'}else{'CANCELADO'})" "UI"
    return $confirmed
}
