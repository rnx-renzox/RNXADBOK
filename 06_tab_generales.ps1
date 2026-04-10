#==========================================================================
# LOGICA - TAB UTILIDADES GENERALES
#==========================================================================

# OEMINFO MDM HONOR
$btnEditOem.Add_Click({
    $fd=New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter="OEMINFO Files (*.img;*.bin)|*.img;*.bin|Todos|*.*"
    if ($fd.ShowDialog() -ne "OK") { return }
    $Global:_oemPath=$fd.FileName
    $Global:_oemRoot=$script:SCRIPT_ROOT
    $fn=[System.IO.Path]::GetFileName($Global:_oemPath)
    $fs=(Get-Item $Global:_oemPath).Length
    GenLog "`r`n[*] ===== OEMINFO MDM HONOR ====="
    GenLog "[*] Archivo : $fn  ($([math]::Round($fs/1KB,2)) KB)"
    GenLog "[~] Procesando..."
    $Global:_btnOem=$btnEditOem; $Global:_btnOem.Enabled=$false; $Global:_btnOem.Text="PROCESANDO..."
    $stamp=Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
    $backDir=[System.IO.Path]::Combine($Global:_oemRoot,"BACKUPS","OEMINFO_MDM_HONOR",$stamp)
    [OemPatcher]::Run($Global:_oemPath,$backDir)
    $Global:_oemTimer=New-Object System.Windows.Forms.Timer; $Global:_oemTimer.Interval=400
    $Global:_oemTimer.Add_Tick({
        $msg=""
        while ([OemPatcher]::Q.TryDequeue([ref]$msg)) { GenLog $msg }
        if ([OemPatcher]::Done) {
            $Global:_oemTimer.Stop(); $Global:_oemTimer.Dispose()
            $Global:_btnOem.Enabled=$true; $Global:_btnOem.Text="OEMINFO MDM HONOR"
        }
    })
    $Global:_oemTimer.Start()
})

#==========================================================================
# MODEM MI ACCOUNT - edita modem.img / modem.bin
# Entra a /image y renombra todos los archivos cardapp.xxx a 00000000000
# Soporta seleccion de 1 o 2 archivos (modem_a + modem_b, tipico en Xiaomi)
#==========================================================================
$btnEFSMod.Add_Click({
    $btnEFSMod.Enabled = $false; $btnEFSMod.Text = "PROCESANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        GenLog ""
        GenLog "[*] =========================================="
        GenLog "[*]   MODEM MI ACCOUNT  -  RNX TOOL PRO"
        GenLog "[*]   Renombrar cardapp.xxx -> 00000000000"
        GenLog "[*] =========================================="
        GenLog ""
        GenLog "[~] Selecciona 1 o 2 archivos modem (modem.img / modem.bin)"
        GenLog "[~] Algunos Xiaomi traen modem_a y modem_b - selecciona ambos"
        GenLog ""

        $fd = New-Object System.Windows.Forms.OpenFileDialog
        $fd.Filter    = "Modem Image (*.img;*.bin)|*.img;*.bin|Todos|*.*"
        $fd.Title     = "Selecciona modem.img / modem.bin (CTRL para seleccionar 2)"
        $fd.Multiselect = $true
        if ($fd.ShowDialog() -ne "OK") {
            GenLog "[~] Cancelado."
            return
        }

        $selectedFiles = $fd.FileNames
        if ($selectedFiles.Count -eq 0) { GenLog "[~] Sin archivos seleccionados."; return }
        if ($selectedFiles.Count -gt 2) {
            GenLog "[!] Maximo 2 archivos permitidos (modem_a + modem_b). Seleccionaste: $($selectedFiles.Count)"
            GenLog "[~] Por favor selecciona solo 1 o 2 archivos."
            return
        }

        GenLog "[+] Archivos seleccionados: $($selectedFiles.Count)"
        foreach ($f in $selectedFiles) {
            $fn = [System.IO.Path]::GetFileName($f)
            $fs = [math]::Round((Get-Item $f).Length / 1MB, 2)
            GenLog "    -> $fn  ($fs MB)"
        }
        GenLog ""

        $modemRoot = $script:SCRIPT_ROOT
        $stamp   = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
        $backDir = [System.IO.Path]::Combine($modemRoot, "BACKUPS", "MODEM_MI_ACCOUNT", $stamp)

        [ModemMiPatcher]::Run($selectedFiles, $backDir)

        $Global:_modemTimer = New-Object System.Windows.Forms.Timer
        $Global:_modemTimer.Interval = 500
        $Global:_modemTimer.Add_Tick({
            $msg = ""
            while ([ModemMiPatcher]::Q.TryDequeue([ref]$msg)) { GenLog $msg }
            if ([ModemMiPatcher]::Done) {
                $Global:_modemTimer.Stop(); $Global:_modemTimer.Dispose()
                $btnEFSMod.Enabled = $true
                $btnEFSMod.Text    = "MODEM MI ACCOUNT"
            }
        })
        $Global:_modemTimer.Start()

    } catch {
        GenLog "[!] Error inesperado: $_"
        $btnEFSMod.Enabled = $true; $btnEFSMod.Text = "MODEM MI ACCOUNT"
    }
    # No finally aqui: el timer reestablece el boton al terminar
})

# BORRAR DATOS
$btnsG1[0].Add_Click({
    GenLog "[*] BORRAR DATOS..."
    if (-not (Check-ADB)) { GenLog "[!] No hay equipo ADB."; return }
    $r=[System.Windows.Forms.MessageBox]::Show("Esto borrara TODOS los datos.`nEsta seguro?","CONFIRMAR",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($r -eq "Yes") {
        GenLog "[~] Enviando wipe..."; & adb shell "wipe data" 2>$null; & adb reboot recovery 2>$null
        GenLog "[OK] Wipe enviado - reiniciando recovery."
    } else { GenLog "[~] Cancelado." }
})
# DESHABILITAR OTA
$btnsG1[1].Add_Click({
    GenLog "[*] DESHABILITANDO OTA..."
    if (-not (Check-ADB)) { GenLog "[!] No hay equipo ADB."; return }
    & adb shell "pm disable com.wssyncmldm" 2>$null
    & adb shell "pm disable com.sec.android.soagent" 2>$null
    GenLog "[OK] OTA deshabilitado."
})
# FLASHEAR ROOT
$btnsG1[2].Add_Click({ GenLog "[>] FLASHEAR ROOT: usa Magisk patched boot.img en INICIAR FLASHEO" })
# VERIFICAR ROOT
$btnsG1[3].Add_Click({
    if (-not (Check-ADB)) { GenLog "[!] No hay equipo ADB."; return }
    GenLog "[*] Verificando root..."; $r=Detect-Root; GenLog "[+] ROOT STATE : $r"
    $rootStr2=if ($r -ne "NO ROOT") {"SI"} else {"NO"}; $Global:lblRoot.Text = "ROOT        : $rootStr2"
    $Global:lblRoot.ForeColor = if ($r -ne "NO ROOT") {[System.Drawing.Color]::Lime} else {[System.Drawing.Color]::Red}
})
# EFS SAMSUNG SIM 2
$btnEFSDirec.Add_Click({
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter = "EFS Image (*.img;*.bin)|*.img;*.bin|Todos|*.*"
    $fd.Title  = "Selecciona archivo EFS Samsung (efs.img / efs.bin)"
    if ($fd.ShowDialog() -ne "OK") { return }
    $Global:_efsPath = $fd.FileName
    $Global:_efsRoot = $script:SCRIPT_ROOT
    $fn = [System.IO.Path]::GetFileName($Global:_efsPath)
    $fs = (Get-Item $Global:_efsPath).Length
    GenLog "`r`n[*] ===== EFS SAMSUNG SIM 2 ====="
    GenLog "[*] Archivo : $fn  ($([math]::Round($fs/1KB,2)) KB)"
    GenLog "[~] Editando imagen EFS directamente (sin ADB, sin montar)..."
    $Global:_btnEfsDirec = $btnEFSDirec
    $Global:_btnEfsDirec.Enabled = $false
    $Global:_btnEfsDirec.Text    = "PROCESANDO..."
    $stamp   = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
    $backDir = [System.IO.Path]::Combine($Global:_efsRoot, "BACKUPS", "EFS_SAMSUNG_SIM2", $stamp)
    [EfsPatcher]::Run($Global:_efsPath, $backDir)
    $Global:_efsDirTimer = New-Object System.Windows.Forms.Timer
    $Global:_efsDirTimer.Interval = 400
    $Global:_efsDirTimer.Add_Tick({
        $msg = ""
        while ([EfsPatcher]::Q.TryDequeue([ref]$msg)) { GenLog $msg }
        if ([EfsPatcher]::Done) {
            $Global:_efsDirTimer.Stop(); $Global:_efsDirTimer.Dispose()
            $Global:_btnEfsDirec.Enabled = $true
            $Global:_btnEfsDirec.Text    = "EFS SAMSUNG SIM 2"
        }
    })
    $Global:_efsDirTimer.Start()
})

# PERSIST MI ACCOUNT
$btnPersist.Add_Click({
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter = "Persist Image (*.img;*.bin)|*.img;*.bin|Todos|*.*"
    $fd.Title  = "Selecciona archivo Persist Xiaomi (persist.img / persist.bin)"
    if ($fd.ShowDialog() -ne "OK") { return }
    $Global:_persistPath = $fd.FileName
    $Global:_persistRoot = $script:SCRIPT_ROOT
    $fn = [System.IO.Path]::GetFileName($Global:_persistPath)
    $fs = (Get-Item $Global:_persistPath).Length
    GenLog "`r`n[*] ===== PERSIST MI ACCOUNT ====="
    GenLog "[*] Archivo : $fn  ($([math]::Round($fs/1KB,2)) KB)"
    GenLog "[~] Navegando ext4 (superblock->inode->fdsd->st->rn)..."
    $Global:_btnPersist = $btnPersist
    $Global:_btnPersist.Enabled = $false
    $Global:_btnPersist.Text    = "PROCESANDO..."
    $stamp   = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
    $backDir = [System.IO.Path]::Combine($Global:_persistRoot, "BACKUPS", "PERSIST_MI_ACCOUNT", $stamp)
    [PersistPatcher]::Run($Global:_persistPath, $backDir)
    $Global:_persistTimer = New-Object System.Windows.Forms.Timer
    $Global:_persistTimer.Interval = 400
    $Global:_persistTimer.Add_Tick({
        $msg = ""
        while ([PersistPatcher]::Q.TryDequeue([ref]$msg)) { GenLog $msg }
        if ([PersistPatcher]::Done) {
            $Global:_persistTimer.Stop(); $Global:_persistTimer.Dispose()
            $Global:_btnPersist.Enabled = $true
            $Global:_btnPersist.Text    = "PERSIST MI ACCOUNT"
        }
    })
    $Global:_persistTimer.Start()
})
# LEER IMEI
$btnsG3[2].Add_Click({
    GenLog "[*] LEER IMEI..."
    if (-not (Check-ADB)) {
        $hdet=Invoke-HeimdallAdv "detect"
        if ($hdet -imatch "Device detected") {
            $pit=Invoke-HeimdallAdv "print-pit"
            $pit -split "`n" | Where-Object { $_ -imatch "IMEI" } | ForEach-Object { GenLog "[+] $_" }
        } else { GenLog "[!] Sin ADB ni Download Mode"; return }
        return
    }
    $imeiRaw=(& adb shell "service call iphonesubinfo 1" 2>$null)
    if ($imeiRaw -match "'\s*(\d{5,})\s*'") { GenLog "[+] IMEI : $($Matches[1])" }
    else {
        $imei2=(& adb shell "dumpsys iphonesubinfo" 2>$null) | Select-String "Device ID" | Select-Object -First 1
        if ($imei2) { GenLog "[+] $imei2" } else { GenLog "[!] IMEI no disponible" }
    }
})
# Stubs MTK
$btnsG3[0].Add_Click({ GenLog "[>] BYPASS MTK : en desarrollo" })
$btnsG3[1].Add_Click({ GenLog "[>] ESCRIBIR IMEI : requiere EDL o herramienta MTK" })
$btnsG3[3].Add_Click({ GenLog "[>] DESBLOQUEAR BL : fastboot flashing unlock" })

#==========================================================================
# WINUSB DRIVER BUTTON HANDLER
#==========================================================================
$btnWinUSB.Add_Click({
    $btnWinUSB.Enabled = $false
    $btnWinUSB.Text    = "INSTALANDO..."
    [System.Windows.Forms.Application]::DoEvents()

    $Global:logOdin.Clear()
    $cpuNow = Get-SamsungCPUInfo

    if ($cpuNow.MODE -ne "DOWNLOAD_MODE") {
        OdinLog "[!] No hay dispositivo en Download Mode"
        OdinLog "[~] Conecta el equipo en Download Mode primero"
        OdinLog "    Vol- + Power  o  adb reboot download"
        $btnWinUSB.Enabled = $true
        $btnWinUSB.Text    = "INSTALAR DRIVER WINUSB"
        return
    }

    $vid    = $cpuNow.VID
    $usbpid = $cpuNow.USBPID
    $name   = $cpuNow.USB_NAME

    $ok = Install-WinUSBDriver -vid $vid -usbpid $usbpid -friendlyName $name

    if ($ok) {
        $btnWinUSB.ForeColor = [System.Drawing.Color]::Lime
        $btnWinUSB.Text      = "DRIVER OK - RECONECTA"
        $Global:lblStatus.Text = "  RNX TOOL PRO v2.3  |  WinUSB instalado  |  Reconecta el equipo"
    } else {
        $btnWinUSB.ForeColor = [System.Drawing.Color]::Red
        $btnWinUSB.Text      = "ERROR - VER LOG"
    }
    $btnWinUSB.Enabled = $true
})

