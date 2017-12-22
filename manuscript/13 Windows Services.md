{:: encoding="utf-8" /}
[parm]:title       =   'Services'


# Windows Services


## What is a Windows Service

While the Windows Task Manager just starts any ordinary application, any application that runs as a Windows Service must be specifically designed in order to meet a number of requirements. 

In particular services are expected to communicate by exchanging messages with the Windows Service Control Manager (SCM). 

Commands can be issued by the `SC.exe` (Service Controller) application or interactively via the "Services" application. This allows the user to not only start but also to pause, continue (also called resume) and stop a Windows Service. 


## Windows Services and the Window Event Log
  
Our application is already prepared to write log files and save information in case of a crash, but that's not sufficient: while applications started by the Windows Task Scheduler _might_ write to the Windows Event Log, applications running as a Windows Service are _expected_ to do that, and for good reasons: when running on a server one cannot expect anybody to be around for keeping an eye on log or crash files. 

In large organisations running server farms it is common to have a software in place that frequently checks the Windows Event Logs of all those servers, and raise an alarm in one way or another (TCP messages, text messages, emails, whatever) in case it finds any problems.

We won't add the ability to write to the Windows Event Log in this chapter but rather discuss how to do this in the next chapter.


## Restrictions

With Dyalog version 16.0 we cannot install a stand-alone EXE as a Windows Service. All we can do is to install a given interpreter and then ask it to load a workspace which implies running `⎕LX`. In a future version of Dyalog this restriction will most likely be lifted.

That means that in case you don't want to expose your code you have a problem. There are some solutions:

* Lock all the functions and operators in the workspace.  
* You can create .NET assemblies from your APL code and call them from the workspace that is running as a Windows Service.
* You can start the stand-alone EXE from the workspace that is running as a Windows Service and communicate with it via TCP/Conga.
  
All three solutions share the disadvantage that they add a level of complexity without any gain but hiding the code, but at least there are several escape routes available.

We resume, as usual, by saving a copy of `Z:\code\v12` as `Z:\code\v13`.


## The ServiceState namespace

In order to simplify things we are going to make use of the `ServiceState` namespace, another member of the APLTree project. It requires you to do just two things:

1. Call `ServiceState.Init` as early as possible. This function will make sure that the Service is capable of communicating with the SCM. 

   To do it as early as possible is necessary so that any request will be answered in time. Windows is not exactly patient when it waits for a Service to respond to a "Pause", "Resume" or "Stop" request: after 5 seconds you are already in danger to see an error message that is basically saying that the Service refused to cooperate.

   However, note that the interpreter confirms the "start" request for us; no further action is required.
   
   Normally you need to create a parameter space by calling `CreateParmSpace` and to set at least the name of the log function and possibly the namespace (or class instance) that log function is living in; this log function is used to log any incoming requests from the SCM. The parameter space is then passed as right argument to `Init`.

1. In its main loop the Service is expected to call `ServiceState.CheckServiceMessages`.
   
   This is an operator, so it needs a function as operand: that is a function that is doing the logging, allowing `CheckServiceMessages` to log its actions to the log file. (If you don't have the need to write to a log file then simply passing `{⍵}` will do.
      
   If no request of the SCM is pending when `CheckServiceMessages` is called then it will quit straight away and return a 0. If a "Pause" is pending then it goes into a loop, and it will continue to loop (with a `⎕DL` in between) until either "Continue" (sometimes referred to as "Resume") or "Stop" is requested by the SCM. 

   If a "Stop" is requested the operator will subsequently quit and return a 1.

   
## Installing and uninstalling a Service.

**Note:** for installing as well as un-installing a Service you need admin rights.

Let's assume you have loaded a WS `MyService` which you want to install as a Windows Service run by the same version of Dyalog you are currently in:

~~~
aplexe←'"',(2 ⎕NQ # 'GetEnvironment' 'dyalog'),'\dyalogrt.exe"'
wsid←'"whereEverTheWsLives\MyAppService.DWS"'
cmd←aplexe,' ',wsid,' APL_ServiceInstall=MyAppService DYALOG_NOPOPUPS=1'
~~~

`cmd` could now be execute with the `Execute` class which we introduced in the chapter "[Handling Errors](./07 Handling errors.html)". That would do the trick.

`DYALOG_NOPOPUPS`
: Setting this to 1 prevents any dialogs from popping up (aplcore, WS FULL etc.). You don't want them when Dyalog is running in the background because there's nobody around to click the "OK" button. 
: This also prevents the "Service MyAppService successfully installed" message from popping up which you don't want to see when executing tests that install, start, pause, resume, stop and uninstall a Service.

In order to uninstall the Service simply open a console window with "Run as administrator" and enter:

~~~
sc delete MyAppService
~~~

and you are done.

A> # Pitfalls when installing / uninstalling Windows Services
A>
A> Be warned that when you have opened the "Services" GUI while installing or uninstalling a Windows Service then you must press F5 on the GUI in order to update it. 
A>
A> The problem is not that the GUI does not update itself, though this can be quite annoying; it can get much worse: you might end up with a Service marked in the GUI as "disabled", and the only thing you can do by then is rebooting the machine. 
A> 
A> This will happen when you try to perform an action on the GUI when it is not in sync with the Service's current state.

A> # SC: Service Control
A>
A> `SC` is a command line program that allows a user with admin rights to issue particular commands regarding Windows Services. The general format is:
A>
A> ~~~
A> SC.exe {command} {serviceName}
A> ~~~
A>
A> Commonly used commands are:
A>
A> * create
A> * start
A> * pause
A> * continue
A> * stop
A> * query
A> * delete

## Obstacles

From experience we can tell that there are quite a number of traps. In general there are three different types of problems you might encounter:

1. The Service pretends to start (read: show "running" in the Services GUI) but nothing happens at all.
2. The Service starts, the log file reads fine, but once you request the Service to "Pause" or "Stop" you get nothing but a Windows error message.
3. It all works well but the application does not do anything, or something unexpected.


### The Service seems to be doing nothing at all

If a Service does not seem to do anything when started:

* Check the name and path of the workspace the Service is expected to load: if that's wrong you won't see anything at all - the message "Workspace not found" goes straight into the ether.

* Make sure the workspace size is sufficent. Again too little memory would not produce any error message.

* The Service might create an aplcore when started.

* Start the "Event Viewer" and check whether any useful piece of information is provided. Although our application does not write to the application log yet, the SCM might!


A> # CONTINUE workspaces
A> 
A> The Service might have created a CONTINUE workspace for all sorts of reasons.  
A> 
A> Note that starting with version 16.0 by default Dyalog does _not_ drop a CONTINUE workspace any more. You must configure Dyalog accordingly. 
A> 
A> Note also that a CONTINUE cannot be saved in case there is more than one thread running, and Services are by definition multi-threaded. However, in case it fails very early there might still be a CONTINUE.
A> 
A> Keep in mind that once a second thread is started, Dyalog is not able any more to save a CONTINUE workspace. On the other hand you should have established error trapping before a second thread is started; that would avoid this problem.

A> # aplcores
A> 
A> Writing to the directory the service is installed in might be prohibited by Windows. That might well prevent a CONTINUE or aplcore from being saved. 
A> 
A> While you have no influence on the folder where a CONTINUE would be saved you can define a folder for aplcores:
A> ~~~
A> `APLCORENAME='/pathToFolder/my_aplcore*`. 
A> ~~~
A> This saves any aplcore as "my_aplcore" followed by a running number. For more information regarding aplcores see "[Appendix 3 — aplcores and WS integrity](./52 Appendix 3 — aplcores and WS integrity.html)".

  
### The Service starts but ignores "Pause" and "Stop" requests.

This requires the log file to contain all the information we expect: calling parameters etc. In such a case we _know_ that the Service has started and is running.

* Check whether you have really called `ServiceState.Init`.
* Make sure that you have called `CheckServiceMessages` in the main loop of the application.

If these two conditions are met then it's hard to imagine what could prevent the application from reacting to any requests of the SCM, except when you have an endless loop somewhere in your application.


### The application does not do what's supposed to do.

First  and foremost it is worth mentioning that any application that is supposed to run as a Service should be developed as an ordinary application, including test cases. When it passes such test cases you have reasons to be confident that the application should run fine as a Service as well.

Having said this, there can be surprising differences between running as an ordinary application and a Service. For example, when a Service runs not with a user's account but with the system account (which is quite normal to do) any call to `#.FilesAndDirs.GetTempPath` results in

`"C:\Windows\System32\config\systemprofile\AppData\Local\Apps"` 

while for a user's account it would be something like 

`'C:\Users\{username}\AppData\Local\Temp'`.

When the application behaves in an unexpected way you need to debug it, and for that Ride is invaluable.


## Potions and wands

### Ride

First of all we have to make sure that the application provides us a Ride if we need one. Since passing any arguments for a Ride via the command line requires the Service to be uninstalled and installed at least twice we recommend preparing the Service from within the application instead.

If you have trouble to Ride into any kind of application: make sure that there is not an old instance of the Service running which might occupy the port you need for the Ride.
 
There are two very different scenarios when you might want to use Ride:

* The Service does not seem to start or does not react to "Pause" or "Stop" requests. 
* Although the Service starts fine and reacts properly to any "Pause" or "Stop" requests, the application is behaving unexpectedly.
 
In the former case make sure that you allow the programmer to Ride into the Service as soon as possible - literally. That means that the first line of the function noted on `⎕LX` should provide a Ride.

At such an early stage we don't have an INI file instantiated, so we cannot switch Ride on and off via the INI file, we have to modify the code for that. 

You might feel tempted to overcome this by doing it a bit later (read: after having processed the INI file etc.) but we warn you: if a Service does not cooperate then "a bit later" might well be too late to get to the bottom of the problem, so don't.
  
In the latter case you should add the call to `CheckForRide` once the INI file has been instanciated.

I> Make sure that you have _never_ more than one of the two calls to `CheckForRide` active: if both are active you would be able to make use of the first one but the second one would throw you out!  


## Logging


### Local logging

We want to log as soon as possible any command-line parameters as well as any message exchange between the Service and the SCM.

Again we advise you to not wait until the folder holding the log files is defined by instantiating the INI file. Instead we suggest making the assumption that a certain folder ("Logs") will (or might) exist in the current directory which will become where the workspace was loaded from.

If that's not suitable then consider passing the directory that will host the "Logs" folder as a command line parameter.


#### Windows event log

In the next chapter ("[The Windows Event Log](./14 The Windows Event Log.html)") we will discuss why and how to use the Windows Event Log, in particular when it comes to Services.


### How to implement it


#### Setting the latent expression

First of all we need to point out that `MyApp` as it stands is hardly a candidate for a Service. Therefore we have to make something up: the idea is to specify one to many folders to be watched by the `MyApp` Service.

If any files are found then those are processed. Finally the app will store hashes for all files it has processed. That allows it to recognize any added, changed or removed files efficiently.

For the Service we need to create a workspace that can be loaded by that Service. Therefore we need to set `⎕LX`, and for that we create a new function:

~~~
 ∇ {r}←SetLXForService(earlyRide ridePort)
   ⍝ Set Latent Expression (needed in order to export workspace as EXE)
   ⍝ `earlyRide` is a flag. 1 allows a Ride.
   ⍝ `ridePort`  is the port number to be used for a Ride.
      #.⎕IO←1 ⋄ #.⎕ML←1 ⋄ #.⎕WX←3 ⋄ #.⎕PP←15 ⋄ #.⎕DIV←1   
      r←⍬
      ⎕LX←'#.MyApp.RunAsService ',(⍕earlyRide),' ',(⍕ridePort)
 ∇
~~~

The function takes a flag `earlyRide` and an integer `ridePort` as arguments. How and when this function is called will be discussed in a moment.

Because we have now two functions that set `⎕LX` we shall rename the original one (`SetLX`) to `SetLXForApplication` to tell them apart.


#### Initialising the Service

Next we need the main function for the service:

~~~
 ∇ {r}←RunAsService(earlyRide ridePort);⎕TRAP;MyLogger;Config;∆FileHashes
    ⍝ Main function when app is running as a Windows Service.
    ⍝ `earlyRide`: flag that allows a very early Ride.
    ⍝ `ridePort`: Port number used by Ride.
      r←⍬
      CheckForRide earlyRide ridePort
      #.FilesAndDirs.PolishCurrentDir
      ⎕TRAP←#.HandleError.SetTrap ⍬
      (Config MyLogger)←Initial #.ServiceState.IsRunningAsService
      ⎕TRAP←(Config.Debug=0)SetTrap Config
      Config.ControlFileTieNo←CheckForOtherInstances ⍬
      ∆FileHashes←0 2⍴''
      :If #.ServiceState.IsRunningAsService
          {MainLoop ⍵}&⍬
          ⎕DQ'.'
      :Else
          MainLoop ⍬
      :EndIf
      Cleanup ⍬
      Off EXIT.OK
    ∇
~~~

Notes:

* This function allows a Ride very early indeed. 

* It calls the function `Initial` and passes the result of the function `#.ServiceState.IsRunningAsService` as right argument. We will discuss `Initial` next.

* We create a global variable `∆FileHashes` which we use to collect the hashes of all files that we have processed. This gives us an easy and fast way to check whether any of the files we've already processed got changed.

* We call `MainLoop` (a function that has not been established yet) in different ways depending on whether the function is running as a Windows Service or not for the simple reason that it is much easier to debug an application that runs in a single thread.


#### The "business logic"

Time to change the `MyApp.Initial` function:

~~~
leanpub-start-insert
 ∇ (Config MyLogger)←Initial isService;parms
leanpub-end-insert
    ⍝ Prepares the application.
leanpub-start-insert
      Config←CreateConfig isService
leanpub-end-insert
      Config.ControlFileTieNo←CheckForOtherInstances ⍬      
      CheckForRide (0≠Config.Ride) Config.Ride
      MyLogger←OpenLogFile Config.LogFolder
      MyLogger.Log'Started MyApp in ',F.PWD
      MyLogger.Log 2 ⎕NQ'#' 'GetCommandLine'
      MyLogger.Log↓⎕FMT Config.∆List
leanpub-start-insert
      :If isService
          parms←#.ServiceState.CreateParmSpace
          parms.logFunction←'Log'
          parms.logFunctionParent←MyLogger
          #.ServiceState.Init parms
      :EndIf
leanpub-end-insert
 ∇
~~~

Note that we pass `isService` as right argument to `CreateConfig`, so we must amend `CreateConfig` accordingly:

~~~
leanpub-start-insert
 ∇ Config←CreateConfig isService;myIni;iniFilename
leanpub-end-insert 
   Config←⎕NS''
   ...
leanpub-start-insert          
   Config.IsService←isService
leanpub-end-insert          
   ...         
       Config.Accents←⊃Config.Accents myIni.Get'Config:Accents'
leanpub-start-insert       
        :If isService
            Config.WatchFolders←⊃myIni.Get'Folders:Watch'
        :Else
            Config.LogFolder←'expand'F.NormalizePath⊃Config.LogFolder myIni.Get'Folders:Logs'
        :EndIf
leanpub-end-insert       
        Config.DumpFolder←'expand'F.NormalizePath⊃Config.DumpFolder myIni.Get'Folders:Errors'
   ...
 ∇
~~~

Note that `WatchFolder` is introduced only when the application is running as a Service.

Time to introduce the function `MainLoop`:

~~~
∇ {r}←MainLoop port;S
  r←⍬
  MyLogger.Log'"MyApp" server started'
  S←#.ServiceState
  :Repeat
      LoopOverFolder ⍬
      :If (MyLogger.Log S.CheckServiceMessages)S.IsRunningAsService
          MyLogger.Log'"MyApp" is about to shut down...'
          :Leave
      :EndIf
      ⎕DL 2
  :Until 0
 ⍝Done
∇
~~~

Notes:

* The call to `ServiceState.CheckServiceMessages` makes sure that the function reacts to any status change requests from the SCM.

* `LoopOverFolder` is doing the real work.

The function `LoopOverFolder`:

~~~
∇ {r}←LoopOverFolder dummy;folder;files;hashes;noOf;rc
  r←⍬
  :For folder :In Config.WatchFolders
      files←#.FilesAndDirs.ListFiles folder,'\*.txt'
      hashes←GetHash¨files
      (files hashes)←(~hashes∊∆FileHashes[;2])∘/¨files hashes
      :If 0<noOf←LoopOverFiles files hashes
          :If EXIT.OK=rc←TxtToCsv folder
              MyLogger.Log'Totals.csv updated'
          :Else
              LogError rc('Could not update Totals.csv, RC=',EXIT.GetName rc)
          :EndIf
      :EndIf
  :EndFor
∇
~~~

This function calls `GetHash` so we better introduce this:

~~~
 GetHash←{
 ⍝ Get hash for file ⍵
     ⊣2 ⎕NQ'#' 'GetBuildID'⍵
 }
~~~

The function `LoopOverFiles`:

~~~
 ∇ noOf←LoopOverFiles(files hashes);file;hash;rc
   noOf←0
   :For file hash :InEach files hashes
       :If EXIT.OK=rc←TxtToCsv file
           ∆FileHashes⍪←file hash
           noOf+←1
       :EndIf
   :EndFor
 ∇
 ~~~

This function finally calls `TxtToCsv`.

Because of the change we've made to the right argument of `Initial` we need  to change `StartFromCmdLine`; Here the function `Initial` needs to be told that it is _not_ running as a Service:

~~~
∇ {r}←StartFromCmdLine arg;MyLogger;Config;rc;⎕TRAP
...
   (Config MyLogger)←Initial #.ServiceState.IsRunningAsService
...    
~~~

Two more changes:

~~~
 ∇ {r}←Cleanup dummy
   r←⍬
   ⎕FUNTIE Config.ControlFileTieNo
   Config.ControlFileTieNo←⍬
leanpub-start-insert
   '#'⎕WS'Event' 'ServiceNotification' 0
leanpub-end-insert
 ∇
~~~ 

This disconnects the handler from the "ServiceNotification" event.

Finally we redefine what's a public function:
 
~~~
 ∇ r←PublicFns
leanpub-start-insert 
   r←'StartFromCmdLine' 'TxtToCsv' 'SetLXForApplication' 'SetLXForService' 'RunAsService'
leanpub-end-insert   
 ∇
~~~


#### Running the test cases

Now it's time to make sure that we did not break anything: double-click `MyApp.dyapp` and answer the question whether you would like to run all test cases with "y". If something does not work execute `#.Tests.RunDebug 0` and fix the problem(s).


## Installing and un-installing the Service

In order to install as well as un-install the Service we should have two BAT files: `InstallService.bat` and `Uninstall_Service.bat`. We will create these BAT files from Dyalog. For that we create a class `ServiceHelpers`:

~~~
:Class ServiceHelpers

    ∇ {r}←CreateBatFiles dummy;path;cmd;aplexe;wsid
      :Access Public Shared
    ⍝ Write two BAT files to the current directory: 
    ⍝ Install_Service.bat and Uninstall_Service.bat
      r←⍬
      path←#.FilesAndDirs.PWD

      aplexe←'"',(2 ⎕NQ'#' 'GetEnvironment' 'dyalog'),'\dyalogrt.exe"'
      wsid←'"%~dp0\MyAppService.DWS"'
      cmd←aplexe,' ',wsid,' APL_ServiceInstall=MyAppService'
     ⍝cmd,←' APLCORENAME={foldername}'
     ⍝cmd,←' DYALOG_EVENTLOGNAME={foo}'
      cmd,←' DYALOG_NOPOPUPS=1'
      cmd,←' MAXWS=64MB'
      #.APLTreeUtils.WriteUtf8File(path,'\Install_Service.bat')cmd

      cmd←⊂'sc delete MyAppService'
      cmd,←⊂'@echo off'
      cmd,←⊂'    echo Error %errorlevel%'
      cmd,←⊂'    if NOT ["%errorlevel%"]==["0"] ('
      cmd,←⊂'    pause'
      cmd,←⊂'exit /b %errorlevel%'
      cmd,←⊂')'
      #.APLTreeUtils.WriteUtf8File(path,'\Uninstall_Service.bat')cmd
     ⍝Done
    ∇

:EndClass
~~~

Notes:

* The install BAT will use the version of Dyalog used to create the BAT file, and it will call the runtime EXE.

* In case you are not familiar with `%~dp0`: this stand for "the directory this BAT file was loaded from". In other words: as long as the workspace `MyAppService.DWS` (which we have not created yet) is a sibling of the BAT file it will work.

* The setting of APLCORENAME specifies folder and name of any aplcores. 

  For example, `D:\MyAplcores\aplcore_64_16_0_Unicode_*` would specify in which folder the aplcores shall be saved and that the filenames should start with `aplcore_64_16_0_Unicode_` followed by a running number (the asterisk).

* By setting DYALOG_EVENTLOGNAME you can tell the interpreter that it should write messages to the Windows Event Log, and what name to use for this.

* The un-install BAT file will check the `errorlevel` variable. 

  If it detects an error it will pause so that one can actually see the error message even when we have just double-clicked the BAT file. We've discussed this in the chapter "[Handling errors](./07 Handling errors.html)".


## "Make" for the Service

Now it's time to create a DYAPP for the service. For that copy `Make.dyapp` as `MakeService.dyapp` and then edit it:

~~~
Target #
Load ..\AplTree\APLTreeUtils
Load ..\AplTree\FilesAndDirs
Load ..\AplTree\HandleError
Load ..\AplTree\IniFiles
Load ..\AplTree\OS
Load ..\AplTree\Logger
Load ..\AplTree\EventCodes
Load Constants
Load Utilities
Load MyApp

leanpub-start-insert 
Load ..\AplTree\ServiceState
leanpub-end-insert 
Load ..\AplTree\Tester
Load ..\AplTree\Execute
leanpub-start-insert 
Load ..\AplTree\WinSys
Load TestsForServices
leanpub-end-insert 
Load ServiceHelpers

leanpub-start-insert 
Run #.ServiceHelpers.CreateBatFiles ⍬
Run '#.⎕EX''ServiceHelpers'''
Run #.MyApp.SetLXForService 0 4599   ⍝ [1|0]: Ride/no Ride, [n] Ride port number

Load MakeService
Run #.MakeService.Run 0
leanpub-end-insert 
~~~

Notes:

* We need some more APLTree modules: `Tester`, `Execute` and `WinSys`.
* We make sure that the two BAT files for installing and un-installing the service are written to the disk.
* We delete the class `ServiceHelpers`: it is not needed for running the Service any more once we've created the BAT files.
* We set `⎕LX` by calling `SetLXForService`.
* We load the class `MakeService` and run `MakeService.Run`.


That obviously requires the class `MakeService` to be introduced:

~~~
:Class MakeService
⍝ Creates a workspace "MyAppService" which can then run as a service.
⍝ 1. Re-create folder DESTINATION in the current directory
⍝ 2. Copy the INI file template over to DESTINATION\ as MyApp.ini
⍝ 3. Save the workspace within DESTINATION
    ⎕IO←1 ⋄ ⎕ML←1
    DESTINATION←'MyAppService'

    ∇ {r}←Run offFlag;en;F;U
      :Access Public Shared
      r←⍬
      (F U)←##.(FilesAndDirs Utilities)
      (rc en more)←F.RmDir DESTINATION
      U.Assert 0=rc
      U.Assert 'Create!'##.FilesAndDirs.CheckPath DESTINATION
      'MyApp.ini.template' CopyTo DESTINATION,'\MyApp.ini'
      'Install_Service.bat' CopyTo DESTINATION,'\'
      'Uninstall_Service.bat' CopyTo DESTINATION,'\'
      ⎕WSID←DESTINATION,'\',DESTINATION
      #.⎕EX⍕⎕THIS
      0 ⎕SAVE ⎕WSID
      {⎕OFF}⍣(⊃offFlag)⊣⍬      
    ∇
    
    ∇ {r}←from CopyTo to;rc;more;msg
      r←⍬
      (rc more)←from F.CopyTo to
      msg←'Copy failed RC=' ,(⍕rc),'; ',more
      msg ⎕signal 11/⍨0≠rc
    ∇
:EndClass
~~~

Notes:

* Assigns the name of the destination folder to the global `DESTINATION`.
* (Re-)creates a folder with the name `DESTINATION`.
* Copies over the INI file as well as the two BAT files.
* Finally it sets `⎕WSID` and saves the workspace without the status indicator and without `MakeService` by deleting itself.


A> # Self-deleting code
A>
A> In case you wonder how it is possible that the function `MakeService.Run` deletes itself and keeps running anyway:
A>
A> APL code (functions, operators and scripts) that is about to be executed is copied onto the stack. You can investigate the stack at any given moment with  `)si` and `)sinl`; for details type the command in question into the session and then press F1.
A>
A> Even if the code of a class executes `⎕EX ⍕⎕THIS` or a function or operator `⎕EX ⊃⎕SI` the code keeps running because the copy on the stack will exist until the function or operator quits. Scripts might even live longer: only when the last reference pointing to a script is deleted does the script cease to exist.


## Testing the Service

We have test cases that ensure that the "business logic" of `MyApp` works just fine. What we also need are tests that make sure that it runs fine as a Service as well.

Since the two test scenarios are only loosely related we want to keep those tests separate. It is easy to see way: testing the Service means assembling all the needed stuff, installing the Service, carrying out the tests and finally un-installing the tests and cleaning up. 

We don't want to execute all this unless we really have to.

We start be creating a new script `TestsForServices` which we save alongside the other scrips in `v13/`:

~~~
:Namespace TestsForServices
⍝ Installs a service "MyAppService" in a folder within the Windows Temp directory with 
⍝ a randomly chosen name. The tests then start, pause, continue and stop the service.\\
⍝ They also check whether the application produces the expected results.

    ⎕IO←1 ⋄ ⎕ML←1

:EndNamespace
~~~

We now discuss the functions we are going to add one after the other. Note that the `Initial` function is particularly important in this scenario: we need to copy over all the stuff we need, code as well as input files, make adjustments, and install the Service.

This could all be done in a single function but it would be lengthy and difficult to read. To avoid this we split the function into obvious units. By naming those functions carefully we should get away without adding any comments because the code explains itself. Here we go:

~~~
∇ r←Initial;rc;ini;row;bat;more
   ∆Path←##.FilesAndDirs.GetTempFilename''
   #.FilesAndDirs.DeleteFile ∆Path
   ∆Path←¯4↓∆Path
   ∆ServiceName←'MyAppService'
   r←0
   :If 0=#.WinSys.IsRunningAsAdmin
       ⎕←'Sorry, but you need admin rights to run this test suite!'
       :Return
   :EndIf
   ∆CreateFolderStructure ⍬
   ∆CopyFiles ⍬
   ∆CreateBATs ⍬
   ∆CreateIniFile ⍬
   ∆InstallService ⍬
   ⎕←'*** Service ',∆ServiceName,' successfully installed'
   r←1
~~~

Note that all the sub-function and global variables start their names with `∆`. An example is the function `∆Execute_SC_Cmd`:

~~~
∇ {(rc msg)}←∆Execute_SC_Cmd command;cmd;buff
 ⍝ Executes a SC (Service Control) command
   rc←1 ⋄ msg←'Could not execute the command'
   cmd←'SC ',command,' ',∆ServiceName
   buff←#.Execute.Process cmd
   →FailsIf 0≠1⊃buff
   msg←⊃,/2⊃buff
   rc←3⊃buff
∇
~~~    

It executes `SC` commands like "start", "pause", "continue", "stop" and "query" by preparing a string and then passing it to `Execute.Process`.

It analyzes the result and returns the text part of it as well as a return code. While the first 4 commands aim to change the current status of a Service, "query" is designed to establish what the current status of a Service actually is.

After having executed the test suite we want to clean up, so we create a function `Cleanup`. 

Just a reminder: in case the test framework finds a function `Initial` it executes it _before_ executing the actual test cases, while any function  `Cleanup` will be executed _after_ the test cases have been executed.

~~~
∇ {r}←Cleanup
   r←⍬
   :If 0<⎕NC'∆ServiceName'
       ∆Execute_SC_Cmd'stop'
       ∆Execute_SC_Cmd'delete'
       ##.FilesAndDirs.RmDir ∆Path
       ⎕EX¨'∆Path' '∆ServiceName'
   :EndIf
∇
~~~

We also need `∆Pause`:

~~~
∇ {r}←∆Pause seconds
   r←⍬
   ⎕←'   Pausing for ',(⍕seconds),' seconds...'
   ⎕DL seconds
∇
~~~

We could discuss all the sub functions called by these two functions but it would tell us little. Therefore we suggest that you copy the code from the web site. We just discuss the two test functions:

~~~
∇ R←Test_01(stopFlag batchFlag);⎕TRAP;rc;more
  ⍝ Start, pause, continue and stop the service.
  ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
  R←∆Failed
 
  (rc more)←∆Execute_SC_Cmd'start'
  →FailsIf 0≠rc
  ∆Pause 2  
  (rc more)←∆Execute_SC_Cmd'query'
  →FailsIf 0≠rc
  →FailsIf 0=∨/'STATE : 4 RUNNING'⍷#.APLTreeUtils.dmb more
 
  (rc more)←∆Execute_SC_Cmd'pause'
  →FailsIf 0≠rc
  ∆Pause 2
  →FailsIf 1≠⍴#.FilesAndDirs.ListFiles ∆Path,'\service\Logs\'
  (rc more)←∆Execute_SC_Cmd'query'
  →FailsIf 0=∨/'STATE : 7 PAUSED'⍷#.APLTreeUtils.dmb more
 
  (rc more)←∆Execute_SC_Cmd'continue'
  →FailsIf 0≠rc
  ∆Pause 2
  (rc more)←∆Execute_SC_Cmd'query'
  →FailsIf 0=∨/'STATE : 4 RUNNING'⍷#.APLTreeUtils.dmb more
 
  (rc more)←∆Execute_SC_Cmd'stop'
  →FailsIf 0≠rc
  ∆Pause 2
  (rc more)←∆Execute_SC_Cmd'query'○
  →FailsIf 0=∨/'STATE : 1 STOPPED'⍷#.APLTreeUtils.dmb more
 
  R←∆OK
∇
~~~

In order to understand the `→FailsIf` statements it is essential to have a look at a typical result returned by the `∆Execute_SC_Cmd` function, in this case a "query":

~~~
      ⍴more
328
      ≡more
1
      #.APLTreeUtils.dmb more
SERVICE_NAME: MyAppService TYPE : 10 WIN32_OWN_PROCESS STATE : 4 RUNNING (STOPPABLE, PAUSABLE, ACCEPTS_SHUTDOWN) WIN32_EXIT_CODE : 0 (0x0) SERVICE_EXIT_CODE
       : 0 (0x0) CHECKPOINT 
~~~

Note that we have removed multiple blanks here in order to increase readability. The reason is that the result carries plenty of them.

This test starts, pauses, continues and finally stops the Service after having processed some files:

~~~
∇ R←Test_02(stopFlag batchFlag);⎕TRAP;rc;more;noOfCSVs;success;oldTotal;newTotal;A;F
  ⍝ Start service, check results, give it some more work to do, check and stop it.
   ⎕TRAP←(999 'C' '. ⍝ Deliberate error')(0 'N')
   R←∆Failed
   (A F)←#.(APLTreeUtils FilesAndDirs)
 
   (rc more)←∆Execute_SC_Cmd'start'
   →FailsIf 0≠rc
   ∆Pause 1
   (rc more)←∆Execute_SC_Cmd'query'
   →FailsIf 0=∨/'STATE : 4 RUNNING'⍷A.dmb more
 
   ⍝ At this point the service will have processed all the text files, so there
   ⍝ must now be some CSV files, including the Total.csv file.
   ⍝ We then copy 6 more text files, so we should see 6 more CSVs & a changed Total.
   oldTotal←↑{','A.Split ⍵}¨A.ReadUtf8File ∆Path,'\input\en\total.csv'
   noOfCSVs←⍴F.ListFiles ∆Path,'\input\en\*.csv'
   (success more list)←(∆Path,'\texts')F.CopyTree ∆Path,'\input\'  ⍝ All of them
   {1≠⍵:.}success
   ∆Pause 2
   newTotal←↑{','A.Split ⍵}¨A.ReadUtf8File ∆Path,'\input\en\total.csv'
   →PassesIf(noOfCSVs+6)=⍴F.ListFiles ∆Path,'\input\en\*.csv'
   →PassesIf oldTotal≢newTotal
   oldTotal[;2]←⍎¨oldTotal[;2]
   newTotal[;2]←⍎¨newTotal[;2]
   →PassesIf oldTotal[;2]∧.≤newTotal[;2]
 
   (rc more)←∆Execute_SC_Cmd'stop'
   →FailsIf 0≠rc
   ∆Pause 2
   (rc more)←∆Execute_SC_Cmd'query'
   →FailsIf 0=∨/'STATE : 1 STOPPED'⍷A.dmb more
 
   R←∆OK
∇
~~~

Though this test starts and stops the Service, it's real purpose is to make sure that the Service processes input files as expected.

### Running the tests

First we need to make sure that everything is assembled freshly, and with admin rights. 

The best way to do that is to run the script `MakeService.dyapp` from a console that was started _with admin rights_. This is because unfortunately you cannot right-click on a DYAPP and select "Run as administrator" from the context menu.

Note that you _must_ change the current directory in the console window to where the DYAPP lives before actually calling it.

A> # Console with admin rights.
A> 
A> The best way to start a console window with admin rights:
A>
A> 1. Press the Windows key.
A> 1. Type "cmd"; if you are tempted to ask "where shall I type this into" then don't - just type.
A> 1. Right-click on "Command prompt" and select "Run as administrator".

A Dyalog instance is started. In the session you should see something similar to this:

~~~
Booting C:\...\v13\MakeService.dyapp
Loaded: #.APLTreeUtils
Loaded: #.FilesAndDirs
Loaded: #.HandleError
Loaded: #.IniFiles
Loaded: #.OS
Loaded: #.Logger
Loaded: #.EventCodes
Loaded: #.Constants
Loaded: #.Utilities
Loaded: #.MyApp
Loaded: #.ServiceState
Loaded: #.Tester
Loaded: #.Execute
Loaded: #.WinSys
Loaded: #.TestsForServices
Loaded: #.ServiceHelpers
#.⎕EX'ServiceHelpers'
Loaded: #.MakeService
~~~

In the next step establish the test helpers by calling `#.TestsForServices.GetHelpers`.

Finally run `#.TestsForServices.RunDebug 0`. You should see something like this:

~~~
#.TestsForServices.RunDebug 0
--- Test framework "Tester" version 3.3.0 from YYYY-MM-DD -----------------------------
Searching for INI file testcases_APLTEAM2.ini
  ...not found
Searching for INI file Testcases.ini
  ...not found
Looking for a function "Initial"...
*** Service MyAppService successfully installed
  "Initial" found and sucessfully executed
--- Tests started at YYYY-MM-DD hh:mm:dd on #.TestsForServices ------------------------
   Pausing for 2 seconds...
   Pausing for 2 seconds...
   Pausing for 2 seconds...
   Pausing for 2 seconds...
  Test_01 (1 of 2) : Start, pause and continue the service.
   Pausing for 2 seconds...
   Pausing for 2 seconds...
   Pausing for 2 seconds...
  Test_02 (2 of 2) : Start service, check results, give it some more work to do, check and stop it.
 -------------------------------------------------------------------------------------------------- 
   2 test cases executed
   0 test cases failed
   0 test cases broken
Time of execution recorded on variable #.TestsForServices.TestCasesExecutedAt in: YYYY-MM-DD hh:mm:ss
Looking for a function "Cleanup"...
  Function "Cleanup" found and sucessfully executed.
*** Tests done

~~~

[^aplcore]: More information regarding aplcores is available in "[Appendix 3 — aplcores and WS integrity](52 Appendix 3 — aplcores and WS integrity.html).
























































*[HTML]: Hyper Text Mark-up language
*[DYALOG]: File with the extension 'dyalog' holding APL code
*[TXT]: File with the extension 'txt' containing text
*[INI]: File with the extension 'ini' containing configuration data
*[DYAPP]: File with the extension 'dyapp' that contains 'Load' and 'Run' commands in order to compile an APL application
*[EXE]: Executable file with the extension 'exe'
*[BAT]: Executeabe file that contains batch commands
*[CSS]: File that contains layout definitions (Cascading Style Sheet)
*[MD]: File with the extension 'md' that contains markdown
*[CHM]: Executable file with the extension 'chm' that contains Windows Help(Compiled Help) 
*[DWS]: Dyalog workspace
*[WS]: Short for Workspaces