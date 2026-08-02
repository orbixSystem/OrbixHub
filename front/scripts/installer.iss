; Instalador Windows do OrbixHub (Inno Setup)
; Empacota a saída de `flutter build windows --release` (pasta Release inteira,
; pois o .exe sozinho depende de DLLs e da pasta data\ ao lado) + verifica o
; Microsoft Visual C++ Redistributable (dependência de runtime do app compilado).
;
; Como compilar (a partir de front\):
;   1) scripts\build_prod.ps1 (ou flutter build windows --release --dart-define-from-file=env\prod.json)
;   2) "C:\Users\<voce>\AppData\Local\Programs\Inno Setup 6\ISCC.exe" scripts\installer.iss
;
; Saída: front\build\installer\OrbixHub-Setup-<versao>.exe

#define AppName "OrbixHub"
#define AppPublisher "OrbixSystem"
#define AppURL "https://hub.orbixsystem.com"
#define AppVersion "1.0.0"
#define AppExeName "OrbixHub.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{6F7B2C6E-6E52-4B9B-9C7B-6C1E2B6B9A11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=OrbixHub-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar um atalho na área de trabalho"; GroupDescription: "Atalhos adicionais:"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Instala o VC++ Redistributable silenciosamente se ainda não estiver presente.
Filename: "{tmp}\vcredist_x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Instalando componentes de runtime necessários..."; Check: VCRedistNeedsInstall; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\{#AppExeName}"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
// Detecta se o VC++ Redistributable 2015-2022 (x64) já está instalado,
// checando a chave de registro que o próprio redist grava.
function VCRedistNeedsInstall(): Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', Installed) then
  begin
    if Installed = 1 then
      Result := False;
  end;
end;
