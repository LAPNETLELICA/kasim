; Script generated for Inno Setup 6.0+
; Bundles Kasim Student Desktop Client into ExamGuard_Student_Setup.exe

#define MyAppName "Kasim Secure Exam Client"
#define MyAppVersion "3.0.0"
#define MyAppPublisher "Kasim Security Platform"
#define MyAppExeName "kasim_student.exe"
#define MyAppBuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{D98214C7-234B-4E38-8D2A-9492A0123456}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\KasimStudent
DefaultGroupName={#MyAppName}
OutputDir=Output
OutputBaseFilename=Kasim_Student_Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Tasks: desktopicon; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
