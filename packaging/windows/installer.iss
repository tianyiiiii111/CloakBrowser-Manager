; Inno Setup script — run on Windows after PyInstaller build.
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" packaging\windows\installer.iss /DMyAppVersion=0.1.0

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

#define MyAppName "CloakBrowser Manager"
#define MyAppPublisher "CloakHQ"
#define MyAppExeName "CloakBrowser Manager.exe"
#define MyBuildDir "..\..\dist\CloakBrowser Manager"

[Setup]
AppId={{A8F3C2E1-9B4D-4A2E-8C1F-0D5E6A7B8C9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=CloakBrowser-Manager-{#MyAppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}}"; Flags: nowait postinstall skipifsilent
