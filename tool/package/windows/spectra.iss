; Inno Setup script for Spectra. Inno Setup is NOT preinstalled on the
; windows-latest image (Windows Server 2025); windows_installer.ps1's
; Get-ISCC resolves it from PATH or its default install location, or
; throws with the install command. Driven by windows_installer.ps1, which
; passes AppVersion, BuildDir and OutDir with /D switches.
#define AppPublisher "Spectra"
; Bundle identifier: dev.spectra.spectra (matches the macOS bundle id).
; AppId below is a separate, stable GUID Inno Setup uses to recognize
; upgrades across versions — do not regenerate it once released.
#define AppId "{{68E0C411-A8AC-481C-AB65-F07D8A6DA804}"

[Setup]
AppId={#AppId}
AppName=Spectra
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Spectra
DefaultGroupName=Spectra
DisableProgramGroupPage=yes
OutputDir={#OutDir}
OutputBaseFilename=spectra-{#AppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
UninstallDisplayIcon={app}\spectra.exe

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Spectra"; Filename: "{app}\spectra.exe"
Name: "{autodesktop}\Spectra"; Filename: "{app}\spectra.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts"; Flags: unchecked

[Run]
Filename: "{app}\spectra.exe"; Description: "Launch Spectra"; Flags: nowait postinstall skipifsilent
