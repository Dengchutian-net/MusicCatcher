# FFmpeg 下载脚本 — 安装程序调用
# 用法: powershell -ExecutionPolicy Bypass -File download_ffmpeg.ps1 <目标目录>

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetDir
)

$ffmpegDir = Join-Path $TargetDir "ffmpeg"
$zipUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$zipFile = Join-Path $env:TEMP "ffmpeg-essentials.zip"

Write-Host "=== 下载 FFmpeg ==="
Write-Host "目标目录: $ffmpegDir"

# 创建目录
if (!(Test-Path $ffmpegDir)) {
    New-Item -ItemType Directory -Path $ffmpegDir -Force | Out-Null
}

# 如果已存在 ffmpeg.exe 则跳过
if (Test-Path (Join-Path $ffmpegDir "ffmpeg.exe")) {
    Write-Host "FFmpeg 已存在，跳过下载"
    exit 0
}

# 下载
Write-Host "正在下载 FFmpeg (约 30MB)..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing
} catch {
    Write-Host "下载失败: $_"
    exit 1
}

# 解压
Write-Host "正在解压..."
$extractDir = Join-Path $env:TEMP "ffmpeg_extract"
if (Test-Path $extractDir) {
    Remove-Item -Recurse -Force $extractDir
}
Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

# 找到 bin 目录并复制
$binDir = Get-ChildItem -Path $extractDir -Recurse -Directory | Where-Object { $_.Name -eq "bin" } | Select-Object -First 1
if ($binDir) {
    Copy-Item (Join-Path $binDir.FullName "ffmpeg.exe") -Destination $ffmpegDir -Force
    Copy-Item (Join-Path $binDir.FullName "ffprobe.exe") -Destination $ffmpegDir -Force
    Write-Host "FFmpeg 安装完成"
} else {
    Write-Host "解压失败: 未找到 bin 目录"
    exit 1
}

# 清理
Remove-Item -Force $zipFile -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue

Write-Host "=== 完成 ==="
