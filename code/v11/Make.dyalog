﻿:Class Make
⍝ Puts the application `MyApp` together:
⍝ * Remover folder `Source\` in the current directory
⍝ * Create folder `Source\` in the current directory
⍝ * Copy icon to `Source\`
⍝ * Copy the INI file template over to `DESTINATION`
⍝ * Creates `MyApp.exe` within `Source\`
    ⎕IO←1 ⋄ ⎕ML←1
    DESTINATION←'MyApp'
    ∇ {filename}←Run offFlag;rc;en;more;successFlag;F;msg
      :Access Public Shared
      F←##.FilesAndDirs
      (rc en more)←F.RmDir DESTINATION
      {⍵:.}0≠rc
      successFlag←'Create!'F.CheckPath DESTINATION
      {⍵:.}1≠successFlag
      (successFlag more)←2↑'images'F.CopyTree DESTINATION,'\images'
      {⍵:.}1≠successFlag
      (rc more)←'MyApp.ini.template'F.CopyTo DESTINATION,'\MyApp.ini'
      {⍵:.}0≠rc
      Export'MyApp.exe'
      filename←DESTINATION,'\MyApp.exe'
      :If offFlag
          ⎕OFF
      :EndIf
    ∇
    ∇ {r}←{flags}Export exeName;type;flags;resource;icon;cmdline;try;max;success
    ⍝ Attempts to export the application
      r←⍬
      flags←{0<⎕NC ⍵:⍎⍵ ⋄ 0}'flags'       ⍝ 2 = BOUND_CONSOLE
      max←50
      type←'StandaloneNativeExe'
      icon←F.NormalizePath DESTINATION,'\images\logo.ico'
      resource←cmdline←''
      success←try←0
      :Repeat
          :Trap 11                                                               
              2 ⎕NQ'.' 'Bind',(DESTINATION,'\',exeName)type flags resource icon cmdline
              success←1
          :Else
              ⎕DL 0.2
          :EndTrap
      :Until success∨max<try←try+1
      :If 0=success
          ⎕←'*** ERROR: Failed to export EXE to ',DESTINATION,'\',exeName,' after ',(⍕try),' tries.'
          . ⍝ Deliberate error; allows investigation
      :EndIf
    ∇
:EndClass