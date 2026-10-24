param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [string]$MkcertExe = "mkcert"
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw "Indica el ejecutable con -GodotExe en este sistema. El selector visual requiere Windows."
    }
    Add-Type -AssemblyName System.Windows.Forms
    $godotPicker = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $godotPicker.Title = "Selecciona el ejecutable de Godot que usas para Argentum"
        $godotPicker.Filter = "Ejecutables de Godot (*.exe)|*.exe"
        $godotPicker.CheckFileExists = $true
        $godotPicker.Multiselect = $false
        $downloadsDirectory = Join-Path $env:USERPROFILE "Downloads"
        if (Test-Path -LiteralPath $downloadsDirectory) {
            $godotPicker.InitialDirectory = $downloadsDirectory
        }
        if ($godotPicker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Host "Inicio cancelado."
            exit 0
        }
        $GodotExe = $godotPicker.FileName
    } finally {
        $godotPicker.Dispose()
    }
}
$godotPath = (Resolve-Path -LiteralPath $GodotExe).Path
$projectDirectory = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory "project.godot"))) {
    throw "ProjectPath debe apuntar a la carpeta que contiene project.godot."
}
if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory "shared/networking/server_tls_config.gd"))) {
    throw "Actualiza la rama work/web-export-alpha antes de iniciar la prueba WSS."
}
$mkcertCommand = Get-Command $MkcertExe -CommandType Application -ErrorAction SilentlyContinue
if (-not $mkcertCommand) {
    throw "Falta mkcert. Ejecuta: winget install --id FiloSottile.mkcert --exact ; luego abre una nueva terminal."
}
$mkcertPath = $mkcertCommand.Source

$portProbe = New-Object System.Net.Sockets.TcpClient
try {
    $connection = $portProbe.BeginConnect("127.0.0.1", 7777, $null, $null)
    if ($connection.AsyncWaitHandle.WaitOne(500)) {
        try { $portProbe.EndConnect($connection) } catch { }
    }
    if ($portProbe.Connected) {
        throw "El puerto 7777 esta ocupado. Detene el servidor anterior con Ctrl+C y volve a ejecutar este lanzador."
    }
} finally {
    $portProbe.Dispose()
}

$certificateDirectory = Join-Path $env:LOCALAPPDATA "ArgentumGodot/PrivateWebTest"
New-Item -ItemType Directory -Force -Path $certificateDirectory | Out-Null
$certificatePath = Join-Path $certificateDirectory "localhost.pem"
$keyPath = Join-Path $certificateDirectory "localhost-key.pem"
$chainPath = Join-Path $certificateDirectory "localhost-chain.pem"

Write-Host "Configurando el certificado local de desarrollo. Windows puede pedir permiso para confiar en el certificado."
& $mkcertPath -install
if ($LASTEXITCODE -ne 0) { throw "No se pudo instalar la autoridad de desarrollo de mkcert." }
& $mkcertPath -cert-file $certificatePath -key-file $keyPath localhost 127.0.0.1
if ($LASTEXITCODE -ne 0) { throw "No se pudo generar el certificado local." }
$caRoot = (& $mkcertPath -CAROOT | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw "No se pudo localizar la autoridad de mkcert." }
$rootCertificatePath = Join-Path $caRoot "rootCA.pem"
$chain = [System.IO.File]::ReadAllText($certificatePath) + "`n" + [System.IO.File]::ReadAllText($rootCertificatePath)
[System.IO.File]::WriteAllText($chainPath, $chain, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Importando recursos y clases de la version actual del proyecto..."
& $godotPath --headless --editor --path $projectDirectory --import
if ($LASTEXITCODE -ne 0) { throw "Godot no pudo importar el proyecto. Abri el proyecto en el editor y revisa los errores antes de iniciar el servidor." }

Write-Host "Servidor privado: wss://127.0.0.1:7777"
Write-Host "En la web, ingresa esa direccion y pulsa Conectar. Deja esta terminal abierta; Ctrl+C detiene el servidor."
$godotArguments = @(
    "--headless", "--path", $projectDirectory, "--", "--server", "--server-local-wss",
    "--server-tls-cert=$chainPath", "--server-tls-key=$keyPath"
)
& $godotPath @godotArguments
if ($LASTEXITCODE -ne 0) { throw "Godot termino con codigo $LASTEXITCODE. Revisa los mensajes de esta terminal." }
