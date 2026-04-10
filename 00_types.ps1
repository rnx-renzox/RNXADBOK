#==========================================================================
# RNX TOOL PRO - HYBRID  v2.3  (FLASH ENGINE COMPLETO + EXTRACCION TOTAL)
# MEJORAS v2.3: A) SHA256+Fingerprint  C) Validacion Post-Parche
#               D) Backup Verificado+Meta  H) Logs con Offset+HexDump
#==========================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ("OemPatcher" -as [type])) {
Add-Type -Language CSharp -TypeDefinition (
    "using System;`r`n" +
    "using System.IO;`r`n" +
    "using System.Threading.Tasks;`r`n" +
    "using System.Collections.Concurrent;`r`n" +
    "using System.Security.Cryptography;`r`n" +
    "public static class OemPatcher {`r`n" +
    "    public static ConcurrentQueue<string> Q = new ConcurrentQueue<string>();`r`n" +
    "    public static volatile bool Done = false;`r`n" +
    "    // [MEJORA A] Calcula SHA256 del array de bytes`r`n" +
    "    private static string CalcSHA256(byte[] data) {`r`n" +
    "        using (var sha = SHA256.Create()) {`r`n" +
    "            byte[] h = sha.ComputeHash(data);`r`n" +
    "            return BitConverter.ToString(h).Replace(`"-`",`"`").ToLower();`r`n" +
    "        }`r`n" +
    "    }`r`n" +
    "    public static void Run(string path, string outDir) {`r`n" +
    "        Done = false;`r`n" +
    "        while (Q.Count > 0) { string x; Q.TryDequeue(out x); }`r`n" +
    "        Task.Run((System.Action)(() => {`r`n" +
    "            var sb = new System.Text.StringBuilder();`r`n" +
    "            try {`r`n" +
    "                byte[] bytes = File.ReadAllBytes(path);`r`n" +
    "                sb.AppendLine(`"[+] Bytes leidos   : `" + bytes.Length);`r`n" +
    "                // [MEJORA A] Fingerprint: SHA256 + validacion de tamano`r`n" +
    "                string sha256 = CalcSHA256(bytes);`r`n" +
    "                sb.AppendLine(`"[+] SHA256         : `" + sha256.Substring(0,16) + `"...`");`r`n" +
    "                sb.AppendLine(`"[+] SHA256 completo: `" + sha256);`r`n" +
    "                if (bytes.Length < 512) {`r`n" +
    "                    sb.AppendLine(`"[!] ABORTANDO: Archivo demasiado pequeno (`" + bytes.Length + `" bytes). Minimo esperado: 512 bytes.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                if (bytes.Length > 512 * 1024 * 1024) {`r`n" +
    "                    sb.AppendLine(`"[!] ABORTANDO: Archivo demasiado grande (`" + bytes.Length + `" bytes). Maximo esperado: 512 MB.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] Validacion tamano: OK (`" + (bytes.Length / 1024 / 1024) + `" MB)`");`r`n" +
    "                string hex = BitConverter.ToString(bytes).Replace(`"-`",`"`");`r`n" +
    "                sb.AppendLine(`"[+] Hex OK`");`r`n" +
    "                string[,] pats = {`r`n" +
    "                    {`"6465662F6C61`",     `"FF68772F6C61`"},`r`n" +
    "                    {`"636C61726F2F6C61`", `"FFFFFF68772F6C61`"}`r`n" +
    "                };`r`n" +
    "                string[] patDesc = { `"def/la -> hw/la`", `"claro/la -> hw/la`" };`r`n" +
    "                int changed = 0;`r`n" +
    "                for (int p = 0; p < 2; p++) {`r`n" +
    "                    int hexPos = hex.IndexOf(pats[p,0], StringComparison.OrdinalIgnoreCase);`r`n" +
    "                    if (hexPos >= 0) {`r`n" +
    "                        // [MEJORA H] Log con offset exacto en bytes`r`n" +
    "                        int byteOffset = hexPos / 2;`r`n" +
    "                        string hexOrigBytes = pats[p,0].Length >= 2 ? pats[p,0].Substring(0, Math.Min(16, pats[p,0].Length)) : pats[p,0];`r`n" +
    "                        string hexNewBytes  = pats[p,1].Length >= 2 ? pats[p,1].Substring(0, Math.Min(16, pats[p,1].Length)) : pats[p,1];`r`n" +
    "                        sb.AppendLine(`"[+] Patron OK      : `" + patDesc[p]);`r`n" +
    "                        sb.AppendLine(`"    Offset         : 0x`" + byteOffset.ToString(`"X8`"));`r`n" +
    "                        sb.AppendLine(`"    Bytes orig     : `" + hexOrigBytes);`r`n" +
    "                        sb.AppendLine(`"    Bytes nuevo    : `" + hexNewBytes);`r`n" +
    "                        hex = hex.Replace(pats[p,0], pats[p,1]);`r`n" +
    "                        changed++;`r`n" +
    "                    }`r`n" +
    "                }`r`n" +
    "                if (changed > 0) {`r`n" +
    "                    byte[] nb = new byte[hex.Length / 2];`r`n" +
    "                    for (int i = 0; i < hex.Length; i += 2)`r`n" +
    "                        nb[i/2] = Convert.ToByte(hex.Substring(i,2),16);`r`n" +
    "                    if (!Directory.Exists(outDir)) Directory.CreateDirectory(outDir);`r`n" +
    "                    string fname  = Path.GetFileName(path);`r`n" +
    "                    string saveNew = Path.Combine(outDir, fname);`r`n" +
    "                    string saveBak = Path.Combine(outDir, fname + `".bak`");`r`n" +
    "                    // [MEJORA D] Guardar backup y VERIFICAR que se escribio correctamente`r`n" +
    "                    File.WriteAllBytes(saveBak, bytes);`r`n" +
    "                    long bakSize = new FileInfo(saveBak).Length;`r`n" +
    "                    if (bakSize != bytes.Length) {`r`n" +
    "                        sb.AppendLine(`"[!] ERROR CRITICO: Backup corrupto (`" + bakSize + `" != `" + bytes.Length + `" bytes). Abortando.`");`r`n" +
    "                        Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                    }`r`n" +
    "                    sb.AppendLine(`"[+] Backup verificado: `" + bakSize + `" bytes OK`");`r`n" +
    "                    // [MEJORA D] Archivo .meta.txt con info del backup`r`n" +
    "                    string metaPath = saveBak + `".meta.txt`";`r`n" +
    "                    string metaContent = `"=== RNX TOOL PRO v2.3 - BACKUP META ===\n`" +`r`n" +
    "                        `"Fecha    : `" + DateTime.Now.ToString(`"dd/MM/yyyy HH:mm:ss`") + `"\n`" +`r`n" +
    "                        `"Archivo  : `" + fname + `"\n`" +`r`n" +
    "                        `"Tamano   : `" + bytes.Length + `" bytes\n`" +`r`n" +
    "                        `"SHA256   : `" + sha256 + `"\n`" +`r`n" +
    "                        `"Tipo     : OEM Image\n`" +`r`n" +
    "                        `"Parches  : `" + changed + `"\n`";`r`n" +
    "                    File.WriteAllText(metaPath, metaContent, System.Text.Encoding.UTF8);`r`n" +
    "                    File.WriteAllBytes(saveNew, nb);`r`n" +
    "                    // [MEJORA C] Validacion post-parche: releer el archivo y verificar que los cambios existen`r`n" +
    "                    byte[] verify = File.ReadAllBytes(saveNew);`r`n" +
    "                    string hexVerify = BitConverter.ToString(verify).Replace(`"-`",`"`");`r`n" +
    "                    int confirmed = 0;`r`n" +
    "                    for (int p = 0; p < 2; p++) {`r`n" +
    "                        if (hexVerify.Contains(pats[p,1])) confirmed++;`r`n" +
    "                    }`r`n" +
    "                    sb.AppendLine(`"[+] Verificacion post-parche: `" + confirmed + `"/`" + changed + `" cambios confirmados en disco`");`r`n" +
    "                    if (confirmed < changed) {`r`n" +
    "                        sb.AppendLine(`"[!] ADVERTENCIA: Algunos cambios no se confirmaron al releer el archivo`");`r`n" +
    "                    } else {`r`n" +
    "                        sb.AppendLine(`"[+] Post-parche OK: todos los cambios verificados`");`r`n" +
    "                    }`r`n" +
    "                    // [MEJORA A] SHA256 del archivo modificado`r`n" +
    "                    string sha256New = CalcSHA256(nb);`r`n" +
    "                    sb.AppendLine(`"[+] SHA256 modificado: `" + sha256New.Substring(0,16) + `"...`");`r`n" +
    "                    sb.AppendLine(`"[+] Parches        : `" + changed);`r`n" +
    "                    sb.AppendLine(`"[+] Carpeta        : `" + outDir);`r`n" +
    "                    sb.AppendLine(`"[+] Modificado     : `" + fname);`r`n" +
    "                    sb.AppendLine(`"[+] Backup         : `" + fname + `".bak`");`r`n" +
    "                    sb.AppendLine(`"[+] Meta backup    : `" + fname + `".bak.meta.txt`");`r`n" +
    "                    sb.AppendLine(`"[OK] MODIFICACION EXITOSA.`");`r`n" +
    "                } else { sb.AppendLine(`"[?] Patrones no encontrados.`"); }`r`n" +
    "            } catch (Exception ex) { sb.AppendLine(`"[!] ERROR: `" + ex.Message); }`r`n" +
    "            sb.AppendLine(`"[=] ============================`");`r`n" +
    "            Q.Enqueue(sb.ToString());`r`n" +
    "            Done = true;`r`n" +
    "        }));`r`n" +
    "    }`r`n" +
    "}`r`n"
)
}

# ---- EfsPatcher: edicion binaria directa de efs.img / efs.bin ----
if (-not ("EfsPatcher" -as [type])) {
Add-Type -Language CSharp -TypeDefinition (
    "using System;`r`n" +
    "using System.IO;`r`n" +
    "using System.Text;`r`n" +
    "using System.Threading.Tasks;`r`n" +
    "using System.Collections.Concurrent;`r`n" +
    "using System.Security.Cryptography;`r`n" +
    "public static class EfsPatcher {`r`n" +
    "    public static ConcurrentQueue<string> Q = new ConcurrentQueue<string>();`r`n" +
    "    public static volatile bool Done = false;`r`n" +
    "    // [MEJORA A] Calcula SHA256`r`n" +
    "    private static string CalcSHA256(byte[] data) {`r`n" +
    "        using (var sha = SHA256.Create()) {`r`n" +
    "            byte[] h = sha.ComputeHash(data);`r`n" +
    "            return BitConverter.ToString(h).Replace(`"-`",`"`").ToLower();`r`n" +
    "        }`r`n" +
    "    }`r`n" +
    "    // [MEJORA H] ReplaceExact con offset exacto y hex dump`r`n" +
    "    private static int ReplaceExact(byte[] bytes, string oldName, string newName, StringBuilder sb) {`r`n" +
    "        byte[] needle = Encoding.ASCII.GetBytes(oldName);`r`n" +
    "        byte[] repl   = Encoding.ASCII.GetBytes(newName);`r`n" +
    "        int count = 0;`r`n" +
    "        for (int i = 0; i <= bytes.Length - needle.Length; i++) {`r`n" +
    "            bool match = true;`r`n" +
    "            for (int j = 0; j < needle.Length; j++) {`r`n" +
    "                if (bytes[i+j] != needle[j]) { match = false; break; }`r`n" +
    "            }`r`n" +
    "            if (!match) continue;`r`n" +
    "            // [MEJORA H] Capturar hex original antes de sobreescribir`r`n" +
    "            int dumpLen = Math.Min(needle.Length, 12);`r`n" +
    "            var hexOrigParts = new string[dumpLen];`r`n" +
    "            for (int k = 0; k < dumpLen; k++) hexOrigParts[k] = bytes[i+k].ToString(`"X2`");`r`n" +
    "            string hexOrig = string.Join(`" `", hexOrigParts) + (needle.Length > 12 ? `" ...`" : `"`");`r`n" +
    "            for (int j = 0; j < repl.Length; j++) bytes[i+j] = repl[j];`r`n" +
    "            var hexNewParts = new string[Math.Min(repl.Length, 12)];`r`n" +
    "            for (int k = 0; k < hexNewParts.Length; k++) hexNewParts[k] = bytes[i+k].ToString(`"X2`");`r`n" +
    "            string hexNew  = string.Join(`" `", hexNewParts) + (repl.Length > 12 ? `" ...`" : `"`");`r`n" +
    "            count++;`r`n" +
    "            sb.AppendLine(`"  [OK]  `" + oldName + `" -> `" + newName + `"  @ 0x`" + i.ToString(`"X8`"));`r`n" +
    "            sb.AppendLine(`"        bytes orig : `" + hexOrig);`r`n" +
    "            sb.AppendLine(`"        bytes nuevo: `" + hexNew);`r`n" +
    "        }`r`n" +
    "        if (count == 0) sb.AppendLine(`"  [SKIP] `" + oldName + `" (no encontrado)`");`r`n" +
    "        return count;`r`n" +
    "    }`r`n" +
    "    public static void Run(string path, string outDir) {`r`n" +
    "        Done = false;`r`n" +
    "        while (Q.Count > 0) { string x; Q.TryDequeue(out x); }`r`n" +
    "        Task.Run((System.Action)(() => {`r`n" +
    "            var sb = new StringBuilder();`r`n" +
    "            try {`r`n" +
    "                byte[] orig  = File.ReadAllBytes(path);`r`n" +
    "                byte[] bytes = (byte[])orig.Clone();`r`n" +
    "                sb.AppendLine(`"[+] Bytes leidos   : `" + bytes.Length);`r`n" +
    "                // [MEJORA A] SHA256 + validacion de tamano para EFS Samsung`r`n" +
    "                string sha256orig = CalcSHA256(orig);`r`n" +
    "                sb.AppendLine(`"[+] SHA256 original: `" + sha256orig.Substring(0,16) + `"...`");`r`n" +
    "                sb.AppendLine(`"[+] SHA256 completo: `" + sha256orig);`r`n" +
    "                if (orig.Length < 4 * 1024 * 1024) {`r`n" +
    "                    sb.AppendLine(`"[!] ABORTANDO: Archivo demasiado pequeno para ser un EFS Samsung (`" + orig.Length + `" bytes). Minimo: 4 MB.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                if (orig.Length > 64 * 1024 * 1024) {`r`n" +
    "                    sb.AppendLine(`"[!] ABORTANDO: Archivo demasiado grande (`" + orig.Length + `" bytes). Maximo: 64 MB.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] Validacion tamano: OK (`" + (orig.Length / 1024 / 1024) + `" MB)`");`r`n" +
    "                // [MEJORA A] Deteccion de variante EFS`r`n" +
    "                string rawStr = Encoding.GetEncoding(1252).GetString(bytes);`r`n" +
    "                string efsVariant = `"DESCONOCIDA`";`r`n" +
    "                if (rawStr.Contains(`"FactoryApp`")) efsVariant = `"Samsung v3 (A/S series moderno)`";`r`n" +
    "                else if (rawStr.Contains(`"mps_code`"))  efsVariant = `"Samsung v2 (serie clasica)`";`r`n" +
    "                else if (rawStr.Contains(`"nv_data`"))   efsVariant = `"Samsung v1 (serie legacy)`";`r`n" +
    "                bool hasEsim = rawStr.Contains(`"esim`") || rawStr.Contains(`"ESIM`");`r`n" +
    "                sb.AppendLine(`"[+] Variante EFS   : `" + efsVariant);`r`n" +
    "                sb.AppendLine(`"[+] eSIM presente  : `" + (hasEsim ? `"SI`" : `"NO`"));`r`n" +
    "                sb.AppendLine(`"[~] Buscando informacion del equipo en EFS...`");`r`n" +
    "                string imeiFound = `"`"; string serialFound = `"`"; string modelFound = `"`";`r`n" +
    "                var imeiM = System.Text.RegularExpressions.Regex.Match(rawStr, @`"(?<![0-9])([0-9]{15})(?![0-9])`");`r`n" +
    "                if (imeiM.Success) { imeiFound = imeiM.Value; sb.AppendLine(`"[+] IMEI detectado : `" + imeiFound); }`r`n" +
    "                var serM = System.Text.RegularExpressions.Regex.Match(rawStr, @`"serialno=([A-Za-z0-9]{8,20})`");`r`n" +
    "                if (serM.Success) { serialFound = serM.Groups[1].Value; sb.AppendLine(`"[+] Serial detectado: `" + serialFound); }`r`n" +
    "                var mdlM = System.Text.RegularExpressions.Regex.Match(rawStr, @`"ro\.product\.model=([^\x00\n\r]+)`");`r`n" +
    "                if (mdlM.Success) { modelFound = mdlM.Groups[1].Value.Trim(); sb.AppendLine(`"[+] Modelo detectado: `" + modelFound); }`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                int total = 0;`r`n" +
    "                total += ReplaceExact(bytes, `"esim.prop`",    `"000000000`",         sb);`r`n" +
    "                total += ReplaceExact(bytes, `"factory.prop`", `"000000000000`",      sb);`r`n" +
    "                total += ReplaceExact(bytes, `"wv.keys`",      `"0000000`",           sb);`r`n" +
    "                total += ReplaceExact(bytes, `"mps_code.dat`", `"000000000000_mps`",  sb);`r`n" +
    "                total += ReplaceExact(bytes, `"mep_mode`",     `"00000000`",          sb);`r`n" +
    "                if (!Directory.Exists(outDir)) Directory.CreateDirectory(outDir);`r`n" +
    "                string fname   = Path.GetFileName(path);`r`n" +
    "                string saveNew = Path.Combine(outDir, fname);`r`n" +
    "                string saveBak = Path.Combine(outDir, fname + `".bak`");`r`n" +
    "                // [MEJORA D] Guardar backup y verificar integridad`r`n" +
    "                File.WriteAllBytes(saveBak, orig);`r`n" +
    "                long bakSize = new FileInfo(saveBak).Length;`r`n" +
    "                if (bakSize != orig.Length) {`r`n" +
    "                    sb.AppendLine(`"[!] ERROR CRITICO: Backup corrupto (`" + bakSize + `" != `" + orig.Length + `" bytes). Abortando.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] Backup verificado: `" + bakSize + `" bytes OK`");`r`n" +
    "                // [MEJORA D] Archivo .meta.txt con fingerprint del backup`r`n" +
    "                string metaPath = saveBak + `".meta.txt`";`r`n" +
    "                var meta = new StringBuilder();`r`n" +
    "                meta.AppendLine(`"=== RNX TOOL PRO v2.3 - BACKUP META ===`");`r`n" +
    "                meta.AppendLine(`"Fecha    : `" + DateTime.Now.ToString(`"dd/MM/yyyy HH:mm:ss`"));`r`n" +
    "                meta.AppendLine(`"Archivo  : `" + fname);`r`n" +
    "                meta.AppendLine(`"Tamano   : `" + orig.Length + `" bytes`");`r`n" +
    "                meta.AppendLine(`"SHA256   : `" + sha256orig);`r`n" +
    "                meta.AppendLine(`"Variante : `" + efsVariant);`r`n" +
    "                meta.AppendLine(`"eSIM     : `" + (hasEsim ? `"SI`" : `"NO`"));`r`n" +
    "                if (imeiFound   != `"`") meta.AppendLine(`"IMEI     : `" + imeiFound);`r`n" +
    "                if (serialFound != `"`") meta.AppendLine(`"Serial   : `" + serialFound);`r`n" +
    "                if (modelFound  != `"`") meta.AppendLine(`"Modelo   : `" + modelFound);`r`n" +
    "                meta.AppendLine(`"Parches  : `" + total);`r`n" +
    "                File.WriteAllText(metaPath, meta.ToString(), Encoding.UTF8);`r`n" +
    "                File.WriteAllBytes(saveNew, bytes);`r`n" +
    "                // [MEJORA C] Validacion post-parche: releer y verificar que los nombres originales YA NO existen`r`n" +
    "                byte[] verify = File.ReadAllBytes(saveNew);`r`n" +
    "                string verifyStr = Encoding.GetEncoding(1252).GetString(verify);`r`n" +
    "                string[] origNames = { `"esim.prop`", `"factory.prop`", `"wv.keys`", `"mps_code.dat`", `"mep_mode`" };`r`n" +
    "                int confirmed = 0;`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                sb.AppendLine(`"[~] Verificacion post-parche:`");`r`n" +
    "                foreach (string n in origNames) {`r`n" +
    "                    bool stillPresent = verifyStr.Contains(n);`r`n" +
    "                    if (!stillPresent) { confirmed++; sb.AppendLine(`"  [OK] `" + n + `" eliminado del archivo`"); }`r`n" +
    "                    else { sb.AppendLine(`"  [!!] `" + n + `" TODAVIA presente (parche no aplicado)`"); }`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] Post-parche: `" + confirmed + `"/`" + origNames.Length + `" entradas eliminadas`");`r`n" +
    "                if (confirmed < total) sb.AppendLine(`"[!] ADVERTENCIA: Algunos parches no se confirmaron`");`r`n" +
    "                else sb.AppendLine(`"[+] Verificacion post-parche: TODOS LOS CAMBIOS CONFIRMADOS`");`r`n" +
    "                // [MEJORA A] SHA256 del archivo resultante`r`n" +
    "                string sha256new = CalcSHA256(bytes);`r`n" +
    "                sb.AppendLine(`"[+] SHA256 modificado: `" + sha256new.Substring(0,16) + `"...`");`r`n" +
    "                var info = new StringBuilder();`r`n" +
    "                info.AppendLine(`"=== RNX TOOL PRO - EFS INFO ===`");`r`n" +
    "                info.AppendLine(`"Archivo  : `" + fname);`r`n" +
    "                info.AppendLine(`"Fecha    : `" + DateTime.Now.ToString(`"dd/MM/yyyy HH:mm:ss`"));`r`n" +
    "                info.AppendLine(`"Variante : `" + efsVariant);`r`n" +
    "                info.AppendLine(`"eSIM     : `" + (hasEsim ? `"SI`" : `"NO`"));`r`n" +
    "                if (imeiFound   != `"`") info.AppendLine(`"IMEI     : `" + imeiFound);`r`n" +
    "                if (serialFound != `"`") info.AppendLine(`"Serial   : `" + serialFound);`r`n" +
    "                if (modelFound  != `"`") info.AppendLine(`"Modelo   : `" + modelFound);`r`n" +
    "                info.AppendLine(`"Parches  : `" + total);`r`n" +
    "                info.AppendLine(`"SHA256 orig: `" + sha256orig);`r`n" +
    "                info.AppendLine(`"SHA256 mod : `" + sha256new);`r`n" +
    "                File.WriteAllText(Path.Combine(outDir, `"efs_info.txt`"), info.ToString(), Encoding.UTF8);`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                sb.AppendLine(`"[+] Parches aplicados : `" + total);`r`n" +
    "                sb.AppendLine(`"[+] Backup original   : `" + fname + `".bak`");`r`n" +
    "                sb.AppendLine(`"[+] Meta backup       : `" + fname + `".bak.meta.txt`");`r`n" +
    "                sb.AppendLine(`"[+] Modificado        : `" + fname);`r`n" +
    "                sb.AppendLine(`"[+] Info equipo       : efs_info.txt`");`r`n" +
    "                sb.AppendLine(`"[+] Carpeta           : `" + outDir);`r`n" +
    "                sb.AppendLine(`"[OK] EFS EDITADO CORRECTAMENTE.`");`r`n" +
    "            } catch (Exception ex) { sb.AppendLine(`"[!] ERROR: `" + ex.Message); }`r`n" +
    "            sb.AppendLine(`"[=] ============================`");`r`n" +
    "            Q.Enqueue(sb.ToString());`r`n" +
    "            Done = true;`r`n" +
    "        }));`r`n" +
    "    }`r`n" +
    "}`r`n"
)
}

# ---- PersistPatcher: ext4 superblock+inode reader, navega fdsd->st, renombra st->rn ----
if (-not ("PersistPatcher" -as [type])) {
Add-Type -Language CSharp -TypeDefinition (
    "using System;`r`n" +
    "using System.IO;`r`n" +
    "using System.Text;`r`n" +
    "using System.Threading.Tasks;`r`n" +
    "using System.Collections.Concurrent;`r`n" +
    "using System.Collections.Generic;`r`n" +
    "using System.Security.Cryptography;`r`n" +
    "public static class PersistPatcher {`r`n" +
    "    public static ConcurrentQueue<string> Q = new ConcurrentQueue<string>();`r`n" +
    "    public static volatile bool Done = false;`r`n" +
    "    // [MEJORA A] Calcula SHA256`r`n" +
    "    private static string CalcSHA256(byte[] data) {`r`n" +
    "        using (var sha = SHA256.Create()) {`r`n" +
    "            byte[] h = sha.ComputeHash(data);`r`n" +
    "            return BitConverter.ToString(h).Replace(`"-`",`"`").ToLower();`r`n" +
    "        }`r`n" +
    "    }`r`n" +
    "    static uint LE32(byte[] b, int o) { return BitConverter.ToUInt32(b, o); }`r`n" +
    "    static ushort LE16(byte[] b, int o) { return BitConverter.ToUInt16(b, o); }`r`n" +
    "    static long GetInodeTableOffset(byte[] b, uint inode, uint ipg, uint isz, uint bsz, uint fdb) {`r`n" +
    "        uint grp = (inode - 1) / ipg;`r`n" +
    "        uint idx = (inode - 1) % ipg;`r`n" +
    "        uint gdtBlock = fdb + 1;`r`n" +
    "        long gdtOff  = (long)gdtBlock * bsz + (long)grp * 32;`r`n" +
    "        uint itBlock = LE32(b, (int)gdtOff + 8);`r`n" +
    "        return (long)itBlock * bsz + (long)idx * isz;`r`n" +
    "    }`r`n" +
    "    static int[] GetInodeBlocks(byte[] b, long inodeOff, uint bsz) {`r`n" +
    "        List<int> blocks = new List<int>();`r`n" +
    "        uint flags = LE32(b, (int)inodeOff + 0x20);`r`n" +
    "        bool extents = (flags & 0x80000) != 0;`r`n" +
    "        if (extents) {`r`n" +
    "            int eh = (int)inodeOff + 0x28;`r`n" +
    "            ushort entries = LE16(b, eh + 2);`r`n" +
    "            ushort depth   = LE16(b, eh + 6);`r`n" +
    "            if (depth == 0) {`r`n" +
    "                for (int e = 0; e < entries; e++) {`r`n" +
    "                    int eOff  = eh + 12 + e * 12;`r`n" +
    "                    ushort len   = LE16(b, eOff + 4);`r`n" +
    "                    uint   start = LE32(b, eOff + 8);`r`n" +
    "                    for (int k = 0; k < len; k++) blocks.Add((int)(start + k));`r`n" +
    "                }`r`n" +
    "            } else {`r`n" +
    "                for (int e = 0; e < entries; e++) {`r`n" +
    "                    int  iOff    = eh + 12 + e * 12;`r`n" +
    "                    uint leafBlk = LE32(b, iOff + 8);`r`n" +
    "                    long leafOff = (long)leafBlk * bsz;`r`n" +
    "                    if (leafOff + 12 > b.Length) continue;`r`n" +
    "                    ushort lEntries = LE16(b, (int)leafOff + 2);`r`n" +
    "                    for (int le = 0; le < lEntries; le++) {`r`n" +
    "                        int    leOff  = (int)leafOff + 12 + le * 12;`r`n" +
    "                        ushort lLen   = LE16(b, leOff + 4);`r`n" +
    "                        uint   lStart = LE32(b, leOff + 8);`r`n" +
    "                        for (int k = 0; k < lLen; k++) blocks.Add((int)(lStart + k));`r`n" +
    "                    }`r`n" +
    "                }`r`n" +
    "            }`r`n" +
    "        } else {`r`n" +
    "            for (int i = 0; i < 12; i++) {`r`n" +
    "                uint blk = LE32(b, (int)inodeOff + 0x28 + i * 4);`r`n" +
    "                if (blk > 0) blocks.Add((int)blk);`r`n" +
    "            }`r`n" +
    "        }`r`n" +
    "        return blocks.ToArray();`r`n" +
    "    }`r`n" +
    "    static int SearchDirent(byte[] b, int blkOff, int blkSize, string name, out uint foundInode) {`r`n" +
    "        byte[] needle = Encoding.ASCII.GetBytes(name);`r`n" +
    "        foundInode = 0;`r`n" +
    "        int pos = blkOff;`r`n" +
    "        int end = blkOff + blkSize;`r`n" +
    "        while (pos < end - 8) {`r`n" +
    "            uint   ino    = LE32(b, pos);`r`n" +
    "            ushort recLen = LE16(b, pos + 4);`r`n" +
    "            byte   nLen   = b[pos + 6];`r`n" +
    "            if (recLen < 8) break;`r`n" +
    "            if (ino > 0 && nLen == needle.Length && pos + 8 + nLen <= end) {`r`n" +
    "                bool match = true;`r`n" +
    "                for (int j = 0; j < nLen; j++) {`r`n" +
    "                    if (b[pos + 8 + j] != needle[j]) { match = false; break; }`r`n" +
    "                }`r`n" +
    "                if (match) { foundInode = ino; return pos + 8; }`r`n" +
    "            }`r`n" +
    "            pos += recLen;`r`n" +
    "        }`r`n" +
    "        return -1;`r`n" +
    "    }`r`n" +
    "    public static void Run(string path, string outDir) {`r`n" +
    "        Done = false;`r`n" +
    "        while (Q.Count > 0) { string x; Q.TryDequeue(out x); }`r`n" +
    "        Task.Run((System.Action)(() => {`r`n" +
    "            var sb = new StringBuilder();`r`n" +
    "            try {`r`n" +
    "                byte[] orig  = File.ReadAllBytes(path);`r`n" +
    "                byte[] bytes = (byte[])orig.Clone();`r`n" +
    "                sb.AppendLine(`"[+] Bytes leidos    : `" + bytes.Length);`r`n" +
    "                // [MEJORA A] SHA256 + validacion de tamano para Persist Xiaomi`r`n" +
    "                string sha256orig = CalcSHA256(orig);`r`n" +
    "                sb.AppendLine(`"[+] SHA256 original : `" + sha256orig.Substring(0,16) + `"...`");`r`n" +
    "                sb.AppendLine(`"[+] SHA256 completo : `" + sha256orig);`r`n" +
    "                if (orig.Length < 512 * 1024) {`r`n" +
    "                    sb.AppendLine(`"[!] ABORTANDO: Archivo demasiado pequeno para Persist (`" + orig.Length + `" bytes). Minimo: 512 KB.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                if (orig.Length > 128 * 1024 * 1024) {`r`n" +
    "                    sb.AppendLine(`"[!] ABORTANDO: Archivo demasiado grande (`" + orig.Length + `" bytes). Maximo: 128 MB.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] Validacion tamano: OK (`" + (orig.Length / 1024) + `" KB)`");`r`n" +
    "                int sbOff = 0x400;`r`n" +
    "                bool isExt4 = (bytes.Length > sbOff + 0x3A && bytes[sbOff + 0x38] == 0x53 && bytes[sbOff + 0x39] == 0xEF);`r`n" +
    "                sb.AppendLine(`"[+] Filesystem      : `" + (isExt4 ? `"ext4 (OK)`" : `"no ext4`"));`r`n" +
    "                if (!isExt4) { sb.AppendLine(`"[!] Abortando: no es ext4`"); Q.Enqueue(sb.ToString()); Done = true; return; }`r`n" +
    "                uint bsz  = (uint)(1024 << (int)LE32(bytes, sbOff + 0x18));`r`n" +
    "                uint ipg  = LE32(bytes, sbOff + 0x28);`r`n" +
    "                uint isz  = (uint)LE16(bytes, sbOff + 0x58);`r`n" +
    "                uint fdb  = LE32(bytes, sbOff + 0x14);`r`n" +
    "                sb.AppendLine(`"[+] blockSize       : `" + bsz);`r`n" +
    "                sb.AppendLine(`"[+] inodesPerGroup  : `" + ipg);`r`n" +
    "                sb.AppendLine(`"[+] inodeSize       : `" + isz);`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                sb.AppendLine(`"[~] Leyendo root inode (2)...`");`r`n" +
    "                long rootOff = GetInodeTableOffset(bytes, 2, ipg, isz, bsz, fdb);`r`n" +
    "                sb.AppendLine(`"[+] root inode off  : 0x`" + rootOff.ToString(`"X8`"));`r`n" +
    "                int[] rootBlks = GetInodeBlocks(bytes, rootOff, bsz);`r`n" +
    "                sb.AppendLine(`"[+] root bloques    : `" + rootBlks.Length);`r`n" +
    "                int fdsdNameOff = -1;`r`n" +
    "                uint fdsdInode  = 0;`r`n" +
    "                foreach (int blk in rootBlks) {`r`n" +
    "                    long bo = (long)blk * bsz;`r`n" +
    "                    if (bo + bsz > bytes.Length) continue;`r`n" +
    "                    uint fi = 0;`r`n" +
    "                    int r = SearchDirent(bytes, (int)bo, (int)bsz, `"fdsd`", out fi);`r`n" +
    "                    if (r >= 0) { fdsdNameOff = r; fdsdInode = fi; break; }`r`n" +
    "                }`r`n" +
    "                if (fdsdNameOff < 0) {`r`n" +
    "                    sb.AppendLine(`"[!] fdsd no encontrado en root`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] fdsd inode      : `" + fdsdInode + `"  name-off: 0x`" + fdsdNameOff.ToString(`"X8`"));`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                sb.AppendLine(`"[~] Leyendo inode fdsd...`");`r`n" +
    "                long fdsdOff  = GetInodeTableOffset(bytes, fdsdInode, ipg, isz, bsz, fdb);`r`n" +
    "                int[] fdsdBlks = GetInodeBlocks(bytes, fdsdOff, bsz);`r`n" +
    "                sb.AppendLine(`"[+] fdsd bloques    : `" + fdsdBlks.Length);`r`n" +
    "                int stNameOff = -1;`r`n" +
    "                uint stInode  = 0;`r`n" +
    "                foreach (int blk in fdsdBlks) {`r`n" +
    "                    long bo = (long)blk * bsz;`r`n" +
    "                    if (bo + bsz > bytes.Length) continue;`r`n" +
    "                    uint si = 0;`r`n" +
    "                    int r = SearchDirent(bytes, (int)bo, (int)bsz, `"st`", out si);`r`n" +
    "                    if (r >= 0) { stNameOff = r; stInode = si; break; }`r`n" +
    "                }`r`n" +
    "                if (stNameOff < 0) {`r`n" +
    "                    sb.AppendLine(`"[!] st no encontrado en fdsd`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                // [MEJORA H] Capturar bytes originales antes de modificar`r`n" +
    "                byte origByte0 = bytes[stNameOff];`r`n" +
    "                byte origByte1 = bytes[stNameOff + 1];`r`n" +
    "                bytes[stNameOff]     = (byte)'r';`r`n" +
    "                bytes[stNameOff + 1] = (byte)'n';`r`n" +
    "                sb.AppendLine(`"  [OK] st -> rn  @ 0x`" + stNameOff.ToString(`"X8`") + `"  inode=`" + stInode);`r`n" +
    "                sb.AppendLine(`"        bytes orig : `" + origByte0.ToString(`"X2`") + `" `" + origByte1.ToString(`"X2`") + `"  (ASCII: '`" + (char)origByte0 + (char)origByte1 + `"')`");`r`n" +
    "                sb.AppendLine(`"        bytes nuevo: `" + ((byte)'r').ToString(`"X2`") + `" `" + ((byte)'n').ToString(`"X2`") + `"  (ASCII: 'rn')`");`r`n" +
    "                if (!Directory.Exists(outDir)) Directory.CreateDirectory(outDir);`r`n" +
    "                string fname   = Path.GetFileName(path);`r`n" +
    "                string saveBak = Path.Combine(outDir, fname + `".bak`");`r`n" +
    "                string saveNew = Path.Combine(outDir, fname);`r`n" +
    "                // [MEJORA D] Backup verificado`r`n" +
    "                File.WriteAllBytes(saveBak, orig);`r`n" +
    "                long bakSize = new FileInfo(saveBak).Length;`r`n" +
    "                if (bakSize != orig.Length) {`r`n" +
    "                    sb.AppendLine(`"[!] ERROR CRITICO: Backup corrupto (`" + bakSize + `" != `" + orig.Length + `" bytes). Abortando.`");`r`n" +
    "                    Q.Enqueue(sb.ToString()); Done = true; return;`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[+] Backup verificado: `" + bakSize + `" bytes OK`");`r`n" +
    "                // [MEJORA D] Meta archivo con fingerprint del backup`r`n" +
    "                string metaPath = saveBak + `".meta.txt`";`r`n" +
    "                string metaContent = `"=== RNX TOOL PRO v2.3 - BACKUP META ===\n`" +`r`n" +
    "                    `"Fecha    : `" + DateTime.Now.ToString(`"dd/MM/yyyy HH:mm:ss`") + `"\n`" +`r`n" +
    "                    `"Archivo  : `" + fname + `"\n`" +`r`n" +
    "                    `"Tamano   : `" + orig.Length + `" bytes\n`" +`r`n" +
    "                    `"SHA256   : `" + sha256orig + `"\n`" +`r`n" +
    "                    `"Tipo     : Persist ext4 (Xiaomi/Redmi/POCO)\n`" +`r`n" +
    "                    `"Offset   : 0x`" + stNameOff.ToString(`"X8`") + `"\n`" +`r`n" +
    "                    `"Cambio   : st -> rn (inode=`" + stInode + `")\n`";`r`n" +
    "                File.WriteAllText(metaPath, metaContent, Encoding.UTF8);`r`n" +
    "                File.WriteAllBytes(saveNew, bytes);`r`n" +
    "                // [MEJORA C] Validacion post-parche: verificar que el cambio 'st'->'rn' existe en el archivo guardado`r`n" +
    "                byte[] verify = File.ReadAllBytes(saveNew);`r`n" +
    "                bool postOk = (verify[stNameOff] == (byte)'r' && verify[stNameOff + 1] == (byte)'n');`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                sb.AppendLine(`"[~] Verificacion post-parche:`");`r`n" +
    "                if (postOk) {`r`n" +
    "                    sb.AppendLine(`"  [OK] Offset 0x`" + stNameOff.ToString(`"X8`") + `": 'rn' confirmado en disco`");`r`n" +
    "                    sb.AppendLine(`"[+] Verificacion post-parche: CAMBIO CONFIRMADO`");`r`n" +
    "                } else {`r`n" +
    "                    sb.AppendLine(`"  [!!] ADVERTENCIA: El cambio no se confirmo al releer el archivo`");`r`n" +
    "                    sb.AppendLine(`"  [!!] Byte en offset: `" + verify[stNameOff].ToString(`"X2`") + `" `" + verify[stNameOff+1].ToString(`"X2`") + `" (esperado: 72 6E)`");`r`n" +
    "                }`r`n" +
    "                // [MEJORA A] SHA256 del archivo modificado`r`n" +
    "                string sha256new = CalcSHA256(bytes);`r`n" +
    "                sb.AppendLine(`"[+] SHA256 modificado: `" + sha256new.Substring(0,16) + `"...`");`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                sb.AppendLine(`"[+] Backup          : `" + fname + `".bak`");`r`n" +
    "                sb.AppendLine(`"[+] Meta backup     : `" + fname + `".bak.meta.txt`");`r`n" +
    "                sb.AppendLine(`"[+] Modificado      : `" + fname);`r`n" +
    "                sb.AppendLine(`"[+] Carpeta         : `" + outDir);`r`n" +
    "                sb.AppendLine(`"[OK] PERSIST EDITADO CORRECTAMENTE.`");`r`n" +
    "            } catch (Exception ex) { sb.AppendLine(`"[!] ERROR: `" + ex.Message); }`r`n" +
    "            sb.AppendLine(`"[=] ============================`");`r`n" +
    "            Q.Enqueue(sb.ToString());`r`n" +
    "            Done = true;`r`n" +
    "        }));`r`n" +
    "    }`r`n" +
    "}`r`n"
)
}

# ---- ModemMiPatcher: edita modem.img/modem.bin, FAT16/FAT32, entra a /image, renombra CARDAPP.* -> 00000000.000 ----
if (-not ("ModemMiPatcher" -as [type])) {
Add-Type -Language CSharp -TypeDefinition (
    "using System;`r`n" +
    "using System.IO;`r`n" +
    "using System.Text;`r`n" +
    "using System.Threading.Tasks;`r`n" +
    "using System.Collections.Concurrent;`r`n" +
    "using System.Collections.Generic;`r`n" +
    "using System.Security.Cryptography;`r`n" +
    "public static class ModemMiPatcher {`r`n" +
    "    public static ConcurrentQueue<string> Q = new ConcurrentQueue<string>();`r`n" +
    "    public static volatile bool Done = false;`r`n" +
    "    private static string CalcSHA256(byte[] data) {`r`n" +
    "        using (var sha = SHA256.Create()) {`r`n" +
    "            byte[] h = sha.ComputeHash(data);`r`n" +
    "            return BitConverter.ToString(h).Replace(`"-`",`"`").ToLower();`r`n" +
    "        }`r`n" +
    "    }`r`n" +
    "    static ushort LE16(byte[] b, int o) { return BitConverter.ToUInt16(b, o); }`r`n" +
    "    static uint   LE32(byte[] b, int o) { return BitConverter.ToUInt32(b, o); }`r`n" +
    "    // Encuentra el offset base del FAT en el imagen (soporta raw FAT e imagen con MBR)`r`n" +
    "    static int FindFatBase(byte[] img, StringBuilder sb) {`r`n" +
    "        // Buscar boot sector FAT: magic 55 AA en offset 510, OEM 'MSDOS5.0' o similar`r`n" +
    "        for (int scan = 0; scan < Math.Min(img.Length, 64 * 1024 * 1024); scan += 512) {`r`n" +
    "            if (scan + 512 > img.Length) break;`r`n" +
    "            // FAT boot sector signature`r`n" +
    "            if (img[scan + 510] == 0x55 && img[scan + 511] == 0xAA) {`r`n" +
    "                // Verificar que es un BPB valido: bytes_per_sector debe ser 512/1024/2048/4096`r`n" +
    "                int bps = LE16(img, scan + 11);`r`n" +
    "                int spc = img[scan + 13];`r`n" +
    "                if ((bps == 512 || bps == 1024 || bps == 2048 || bps == 4096) && spc > 0 && spc <= 128) {`r`n" +
    "                    string fatType = `"`";`r`n" +
    "                    if (scan + 62 + 8 <= img.Length) fatType = System.Text.Encoding.ASCII.GetString(img, scan + 54, 8).Trim();`r`n" +
    "                    sb.AppendLine(`"[+] FAT boot sector encontrado en offset 0x`" + scan.ToString(`"X8`") + `" | tipo: '`" + fatType + `"' | BPS=`" + bps + `" SPC=`" + spc);`r`n" +
    "                    return scan;`r`n" +
    "                }`r`n" +
    "            }`r`n" +
    "        }`r`n" +
    "        return -1;`r`n" +
    "    }`r`n" +
    "    static int RenameCardappsInFat(byte[] img, int fatBase, StringBuilder sb) {`r`n" +
    "        // Leer BPB (BIOS Parameter Block) del boot sector`r`n" +
    "        int bps  = LE16(img, fatBase + 11);  // bytes per sector`r`n" +
    "        int spc  = img[fatBase + 13];         // sectors per cluster`r`n" +
    "        int res  = LE16(img, fatBase + 14);   // reserved sectors`r`n" +
    "        int nf   = img[fatBase + 16];         // number of FATs`r`n" +
    "        int rc   = LE16(img, fatBase + 17);   // root entry count (FAT16; 0 for FAT32)`r`n" +
    "        int fsz16 = LE16(img, fatBase + 22);  // FAT size sectors (FAT16)`r`n" +
    "        uint fsz32 = LE32(img, fatBase + 36); // FAT size sectors (FAT32)`r`n" +
    "        int fsz  = (fsz16 != 0) ? fsz16 : (int)fsz32;`r`n" +
    "        int cs   = spc * bps;                 // cluster size in bytes`r`n" +
    "        bool isFat32 = (rc == 0);`r`n" +
    "        sb.AppendLine(`"[+] FAT type      : `" + (isFat32 ? `"FAT32`" : `"FAT16`"));`r`n" +
    "        sb.AppendLine(`"[+] bytes/sector  : `" + bps);`r`n" +
    "        sb.AppendLine(`"[+] sectors/clust : `" + spc);`r`n" +
    "        sb.AppendLine(`"[+] cluster size  : `" + cs + `" bytes`");`r`n" +
    "        sb.AppendLine(`"[+] num FATs      : `" + nf);`r`n" +
    "        sb.AppendLine(`"[+] FAT size      : `" + fsz + `" sectors`");`r`n" +
    "        sb.AppendLine(`"[+] root entries  : `" + rc);`r`n" +
    "        // Calcular offsets clave`r`n" +
    "        long fat1Off  = fatBase + (long)res * bps;`r`n" +
    "        long rootOff  = fat1Off + (long)nf * fsz * bps;`r`n" +
    "        long dataOff  = isFat32 ? rootOff : rootOff + (long)rc * 32;`r`n" +
    "        uint rootClust32 = isFat32 ? LE32(img, fatBase + 44) : 0;`r`n" +
    "        sb.AppendLine(`"[+] FAT1 offset   : 0x`" + fat1Off.ToString(`"X8`"));`r`n" +
    "        sb.AppendLine(`"[+] Root dir off  : 0x`" + rootOff.ToString(`"X8`"));`r`n" +
    "        sb.AppendLine(`"[+] Data area off : 0x`" + dataOff.ToString(`"X8`"));`r`n" +
    "        sb.AppendLine(`"`");`r`n" +
    "        // Funcion para leer siguiente cluster de la FAT`r`n" +
    "        // FAT16: entry = 2 bytes; FAT32: entry = 4 bytes (28 bits validos)`r`n" +
    "        // Retorna 0xFFFF (FAT16) / 0x0FFFFFFF (FAT32) para fin de cadena`r`n" +
    "        // Funcion lambda no soportada en C# antiguo - usamos metodo local via delegate`r`n" +
    "        // Para simplificar, inline el calculo`r`n" +
    "        // Cluster offset calculator`r`n" +
    "        // Renombrar CARDAPP en un bloque de directorio (offset + tamanio en bytes)`r`n" +
    "        int totalRenamed = 0;`r`n" +
    "        byte[] cardappBytes = System.Text.Encoding.ASCII.GetBytes(`"CARDAPP`");`r`n" +
    "        // Funcion de escaneo de un bloque de directorio FAT`r`n" +
    "        // Cada entrada = 32 bytes. Nombre[0:8] + Ext[8:11] + Attr[11] + ..`r`n" +
    "        // Si nombre[0]==0x00: fin. Si nombre[0]==0xE5: eliminado. Si attr==0x0F: LFN.`r`n" +
    "        System.Action<long, int> scanDirBlock = null;`r`n" +
    "        scanDirBlock = (long blockOff, int blockSize) => {`r`n" +
    "            for (int e = 0; e < blockSize / 32; e++) {`r`n" +
    "                long eOff = blockOff + e * 32L;`r`n" +
    "                if (eOff + 32 > img.Length) break;`r`n" +
    "                byte b0   = img[eOff];`r`n" +
    "                if (b0 == 0x00) break;   // fin de directorio`r`n" +
    "                if (b0 == 0xE5) continue; // entrada eliminada`r`n" +
    "                byte attr = img[eOff + 11];`r`n" +
    "                if (attr == 0x0F) continue; // LFN`r`n" +
    "                // Comprobar si el nombre comienza con CARDAPP (7 bytes)`r`n" +
    "                bool isCardapp = true;`r`n" +
    "                for (int k = 0; k < cardappBytes.Length; k++) {`r`n" +
    "                    if (img[eOff + k] != cardappBytes[k]) { isCardapp = false; break; }`r`n" +
    "                }`r`n" +
    "                if (!isCardapp) continue;`r`n" +
    "                // Leer nombre original para el log`r`n" +
    "                string origName8 = System.Text.Encoding.ASCII.GetString(img, (int)eOff, 8).TrimEnd();`r`n" +
    "                string origExt3  = System.Text.Encoding.ASCII.GetString(img, (int)eOff + 8, 3).TrimEnd();`r`n" +
    "                string origFull  = origExt3.Length > 0 ? origName8 + `".`" + origExt3 : origName8;`r`n" +
    "                string hexOrig   = BitConverter.ToString(img, (int)eOff, 11).Replace(`"-`",`" `");`r`n" +
    "                // Renombrar: nombre -> '00000000', extension -> '000'`r`n" +
    "                for (int k = 0; k < 8;  k++) img[eOff + k]     = (byte)'0';`r`n" +
    "                for (int k = 0; k < 3;  k++) img[eOff + 8 + k] = (byte)'0';`r`n" +
    "                totalRenamed++;`r`n" +
    "                sb.AppendLine(`"  [OK] '`" + origFull + `"' -> '00000000.000'  @ 0x`" + eOff.ToString(`"X8`"));`r`n" +
    "                sb.AppendLine(`"       hex orig: `" + hexOrig);`r`n" +
    "            }`r`n" +
    "        };`r`n" +
    "        // Buscar directorio 'IMAGE' en el root`r`n" +
    "        // Para FAT16: root dir es un bloque fijo en rootOff con rc entradas`r`n" +
    "        // Para FAT32: root dir sigue cadena de clusters desde rootClust32`r`n" +
    "        sb.AppendLine(`"[~] Buscando directorio 'IMAGE' en root...`");`r`n" +
    "        byte[] imageName = System.Text.Encoding.ASCII.GetBytes(`"IMAGE   `"); // 8 bytes padded`r`n" +
    "        uint imageCluster = 0;`r`n" +
    "        long searchRootOff = rootOff;`r`n" +
    "        int  searchRootSz  = rc * 32;`r`n" +
    "        if (isFat32) { searchRootOff = dataOff + (long)(rootClust32 - 2) * cs; searchRootSz = cs; }`r`n" +
    "        for (int e = 0; e < searchRootSz / 32; e++) {`r`n" +
    "            long eOff = searchRootOff + e * 32L;`r`n" +
    "            if (eOff + 32 > img.Length) break;`r`n" +
    "            if (img[eOff] == 0x00) break;`r`n" +
    "            if (img[eOff] == 0xE5) continue;`r`n" +
    "            byte attr = img[eOff + 11];`r`n" +
    "            if (attr == 0x0F) continue;`r`n" +
    "            bool isDir = (attr & 0x10) != 0;`r`n" +
    "            if (!isDir) continue;`r`n" +
    "            bool nameMatch = true;`r`n" +
    "            for (int k = 0; k < 8; k++) { if (img[eOff + k] != imageName[k]) { nameMatch = false; break; } }`r`n" +
    "            if (nameMatch) {`r`n" +
    "                imageCluster = isFat32 ? (uint)((LE16(img,(int)eOff+20) << 16) | LE16(img,(int)eOff+26)) : LE16(img,(int)eOff+26);`r`n" +
    "                sb.AppendLine(`"[+] Directorio /image encontrado - cluster=`" + imageCluster);`r`n" +
    "                break;`r`n" +
    "            }`r`n" +
    "        }`r`n" +
    "        if (imageCluster == 0) {`r`n" +
    "            sb.AppendLine(`"[!] Directorio 'IMAGE' no encontrado en root`");`r`n" +
    "            sb.AppendLine(`"[~] Escaneando root y data area completa buscando CARDAPP...`");`r`n" +
    "            // Fallback: escanear todo el area de directorio root`r`n" +
    "            scanDirBlock(searchRootOff, searchRootSz);`r`n" +
    "            // Y escanear toda el area de datos en bloques de cluster_size`r`n" +
    "            for (long off = dataOff; off + cs <= img.Length; off += cs)`r`n" +
    "                scanDirBlock(off, cs);`r`n" +
    "        } else {`r`n" +
    "            // Seguir cadena FAT del directorio /image`r`n" +
    "            var visited = new HashSet<uint>();`r`n" +
    "            uint clust = imageCluster;`r`n" +
    "            while (clust >= 2 && !visited.Contains(clust)) {`r`n" +
    "                visited.Add(clust);`r`n" +
    "                long clustOff = dataOff + (long)(clust - 2) * cs;`r`n" +
    "                if (clustOff + cs > img.Length) break;`r`n" +
    "                sb.AppendLine(`"[~] Escaneando cluster `" + clust + `" @ 0x`" + clustOff.ToString(`"X8`"));`r`n" +
    "                scanDirBlock(clustOff, cs);`r`n" +
    "                // Siguiente cluster de la FAT`r`n" +
    "                long fatEntOff = fat1Off + (isFat32 ? (long)clust * 4 : (long)clust * 2);`r`n" +
    "                if (fatEntOff + (isFat32 ? 4 : 2) > img.Length) break;`r`n" +
    "                uint nextClust = isFat32 ? (LE32(img, (int)fatEntOff) & 0x0FFFFFFF) : LE16(img, (int)fatEntOff);`r`n" +
    "                if (isFat32 ? nextClust >= 0x0FFFFFF8u : nextClust >= 0xFFF8u) break;`r`n" +
    "                clust = nextClust;`r`n" +
    "            }`r`n" +
    "        }`r`n" +
    "        sb.AppendLine(`"`");`r`n" +
    "        sb.AppendLine(`"[+] Total CARDAPP renombrados: `" + totalRenamed);`r`n" +
    "        return totalRenamed;`r`n" +
    "    }`r`n" +
    "    static void ProcessFile(string path, string outDir, StringBuilder sb) {`r`n" +
    "        sb.AppendLine(`"[*] ===== MODEM MI ACCOUNT =====`");`r`n" +
    "        sb.AppendLine(`"[*] Archivo: `" + path);`r`n" +
    "        if (!File.Exists(path)) { sb.AppendLine(`"[!] ARCHIVO NO ENCONTRADO: `" + path); return; }`r`n" +
    "        byte[] orig  = File.ReadAllBytes(path);`r`n" +
    "        byte[] bytes = (byte[])orig.Clone();`r`n" +
    "        sb.AppendLine(`"[+] Bytes leidos    : `" + bytes.Length);`r`n" +
    "        string sha256orig = CalcSHA256(orig);`r`n" +
    "        sb.AppendLine(`"[+] SHA256 original : `" + sha256orig.Substring(0,16) + `"...`");`r`n" +
    "        sb.AppendLine(`"[+] SHA256 completo : `" + sha256orig);`r`n" +
    "        if (orig.Length < 1 * 1024 * 1024) {`r`n" +
    "            sb.AppendLine(`"[!] ABORTANDO: Archivo muy pequeno (`" + orig.Length + `" bytes). Minimo: 1 MB.`"); return;`r`n" +
    "        }`r`n" +
    "        sb.AppendLine(`"[+] Tamano: OK (`" + (orig.Length / 1024 / 1024) + `" MB)`");`r`n" +
    "        // Detectar FAT boot sector`r`n" +
    "        int fatBase = FindFatBase(bytes, sb);`r`n" +
    "        if (fatBase < 0) {`r`n" +
    "            sb.AppendLine(`"[!] ABORTANDO: No se encontro FAT boot sector en el archivo.`");`r`n" +
    "            sb.AppendLine(`"[!] Asegurate de seleccionar el archivo modem.img / modem.bin correcto.`");`r`n" +
    "            return;`r`n" +
    "        }`r`n" +
    "        int totalRenamed = RenameCardappsInFat(bytes, fatBase, sb);`r`n" +
    "        if (totalRenamed == 0) {`r`n" +
    "            sb.AppendLine(`"[!] No se encontraron entradas CARDAPP en el filesystem FAT.`");`r`n" +
    "            sb.AppendLine(`"[~] El archivo puede no ser compatible o ya fue modificado.`");`r`n" +
    "            return;`r`n" +
    "        }`r`n" +
    "        // Guardar con backup verificado + meta`r`n" +
    "        if (!Directory.Exists(outDir)) Directory.CreateDirectory(outDir);`r`n" +
    "        string fname   = Path.GetFileName(path);`r`n" +
    "        string saveBak = Path.Combine(outDir, fname + `".bak`");`r`n" +
    "        string saveNew = Path.Combine(outDir, fname);`r`n" +
    "        File.WriteAllBytes(saveBak, orig);`r`n" +
    "        long bakSize = new FileInfo(saveBak).Length;`r`n" +
    "        if (bakSize != orig.Length) {`r`n" +
    "            sb.AppendLine(`"[!] ERROR CRITICO: Backup corrupto (`" + bakSize + `" != `" + orig.Length + `"). Abortando.`"); return;`r`n" +
    "        }`r`n" +
    "        sb.AppendLine(`"[+] Backup verificado: `" + bakSize + `" bytes OK`");`r`n" +
    "        // Meta archivo`r`n" +
    "        string metaPath = saveBak + `".meta.txt`";`r`n" +
    "        var meta = new StringBuilder();`r`n" +
    "        meta.AppendLine(`"=== RNX TOOL PRO v2.3 - BACKUP META ===`");`r`n" +
    "        meta.AppendLine(`"Fecha      : `" + DateTime.Now.ToString(`"dd/MM/yyyy HH:mm:ss`"));`r`n" +
    "        meta.AppendLine(`"Archivo    : `" + fname);`r`n" +
    "        meta.AppendLine(`"Tamano     : `" + orig.Length + `" bytes`");`r`n" +
    "        meta.AppendLine(`"SHA256     : `" + sha256orig);`r`n" +
    "        meta.AppendLine(`"Tipo       : Modem FAT16/FAT32 - CARDAPP rename (MI ACCOUNT)`");`r`n" +
    "        meta.AppendLine(`"Renombrados: `" + totalRenamed);`r`n" +
    "        File.WriteAllText(metaPath, meta.ToString(), Encoding.UTF8);`r`n" +
    "        File.WriteAllBytes(saveNew, bytes);`r`n" +
    "        // Validacion post-parche`r`n" +
    "        byte[] verify = File.ReadAllBytes(saveNew);`r`n" +
    "        bool anyLeft = false;`r`n" +
    "        byte[] chk = System.Text.Encoding.ASCII.GetBytes(`"CARDAPP`");`r`n" +
    "        for (int i = 0; i <= verify.Length - chk.Length; i++) {`r`n" +
    "            bool m = true;`r`n" +
    "            for (int j = 0; j < chk.Length; j++) { if (verify[i+j] != chk[j]) { m=false; break; } }`r`n" +
    "            if (m) { anyLeft = true; break; }`r`n" +
    "        }`r`n" +
    "        string sha256new = CalcSHA256(bytes);`r`n" +
    "        sb.AppendLine(`"[~] Verificacion post-parche:`");`r`n" +
    "        if (!anyLeft) {`r`n" +
    "            sb.AppendLine(`"  [OK] No quedan entradas CARDAPP en el archivo guardado`");`r`n" +
    "            sb.AppendLine(`"[+] POST-PARCHE: TODOS LOS CAMBIOS CONFIRMADOS`");`r`n" +
    "        } else {`r`n" +
    "            sb.AppendLine(`"  [!!] ADVERTENCIA: Aun existen bytes CARDAPP en el archivo`");`r`n" +
    "        }`r`n" +
    "        sb.AppendLine(`"[+] SHA256 modificado: `" + sha256new.Substring(0,16) + `"...`");`r`n" +
    "        sb.AppendLine(`"`");`r`n" +
    "        sb.AppendLine(`"[+] Backup       : `" + fname + `".bak`");`r`n" +
    "        sb.AppendLine(`"[+] Meta backup  : `" + fname + `".bak.meta.txt`");`r`n" +
    "        sb.AppendLine(`"[+] Modificado   : `" + fname);`r`n" +
    "        sb.AppendLine(`"[+] Carpeta      : `" + outDir);`r`n" +
    "        sb.AppendLine(`"[OK] MODEM MI ACCOUNT EDITADO CORRECTAMENTE.`");`r`n" +
    "    }`r`n" +
    "    public static void Run(string[] paths, string outDir) {`r`n" +
    "        Done = false;`r`n" +
    "        while (Q.Count > 0) { string x; Q.TryDequeue(out x); }`r`n" +
    "        Task.Run((System.Action)(() => {`r`n" +
    "            var sb = new StringBuilder();`r`n" +
    "            try {`r`n" +
    "                sb.AppendLine(`"[*] ========================================`");`r`n" +
    "                sb.AppendLine(`"[*]   MODEM MI ACCOUNT  -  RNX TOOL PRO`");`r`n" +
    "                sb.AppendLine(`"[*]   Archivos a procesar: `" + paths.Length);`r`n" +
    "                sb.AppendLine(`"[*] ========================================`");`r`n" +
    "                sb.AppendLine(`"`");`r`n" +
    "                for (int f = 0; f < paths.Length; f++) {`r`n" +
    "                    sb.AppendLine(`"[*] --- Archivo `" + (f+1) + `" de `" + paths.Length + `" ---`");`r`n" +
    "                    string subDir = Path.Combine(outDir, `"modem_`" + (f+1));`r`n" +
    "                    ProcessFile(paths[f], subDir, sb);`r`n" +
    "                    sb.AppendLine(`"`");`r`n" +
    "                }`r`n" +
    "                sb.AppendLine(`"[=] ============================`");`r`n" +
    "            } catch (Exception ex) { sb.AppendLine(`"[!] ERROR GLOBAL: `" + ex.Message + `" | `" + ex.StackTrace); }`r`n" +
    "            Q.Enqueue(sb.ToString());`r`n" +
    "            Done = true;`r`n" +
    "        }));`r`n" +
    "    }`r`n" +
    "}`r`n"
)
}
