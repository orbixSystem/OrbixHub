; Instalador do OrbixHub para Windows (Inno Setup 6).
;
; Empacota a pasta inteira do build — o .exe sozinho nao roda, ele depende das
; DLLs e da pasta data\ ao lado.
;
;   ISCC.exe /DAppVersion=1.0.3 installer\orbixhub.iss
;
; O AppId é a identidade do programa e NÃO PODE MUDAR: é por ele que o Windows
; reconhece uma instalação existente e atualiza por cima em vez de criar uma
; segunda cópia.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{B4B7F0C1-6E2E-4E9E-9E1E-8F0A2D3C5A11}
AppName=OrbixHub
AppVersion={#AppVersion}
AppPublisher=OrbixSystem
DefaultDirName={localappdata}\OrbixHub
DefaultGroupName=OrbixHub
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=OrbixHubSetup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Instala no perfil do usuário: a atualização automática roda sem pedir UAC,
; que é o que permite o app se atualizar sozinho depois de baixar.
PrivilegesRequired=lowest
; O app está aberto quando dispara a atualização — fecha e reabre no fim.
CloseApplications=yes
RestartApplications=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OrbixHub"; Filename: "{app}\orbixhub_front.exe"
Name: "{userdesktop}\OrbixHub"; Filename: "{app}\orbixhub_front.exe"

[Run]
Filename: "{app}\orbixhub_front.exe"; Description: "Abrir o OrbixHub"; \
  Flags: nowait postinstall skipifsilent
