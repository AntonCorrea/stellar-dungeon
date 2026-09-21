# make_frames.ps1 (v2)
# Extrae frames 16x16 de tileset/variantes 0x72.
#
# v2: el matcher viejo comparaba mascaras de luma>128 y fallaba con tiles
# oscuros (pisos/muros): la mascara de un tile oscuro es toda-false y
# "coincidia" 256/256 con CUALQUIER tile vacio/transparente -> frames vacios.
# Ahora se usa correlacion de luminancia NORMALIZADA (media/std por tile),
# tolerante al recolor, con patron de alfa exacto.
#
# Uso:
#   & .\tools\make_frames.ps1
#
# Edita las rutas de abajo si movés las carpetas.
# Salida: assets/frames/<bioma>/<nombre>.png para cada variante.
#
# Nota: no usar bloque param() — en Windows PowerShell 5.1 rompe el LockBits de
# imagenes grandes (bytes 0). Los paths van como variables normales.

$Base      = "C:\Users\NanoCorrea\Documents\repos\event\stellar\0x72_DungeonTilesetII_v1.7.png"
$FramesDir = "C:\Users\NanoCorrea\Documents\repos\event\stellar-dungeon\assets\frames"
$TilesetDir = "C:\Users\NanoCorrea\Documents\repos\event\stellar-dungeon\assets\tileset"
$Variants  = @("omnibo_jungle_dungeon.png", "omnibo_dessert_dungeon.png")

$names = @("floor_1","floor_2","floor_3","floor_4","floor_5","floor_6","floor_7","floor_8",
           "wall_mid","wall_top_mid","column","floor_stairs","floor_ladder")

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.InteropServices

function Get-Img([string]$path) {
  $bmp = [System.Drawing.Bitmap]::FromFile($path)
  $w = $bmp.Width; $h = $bmp.Height
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $stride = $data.Stride
  $len = [int]($stride * $h)
  $bytes = New-Object byte[] ($len)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $len)
  $bmp.UnlockBits($data)
  $bmp.Dispose()
  return @{ Bytes = $bytes; Stride = $stride; W = $w; H = $h; Path = $path }
}

# Igualdad byte-a-byte (para encontrar las coordenadas de los frames base).
function Test-TileEqual($img, $tx, $ty, $frameBytes, $frameStride) {
  for ($py = 0; $py -lt 16; $py++) {
    $ro = $img.Stride * ($ty * 16 + $py) + $tx * 64
    $fo = $frameStride * $py
    for ($px = 0; $px -lt 16; $px++) {
      $bi = $ro + $px * 4; $fi = $fo + $px * 4
      if ($img.Bytes[$bi]     -ne $frameBytes[$fi])     { return $false }
      if ($img.Bytes[$bi + 1] -ne $frameBytes[$fi + 1]) { return $false }
      if ($img.Bytes[$bi + 2] -ne $frameBytes[$fi + 2]) { return $false }
      if ($img.Bytes[$bi + 3] -ne $frameBytes[$fi + 3]) { return $false }
    }
  }
  return $true
}

# Correlacion de luminancia normalizada entre tile (tx,ty) de $img y (bx,by) de
# $base. Patron de alfa debe coincidir exacto. $result.corr = -2 si el alfa
# difiere, -1 si hay pocos pixeles opacos. n = pixeles opacos compartidos.
function NormCorr($img, $tx, $ty, $base, $bx, $by) {
  $aPix = New-Object System.Collections.ArrayList
  $bPix = New-Object System.Collections.ArrayList
  for ($py = 0; $py -lt 16; $py++) {
    $vo = $img.Stride * ($ty * 16 + $py) + $tx * 64
    $bo = $base.Stride * ($by * 16 + $py) + $bx * 64
    for ($px = 0; $px -lt 16; $px++) {
      $vi = $vo + $px * 4; $bi = $bo + $px * 4
      $va = $img.Bytes[$vi + 3]; $ba = $base.Bytes[$bi + 3]
      if (($va -ge 128) -ne ($ba -ge 128)) { return @{ corr = -2.0; n = 0 } }
      if ($va -ge 128) {
        $vl = 0.299 * $img.Bytes[$vi + 2] + 0.587 * $img.Bytes[$vi + 1] + 0.114 * $img.Bytes[$vi]
        $bl = 0.299 * $base.Bytes[$bi + 2] + 0.587 * $base.Bytes[$bi + 1] + 0.114 * $base.Bytes[$bi]
        [void]$aPix.Add($vl); [void]$bPix.Add($bl)
      }
    }
  }
  $n = $aPix.Count
  if ($n -lt 32) { return @{ corr = -1.0; n = $n } }
  $ma = 0.0; $mb = 0.0
  foreach ($x in $aPix) { $ma += $x }; $ma /= $n
  foreach ($x in $bPix) { $mb += $x }; $mb /= $n
  $num = 0.0; $da = 0.0; $db = 0.0
  for ($k = 0; $k -lt $n; $k++) {
    $av = [double]$aPix[$k] - $ma; $bv = [double]$bPix[$k] - $mb
    $num += $av * $bv; $da += $av * $av; $db += $bv * $bv
  }
  if ($da -eq 0 -or $db -eq 0) { return @{ corr = 0.0; n = $n } }
  return @{ corr = $num / [math]::Sqrt($da * $db); n = $n }
}

function Save-Crop([string]$srcPath, $tx, $ty, [string]$outPath) {
  $src = [System.Drawing.Bitmap]::FromFile($srcPath)
  $crop = New-Object System.Drawing.Bitmap(16, 16)
  $g = [System.Drawing.Graphics]::FromImage($crop)
  $dest = New-Object System.Drawing.Rectangle(0, 0, 16, 16)
  $srcR = New-Object System.Drawing.Rectangle(($tx * 16), ($ty * 16), 16, 16)
  $g.DrawImage($src, $dest, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $crop.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $crop.Dispose(); $src.Dispose()
}

"=== 1) Coordenadas base de los frames de referencia ==="
$base = Get-Img $Base
$map = @{}
foreach ($n in $names) {
  $fpath = Join-Path $FramesDir "$n.png"
  if (-not (Test-Path $fpath)) { "BASE  {0}: no hay frame de referencia" -f $n; $map[$n] = $null; continue }
  $fr = Get-Img $fpath
  $found = @()
  for ($ty = 0; $ty -lt 32; $ty++) {
    for ($tx = 0; $tx -lt 32; $tx++) {
      if (Test-TileEqual $base $tx $ty $fr.Bytes $fr.Stride) { $found += ,@{tx=$tx; ty=$ty} }
    }
  }
  if ($found.Count -eq 0) {
    "BASE  {0}: NO encontrado en el tileset base" -f $n
    $map[$n] = $null
  } else {
    $map[$n] = $found[0]
    "BASE  {0}: tile ({1},{2})  (x{3})" -f $n, $found[0].tx, $found[0].ty, $found.Count
  }
}

"=== 2) Match por-tile (correlacion de luma normalizada) en cada variante ==="
foreach ($vn in $Variants) {
  $key = $vn -replace '^omnibo_','' -replace '_dungeon\.png$',''
  $vpath = Join-Path $TilesetDir $vn
  if (-not (Test-Path $vpath)) { "MISSING variant: $vpath"; continue }
  $var = Get-Img $vpath
  $vxMax = [int]($var.W / 16); $vyMax = [int]($var.H / 16)
  "  [$key] variante {0}x{1} tiles" -f $vxMax, $vyMax

  $used = @{}
  $assigned = @{}
  $missing = @()
  foreach ($n in $names) {
    $bc = $map[$n]
    if ($null -eq $bc) { $missing += $n; continue }
    $best = $null; $bestCorr = -2.0
    for ($vy = 0; $vy -lt $vyMax; $vy++) {
      for ($vx = 0; $vx -lt $vxMax; $vx++) {
        if ($used.ContainsKey("$vx,$vy")) { continue }
        $r = NormCorr $var $vx $vy $base $bc.tx $bc.ty
        if ($r.corr -gt $bestCorr) { $bestCorr = $r.corr; $best = @{ vx = $vx; vy = $vy; c = $r.corr; n = $r.n } }
      }
    }
    if ($null -ne $best -and $best.c -ge 0.6 -and $best.n -ge 32) {
      $used["$($best.vx),$($best.vy)"] = $true
      $assigned[$n] = $best
      "  MATCH {0}/{1}: var tile ({2},{3}) corr {4:N3} n={5}" -f $key, $n, $best.vx, $best.vy, $best.c, $best.n
    } else {
      $missing += $n
      "  FALTA {0}/{1}: sin match seguro (best corr {2:N3})" -f $key, $n, $bestCorr
    }
  }

  $outDir = Join-Path $FramesDir $key
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  Get-ChildItem $outDir -Filter "*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
  foreach ($n in $names) {
    if ($assigned.ContainsKey($n)) {
      $s = $assigned[$n]
      Save-Crop $vpath $s.vx $s.vy (Join-Path $outDir "$n.png")
      "  FRAME {0}/{1}: guardado desde tile ({2},{3})" -f $key, $n, $s.vx, $s.vy
    }
  }
}
"DONE"