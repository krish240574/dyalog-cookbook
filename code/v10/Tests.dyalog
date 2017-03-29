﻿:Namespace Tests
    ⎕IO←1 ⋄ ⎕ML←1

    ∇ Initial;list;rc
      ∆Path←##.FilesAndDirs.GetTempPath,'\MyApp_Tests'
      #.FilesAndDirs.RmDir ∆Path
      'Create!'#.FilesAndDirs.CheckPath ∆Path
      list←⊃#.FilesAndDirs.Dir'..\..\texts\en\*.txt'
      rc←list #.FilesAndDirs.CopyTo ∆Path,'\'
      ⍎(0∨.≠⊃rc)/'.'
    ∇

    ∇ R←Test_exe_01(stopFlag batchFlag);⎕TRAP;rc
      ⍝ Process a single file with .\MyApp.exe
      ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
      R←∆Failed
      ⍝ Precautions:
      #.FilesAndDirs.DeleteFile⊃#.FilesAndDirs.Dir ∆Path,'\*.csv'
      rc←#.Execute.Application'MyApp.exe ',∆Path,'\ulysses.txt'
      →GoToTidyUp ##.MyApp.EXIT.OK≠⊃rc
      →GoToTidyUp~#.FilesAndDirs.Exists ∆Path,'\ulysses.csv'
      R←∆OK
     ∆TidyUp:
      #.FilesAndDirs.DeleteFile⊃#.FilesAndDirs.Dir ∆Path,'\*.csv'
    ∇

    ∇ R←Test_exe_02(stopFlag batchFlag);⎕TRAP;rc;listCsvs
      ⍝ Process all TXT files in a certain directory
      ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
      R←∆Failed
      ⍝ Precautions:
      #.FilesAndDirs.DeleteFile⊃#.FilesAndDirs.Dir ∆Path,'\*.csv'
      rc←#.Execute.Application'MyApp.exe ',∆Path,'\'
      →GoToTidyUp ##.MyApp.EXIT.OK≠⊃rc
      listCsvs←⊃#.FilesAndDirs.Dir ∆Path,'\*.csv'
      →GoToTidyUp 1≠⍴listCsvs
      →GoToTidyUp'total.csv'≢#.APLTreeUtils.Lowercase⊃,/1↓⎕NPARTS⊃listCsvs
      R←∆OK
     ∆TidyUp:
      #.FilesAndDirs.DeleteFile⊃#.FilesAndDirs.Dir ∆Path,'\*.csv'
    ∇

    ∇ R←Test_map_01(stopFlag batchFlag);⎕TRAP
      ⍝ Check the length of the left argument
      ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
      R←∆Failed
      :Trap 5
          {}(⊂⎕A)#.Utilities.map'APL is great'
          →FailsIf 1
      :Else
          →PassesIf'Left argument is not a two-element vector'≡⊃⎕DM
      :EndTrap
      R←∆OK
    ∇

    ∇ R←Test_map_02(stopFlag batchFlag);⎕TRAP;Config;MyLogger
      ⍝ Check whether `map` works fine with appropriate data
      ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
      R←∆Failed
      (Config MyLogger)←##.MyApp.Initial ⍬
      →FailsIf'APL IS GREAT'≢Config.Accents ##.Utilities.map ##.APLTreeUtils.Uppercase'APL is great'
      →FailsIf'UßU'≢Config.Accents ##.Utilities.map ##.APLTreeUtils.Uppercase'üßÜ'
      R←∆OK
    ∇

    ∇ R←Test_map_03(stopFlag batchFlag);⎕TRAP;rc
      ⍝ Test whether `TxtToCsv` handles a non-existing file correctly
      ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
      R←∆Failed
      #.MyApp.(Config MyLogger)←##.MyApp.Initial ⍬
      rc←#.MyApp.TxtToCsv'This_file_does_not_exist'
      →FailsIf ##.MyApp.EXIT.SOURCE_NOT_FOUND≢rc
      R←∆OK
    ∇

    ∇ {r}←GetHelpers
      r←#.Tester.EstablishHelpersIn ⎕THIS
    ∇

    ∇ Cleanup
      :If 0<⎕NC'∆Path'
          #.FilesAndDirs.RmDir ∆Path
          ⎕EX '∆Path'
      :EndIf
    ∇

:EndNamespace