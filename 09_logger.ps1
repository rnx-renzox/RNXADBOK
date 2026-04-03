#==========================================================================
# RNX TOOL PRO - MODULO 09: SISTEMA DE LOGGING
# Escribe logs a archivo con niveles INFO / WARN / ERROR / DEBUG
# Carpeta: BACKUPS\LOGS\ dentro de la raiz del proyecto
#==========================================================================

# ---- Inicializar paths de log al cargar el modulo ----
$script:LOG_DIR  = [System.IO.Path]::Combine($script:SCRIPT_ROOT, "BACKUPS", "LOGS")
$script:LOG_FILE = [System.IO.Path]::Combine(
    $script:LOG_DIR,
    "RNX_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
)

# Crear carpeta de logs si no existe
if (-not (Test-Path $script:LOG_DIR)) {
    New-Item $script:LOG_DIR -ItemType Directory -Force | Out-Null
}

# Escribir cabecera de sesion
@(
    "=========================================="
    "  RNX TOOL PRO v2.3 - LOG DE SESION"
    "  Inicio : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    "  Host   : $env:COMPUTERNAME  |  User: $env:USERNAME"
    "  OS     : $([System.Environment]::OSVersion.VersionString)"
    "=========================================="
    ""
) | Add-Content -Path $script:LOG_FILE -Encoding UTF8

# ---- Funcion central de escritura ----
function Write-RNXLog {
    param(
        [ValidateSet("INFO","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",
        [string]$Message,
        [string]$Source = ""   # nombre del tab/funcion que llama
    )
    $ts  = Get-Date -Format "HH:mm:ss"
    $src = if ($Source) { "[$Source] " } else { "" }
    $line = "[$ts] [$Level] $src$Message"
    try {
        Add-Content -Path $script:LOG_FILE -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

# ---- Escribir bloque separador de operacion ----
function Write-RNXLogSection {
    param([string]$Title)
    $sep  = "=" * 50
    $ts   = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    @("", $sep, "  $Title", "  $ts", $sep) |
        Add-Content -Path $script:LOG_FILE -Encoding UTF8 -ErrorAction SilentlyContinue
}

# ---- Parchear OdinLog para que tambien escriba al archivo ----
# Se redefinen las 4 funciones existentes agregando la llamada a Write-RNXLog.
# El comportamiento UI es identico — solo se agrega el log a disco.

function OdinLog($msg) {
    if ($Global:logOdin) {
        $Global:logOdin.AppendText("$msg`r`n")
        $Global:logOdin.SelectionStart = $Global:logOdin.Text.Length
        $Global:logOdin.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    $level = if ($msg -match "^\[!]")  { "ERROR" }
             elseif ($msg -match "^\[~]") { "WARN"  }
             else                         { "INFO"  }
    Write-RNXLog -Level $level -Message $msg -Source "SAMSUNG"
}

function AdbLog($msg) {
    if ($Global:logAdb) {
        $Global:logAdb.AppendText("$msg`r`n")
        $Global:logAdb.SelectionStart = $Global:logAdb.Text.Length
        $Global:logAdb.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    $level = if ($msg -match "^\[!]")  { "ERROR" }
             elseif ($msg -match "^\[~]") { "WARN"  }
             else                         { "INFO"  }
    Write-RNXLog -Level $level -Message $msg -Source "ADB"
}

function GenLog($msg) {
    if ($Global:logGen) {
        $Global:logGen.AppendText("$msg`r`n")
        $Global:logGen.SelectionStart = $Global:logGen.Text.Length
        $Global:logGen.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    $level = if ($msg -match "^\[!]")  { "ERROR" }
             elseif ($msg -match "^\[~]") { "WARN"  }
             else                         { "INFO"  }
    Write-RNXLog -Level $level -Message $msg -Source "GENERALES"
}

function FbLog($msg) {
    if ($Global:logFb) {
        $Global:logFb.AppendText("$msg`r`n")
        $Global:logFb.SelectionStart = $Global:logFb.Text.Length
        $Global:logFb.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    $level = if ($msg -match "^\[!]")  { "ERROR" }
             elseif ($msg -match "^\[~]") { "WARN"  }
             else                         { "INFO"  }
    Write-RNXLog -Level $level -Message $msg -Source "FASTBOOT"
}
