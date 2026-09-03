; Inno Setup script for Spectra. ISCC is preinstalled on GitHub's
; windows-latest runners. Driven by tool/package/windows_installer.ps1,
; which passes AppVersion, BuildDir and OutDir with /D switches.
#define AppPublisher "Spectra"
#define AppId "dev.spectra.spectra"

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
