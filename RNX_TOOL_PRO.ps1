#==========================================================================
# RNX TOOL PRO - HYBRID  v2.3
# Archivo principal - punto de entrada
#
# Estructura:
#   RNX_TOOL_PRO.ps1          <- Este archivo (lanzar este)
#   modules\                  <- codigo PS1 modularizado
#   tools\                    <- binarios externos (adb, heimdall, fastboot, magiskboot...)
#     modules\                <- ZIPs de modulos Magisk para bypass bancario
#==========================================================================

# Capturar la raiz ANTES de cualquier dot-sourcing
# Con dot-sourcing, $PSScriptRoot dentro de cada modulo apunta a su propia carpeta.
# Por eso se pasa la raiz real como variable Global antes de cargar los modulos.
$Global:RNX_ROOT = $PSScriptRoot

$script:MOD_DIR = Join-Path $PSScriptRoot "modules"

. "$script:MOD_DIR\00_types.ps1"
. "$script:MOD_DIR\01_init_globals.ps1"
. "$script:MOD_DIR\09_logger.ps1"        # despues de 01 para que SCRIPT_ROOT ya este definido
. "$script:MOD_DIR\10_services.ps1"      # despues de 09 para que Write-RNXLog este disponible
. "$script:MOD_DIR\11_validations.ps1"   # despues de 10 para que Invoke-ADB/Test-ADBConnected esten listos
. "$script:MOD_DIR\02_ui_main.ps1"
. "$script:MOD_DIR\03_heimdall.ps1"
. "$script:MOD_DIR\04_tab_samsung.ps1"
. "$script:MOD_DIR\05_tab_adb.ps1"
. "$script:MOD_DIR\06_tab_generales.ps1"
. "$script:MOD_DIR\07_tab_fastboot.ps1"
. "$script:MOD_DIR\08_timers_show.ps1"
