; Music Catcher 安装程序 — Inno Setup 脚本
; 用 Inno Setup 6 编译此脚本即可生成安装包

#define MyAppName "Music Catcher"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Music Catcher"
#define MyAppExeName "MusicCatcher.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=MusicCatcherSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create desktop shortcut"; GroupDescription: "Additional:"; Flags: checkedonce

[Files]
; 主程序
Source: "..\music_catcher\dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; FFmpeg 下载脚本
Source: "download_ffmpeg.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 安装完成后下载 FFmpeg
Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\download_ffmpeg.ps1"" ""{app}"""; \
    StatusMsg: "Downloading FFmpeg audio component (~30MB)..."; \
    Flags: runhidden waituntilterminated

; 安装完成后启动程序（可选）
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch Music Catcher"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\ffmpeg"
Type: files; Name: "{app}\download_ffmpeg.ps1"
