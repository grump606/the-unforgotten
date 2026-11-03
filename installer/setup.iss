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
#define AppName "The Unforgotten"
#define AppExe "TheUnforgotten.exe"
#define Repo "grump606/the-unforgotten"

[Setup]
AppId={{7B1E5C52-3D0A-4F6B-9C41-6A2D8E0F1B73}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=grump606
; Upgrades stay in the folder they are in (see DefaultInstallDir); an install still in a folder named after the
; old name moves to the folder named after the game.
DefaultDirName={code:DefaultInstallDir}
UsePreviousAppDir=no
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\build
OutputBaseFilename=TheUnforgotten-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\art\layers\ui\game_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
VersionInfoVersion={#AppVersion}
; The in-game updater relaunches the game itself (/RELAUNCH=1); do not let setup also restart a game it closed.
RestartApplications=no

[Files]
Source: "..\build\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion

; The game was renamed from Card Battle Prototype (v0.6.0): remove the old exe and shortcuts when upgrading in place.
[InstallDelete]
Type: files; Name: "{app}\CardBattlePrototype.exe"
Type: filesandordirs; Name: "{autoprograms}\Card Battle Prototype"
Type: files; Name: "{autodesktop}\Card Battle Prototype.lnk"

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

var
  // The folder of an existing install as it was when setup started, or ''.
  PreviousInstallDir: String;

// The folder a previous setup installed into, without a trailing backslash, or '' if none.
function PreviousAppDir(): String;
begin
  Result := '';
  if not RegQueryStringValue(HKCU, UninstallKey, 'Inno Setup: App Path', Result) then
    if not RegQueryStringValue(HKLM, UninstallKey, 'Inno Setup: App Path', Result) then
      Result := '';
  if (Result <> '') and (Result[Length(Result)] = '\') then
    Delete(Result, Length(Result), 1);
end;

// True for an install folder still named after the game's old name (Card Battle Prototype).
function IsOldInstallDir(const Dir: String): Boolean;
begin
  Result := CompareText(ExtractFileName(Dir), 'Card Battle Prototype') = 0;
end;

// Where setup installs by default: the folder of the existing install (so upgrades stay where they are and
// a folder the user chose is respected), except an install in a folder still named after the old name,
// which moves to the folder named after the game.
function DefaultInstallDir(Param: String): String;
begin
  if (PreviousInstallDir <> '') and not IsOldInstallDir(PreviousInstallDir) then
    Result := PreviousInstallDir
  else
    Result := ExpandConstant('{autopf}\{#AppName}');
end;

// The installed version as recorded by a previous setup, or '' if none.
function InstalledVersion(): String;
begin
  Result := '';
  if not RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', Result) then
    if not RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', Result) then
      Result := '';
end;

// True only for a release tag shaped like the game accepts (run/update_check.gd
// TAG_PATTERN): optional v/V, then 1-4 dot-separated groups of 1-4 ASCII
// digits, at most 24 characters in all, nothing else.
function IsValidTag(const Tag: String): Boolean;
var
  I, Digits, Groups: Integer;
  C: Char;
begin
  Result := False;
  if (Length(Tag) = 0) or (Length(Tag) > 24) then Exit;
  I := 1;
  if (Tag[1] = 'v') or (Tag[1] = 'V') then I := 2;
  Digits := 0;
  Groups := 1;
  while I <= Length(Tag) do
  begin
    C := Tag[I];
    if (C >= '0') and (C <= '9') then
    begin
      Digits := Digits + 1;
      if Digits > 4 then Exit;
    end
    else if C = '.' then
    begin
      if Digits = 0 then Exit;
      Groups := Groups + 1;
      if Groups > 4 then Exit;
      Digits := 0;
    end
    else
      Exit;
    I := I + 1;
  end;
  Result := Digits > 0;
end;

// Latest release tag from GitHub with any leading "v" removed, or '' when it
// cannot be read (offline, private repo, rate limited, unexpected reply, or a
// tag that fails IsValidTag).
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
    Http.SetRequestHeader('User-Agent', 'TheUnforgotten-Setup');
    Http.Send('');
    if Http.Status <> 200 then Exit;
    Body := Http.ResponseText;
    if Length(Body) > 65536 then Exit;
    P := Pos('"tag_name":"', Body);
    if P = 0 then Exit;
    Delete(Body, 1, P + Length('"tag_name":"') - 1);
    Q := Pos('"', Body);
    if Q = 0 then Exit;
    Result := Copy(Body, 1, Q - 1);
    if not IsValidTag(Result) then
    begin
      Result := '';
      Exit;
    end;
    if (Result[1] = 'v') or (Result[1] = 'V') then
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

  PreviousInstallDir := PreviousAppDir();
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

// The game used to keep its saves in a folder named after its old name (Card Battle Prototype, up to
// v0.6.6). Copies the run save and the settings from there into the folder named after the game, never
// over a file that already exists, and removes the old folder once everything arrived. The game does the
// same at startup (run/user_data_migration.gd), so whichever runs first does the work.
function CopyDataFile(const OldDir, NewDir, Name: String): Boolean;
begin
  Result := True;
  if not FileExists(OldDir + '\' + Name) then Exit;
  if FileExists(NewDir + '\' + Name) then Exit;
  Result := FileCopy(OldDir + '\' + Name, NewDir + '\' + Name, True);
end;

procedure MigrateOldSaves();
var
  Base, OldDir, NewDir: String;
  AllCopied: Boolean;
begin
  Base := ExpandConstant('{userappdata}') + '\Godot\app_userdata';
  OldDir := Base + '\Card Battle Prototype';
  NewDir := Base + '\The Unforgotten';
  if not DirExists(OldDir) then Exit;
  if not ForceDirectories(NewDir) then Exit;
  AllCopied := CopyDataFile(OldDir, NewDir, 'run_save.json');
  AllCopied := CopyDataFile(OldDir, NewDir, 'run_save.json.bak') and AllCopied;
  AllCopied := CopyDataFile(OldDir, NewDir, 'run_save.json.tmp') and AllCopied;
  AllCopied := CopyDataFile(OldDir, NewDir, 'settings.json') and AllCopied;
  AllCopied := CopyDataFile(OldDir, NewDir, 'settings.json.bak') and AllCopied;
  AllCopied := CopyDataFile(OldDir, NewDir, 'settings.json.tmp') and AllCopied;
  // Only when every file is safe in the new folder: what is left is logs, caches and leftovers.
  if AllCopied then DelTree(OldDir, True, True, True);
end;

// An install that lived in a folder named after the old name has just been installed into the new folder:
// remove the old folder (the old exe, its uninstaller and nothing else of the player's).
procedure RemoveOldInstallDir();
begin
  if (PreviousInstallDir = '') or not IsOldInstallDir(PreviousInstallDir) then Exit;
  if CompareText(PreviousInstallDir, RemoveBackslash(ExpandConstant('{app}'))) = 0 then Exit;
  if DirExists(PreviousInstallDir) then DelTree(PreviousInstallDir, True, True, True);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MigrateOldSaves();
    RemoveOldInstallDir();
  end;
end;
