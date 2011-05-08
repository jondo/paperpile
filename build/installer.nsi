!include "MUI2.nsh"

;;; General settings

Name "Paperpile"
OutFile "paperpile.exe"

var InstallType

InstallDir "$PROGRAMFILES\Paperpile"
InstallDirRegKey HKLM "Software\Paperpile" "install_dir"
RequestExecutionLevel admin

!define MUI_ABORTWARNING
!define MUI_ICON "..\qt\win32\paperpile.ico"
!define MUI_UNICON "..\qt\win32\paperpile.ico"

;;; Pages

   !define MUI_PAGE_CUSTOMFUNCTION_PRE dirPre
!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_PAGE_INSTFILES

   !define MUI_FINISHPAGE_RUN
   !define MUI_FINISHPAGE_RUN_TEXT "Run Paperpile"
   !define MUI_FINISHPAGE_RUN_FUNCTION runPaperpile
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM

!insertmacro MUI_UNPAGE_INSTFILES
  
!insertmacro MUI_LANGUAGE "English"


Section "Paperpile" Paperpile

  SetOutPath "$INSTDIR"

  File "..\dist\data\win32\paperpile.exe"
  File "..\dist\data\win32\paperpile.ico"
  ;File "..\dist\data\win32\*dll" 
  ;File /r "..\dist\data\win32\plack" 
  
  WriteRegStr HKLM "Software\Paperpile" "install_dir" $INSTDIR
  WriteRegStr HKLM "Software\Paperpile" "version_id"  $%version_id%
  WriteRegStr HKLM "Software\Paperpile" "version_name"  $%version_name%

  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile" "Publisher" "Paperpile"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile" "DisplayName" "Paperpile"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile" "DisplayVersion" "$%version_name%"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile" "NoRepair" 1

  CreateDirectory "$SMPROGRAMS\Paperpile"
  CreateShortCut "$SMPROGRAMS\Paperpile\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\paperpile.ico"
  CreateShortCut "$SMPROGRAMS\Paperpile\Paperpile.lnk" "$INSTDIR\paperpile.exe" "" "$INSTDIR\paperpile.ico"


   WriteUninstaller "$INSTDIR\Uninstall.exe"

SectionEnd


Section "Uninstall"

  Delete "$INSTDIR\Uninstall.exe"
  Delete "$INSTDIR\paperpile.exe"
  Delete "$INSTDIR\paperpile.ico"
  RMDir /r "$INSTDIR\plack"
  ;Delete "$INSTDIR\*dll"

  RMDir "$INSTDIR"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paperpile"
  DeleteRegKey HKLM "Software\Paperpile"

  Delete "$SMPROGRAMS\Paperpile\*.*"
  RMDir  "$SMPROGRAMS\Paperpile"

SectionEnd

Function .onInit

  ReadRegStr $R0 HKLM  "Software\Paperpile\" "version_id"

  StrCpy $InstallType "INSTALL"
    
  StrCmp $R0 "" done

  StrCpy $InstallType "UPGRADE"

  MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
  "Paperpile is already installed. $\n$\nClick `OK` to remove the \
  previous version or `Cancel` to cancel this upgrade." \
  IDOK uninst
  Abort
 
uninst:
  ClearErrors
  ExecWait '$INSTDIR\Uninstall.exe /S $R0 _?=$INSTDIR' 

done:
FunctionEnd



Function dirPre

  StrCmp $installType "UPGRADE" skip

skip:
  Abort

FunctionEnd



Function runPaperpile

Exec '"$INSTDIR\paperpile.exe"'

Functionend