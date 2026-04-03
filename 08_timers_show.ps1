# ---- Extender timer para detectar fastboot ----
# Se agrega un segundo timer liviano (3s) que no interfiere con el ADB timer
$script:FB_LAST_DETECTED = $false
$timerFb          = New-Object Windows.Forms.Timer
$timerFb.Interval = 3000
$timerFb.Add_Tick({
    $modoTxt = $Global:lblModo.Text
    # No correr si ya estamos en otro modo confirmado (ADB activo o Download)
    if ($modoTxt -imatch "ADB|DOWNLOAD") { return }
    $fbExe = Get-FastbootExe
    if (-not $fbExe) { return }
    try {
        $psi2 = New-Object System.Diagnostics.ProcessStartInfo
        $psi2.FileName = $fbExe; $psi2.Arguments = "devices"
        $psi2.RedirectStandardOutput = $true; $psi2.RedirectStandardError = $true
        $psi2.UseShellExecute = $false; $psi2.CreateNoWindow = $true
        $p2 = New-Object System.Diagnostics.Process; $p2.StartInfo = $psi2
        $p2.Start() | Out-Null
        $out2 = $p2.StandardOutput.ReadToEnd(); $p2.WaitForExit()
        $hasFb = $out2 -match "\tfastboot"
        if ($hasFb -and -not $script:FB_LAST_DETECTED) {
            $script:FB_LAST_DETECTED = $true
            $serial2 = ($out2 -split "\t")[0].Trim()
            $Global:lblADB.Text      = "ADB         : FASTBOOT"
            $Global:lblADB.ForeColor = [System.Drawing.Color]::Yellow
            $Global:lblModo.Text     = "MODO        : FASTBOOT"
            $Global:lblModo.ForeColor= [System.Drawing.Color]::Yellow
            $Global:lblSerial.Text   = "SERIAL      : $serial2"
            $Global:lblStatus.Text   = "  RNX TOOL PRO v2.3  |  FASTBOOT  |  $serial2"
        } elseif (-not $hasFb -and $script:FB_LAST_DETECTED) {
            $script:FB_LAST_DETECTED = $false
            $Global:lblADB.Text      = "ADB         : DESCONECTADO"
            $Global:lblADB.ForeColor = [System.Drawing.Color]::Orange
            $Global:lblModo.Text     = "MODO        : -"
            $Global:lblModo.ForeColor= [System.Drawing.Color]::LightGray
        }
    } catch {}
})
$timerFb.Start()

#==========================================================================
# TIMER + SHOW
#==========================================================================
$timer          = New-Object Windows.Forms.Timer
$timer.Interval = 2500   # 2.5s - suficiente para no solapar jobs ADB
$timer.Add_Tick({
    # En Download Mode el sidebar muestra info de Heimdall, no ADB.
    # El timer ADB no debe correr cuando estamos en ese modo
    # (lo detectamos por el texto del label MODO)
    $modoTxt = $Global:lblModo.Text
    if ($modoTxt -imatch "DOWNLOAD") { return }
    Get-DeepDeviceStatus
})
$timer.Start()

# Limpiar jobs al cerrar la ventana
$form.Add_FormClosing({
    $timer.Stop()
    $timerFb.Stop()
    if ($script:FB_LEER_TIMER) { $script:FB_LEER_TIMER.Stop(); $script:FB_LEER_TIMER.Dispose() }
    if ($script:ADB_JOB) {
        Stop-Job  -Job $script:ADB_JOB -ErrorAction SilentlyContinue
        Remove-Job -Job $script:ADB_JOB -Force -ErrorAction SilentlyContinue
    }
    $timerFb.Stop()
    Get-Job -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
    # Escribir cierre de sesion en el log
    try {
        Write-RNXLog -Level "INFO" -Message "=========================================="
        Write-RNXLog -Level "INFO" -Message "  SESION CERRADA: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
        Write-RNXLog -Level "INFO" -Message "=========================================="
    } catch {}
})

$form.ShowDialog()