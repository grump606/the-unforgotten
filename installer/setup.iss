; Inno Setup script. Build with scripts/build_installer.ps1, which passes
; /DAppVersion=<project.godot config/version> and exports the game first.
;
; Running a newer setup over an existing install upgrades it in place (same
; AppId). Running an older setup is refused. On start, setup also asks GitHub
; for the latest release and, if it is newer than this setup, offers to open
; the download page. That check is skipped silently when offline or when the
; repository is private (the API then answers 404).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "Card Battle Prototype"
#define AppExe "CardBattlePrototype.exe"
#define Repo "grump606/card-battle-prototype"

[Setup]
AppId={{7B1E5C52-3D0A-4F6B-9C41-6A2D8E0F1B73}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=grump606
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\build
OutputBaseFilename=CardBattlePrototype-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExe}
VersionInfoVersion={#AppVersion}
; The in-game updater relaunches the game itself (/RELAUNCH=1); do not let setup also restart a game it closed.
RestartApplications=no

[Files]
Source: "..\build\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
; In-game update: the game starts this setup with /SILENT /RELAUNCH=1, then exits; start it again once the files are replaced.
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: ShouldRelaunch

[Code]
const
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{7B1E5C52-3D0A-4F6B-9C41-6A2D8E0F1B73}_is1';

// Compares dotted numeric versions ("1.2.10" vs "1.3"). Returns <0, 0 or >0.
function CompareVersions(A, B: String): Integer;
var
  PA, PB, VA, VB: Integer;
  SA, SB: String;
begin
  Result := 0;
  SA := A;
  SB := B;
  while (Result = 0) and ((SA <> '') or (SB <> '')) do
  begin
    PA := Pos('.', SA);
    if PA = 0 then PA := Length(SA) + 1;
    PB := Pos('.', SB);
    if PB = 0 then PB := Length(SB) + 1;
    VA := StrToIntDef(Copy(SA, 1, PA - 1), 0);
    VB := StrToIntDef(Copy(SB, 1, PB - 1), 0);
    if VA < VB then Result := -1
    else if VA > VB then Result := 1;
    Delete(SA, 1, PA);
    Delete(SB, 1, PB);
  end;
end;

// The installed version as recorded by a previous setup, or '' if none.
function InstalledVersion(): String;
begin
  Result := '';
  if not RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', Result) then
    if not RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', Result) then
      Result := '';
end;

// Latest release tag from GitHub with any leading "v" removed, or '' when it
// cannot be read (offline, private repo, rate limited, unexpected reply).
function LatestReleaseVersion(): String;
var
  Http: Variant;
  Body: String;
  P, Q: Integer;
begin
  Result := '';
  try
    Http := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    Http.SetTimeouts(3000, 3000, 3000, 3000);
    Http.Open('GET', 'https://api.github.com/repos/{#Repo}/releases/latest', False);
    Http.SetRequestHeader('User-Agent', 'CardBattlePrototype-Setup');
    Http.Send('');
    if Http.Status <> 200 then Exit;
    Body := Http.ResponseText;
    P := Pos('"tag_name":"', Body);
    if P = 0 then Exit;
    Delete(Body, 1, P + Length('"tag_name":"') - 1);
    Q := Pos('"', Body);
    if Q = 0 then Exit;
    Result := Copy(Body, 1, Q - 1);
    if (Result <> '') and ((Result[1] = 'v') or (Result[1] = 'V')) then
      Delete(Result, 1, 1);
  except
    Result := '';
  end;
end;

function InitializeSetup(): Boolean;
var
  Installed, Latest: String;
  ErrorCode: Integer;
begin
  Result := True;

  Installed := InstalledVersion();
  if (Installed <> '') and (CompareVersions('{#AppVersion}', Installed) < 0) then
  begin
    MsgBox('{#AppName} ' + Installed + ' is already installed, which is newer than this setup ({#AppVersion}).' + #13#10 +
      'Nothing was changed.', mbInformation, MB_OK);
    Result := False;
    Exit;
  end;

  if WizardSilent() then Exit;

  Latest := LatestReleaseVersion();
  if (Latest <> '') and (CompareVersions(Latest, '{#AppVersion}') > 0) then
  begin
    if MsgBox('A newer version (' + Latest + ') is available. This setup installs {#AppVersion}.' + #13#10 + #13#10 +
      'Open the download page now?' + #13#10 + '(Choose No to install {#AppVersion} anyway.)',
      mbConfirmation, MB_YESNO) = IDYES then
    begin
      ShellExec('open', 'https://github.com/{#Repo}/releases/latest', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
      Result := False;
    end;
  end;
end;

// True when the in-game updater started this setup (/RELAUNCH=1), so the game comes back by itself.
function ShouldRelaunch(): Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

function UpdateReadyMessage(): String;
begin
  Result := '';
end;
