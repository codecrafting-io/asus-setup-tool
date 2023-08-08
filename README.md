# ASUS Setup Tool

![ASUS Setup Tool](/Source/Images/title.png?raw=true)

[![GitHub Release](https://img.shields.io/github/v/tag/codecrafting-io/asus-setup-tool?label=version)]()
[![Github All Releases](https://img.shields.io/github/downloads/codecrafting-io/asus-setup-tool/total)]()
[![Issues](https://img.shields.io/github/issues/codecrafting-io/asus-setup-tool)](https://github.com/codecrafting-io/asus-setup-tool/issues)

This is an PowerShell script tool that manages the setup installation for the legacy [Aura Sync](https://www.ASUS.com/campaign/aura), LiveDash, [AiSuite3](https://www.youtube.com/watch?v=MVS2Bx8Uofg), to FINNALY resolve installation errors on Windows 11. With this tool, you will:

- Download Aura Sync, LiveDash, AiSuite3 directly from ASUS site.
- Proper uninstall all ASUS products and pieces of software, including Armoury Crate.
- Patch ASUS setup files for a correct installation, resolving errors like `AsIO no found`, `AsIO access denied`
- Choose which modules from Aura Sync you want.
- Install Aura Sync, LiveDash (optional), AiSuite 3 (optional).

**NOTE: This tool was only tested for Windows 11 and may not work on Windows 10.**

## Instructions

**NOTE: Before you proceed, note that this tool is experimental, still in early stages, provided as is and may not work or require manual tweaking.**

- Create a System Restore point (recommended), [Instructions Here](https://support.microsoft.com/en-us/windows/create-a-system-restore-point-77e02e2a-3298-c869-9974-ef5658ea3be9#:~:text=In%20the%20search%20box%20on,and%20then%20select%20Create%20%3E%20OK.)
- Download [ASUS Setup Tool here](/../../archive/refs/tags/v0.2.0.zip).
- Extract the zip contents to a folder.
- If you have a third party antivirus, you **may have to add the setup to exclusions, disable or even uninstall it**, specially if it is a Kaspersky product. After this reboot the system and then proceed. You can re-enable/re-install the antivirus later.
- Right click on `setup.bat` and `run as administrator`.
- For question prompts, `[Y] Yes [N] No` just type `Y` or `N` followed by `ENTER`
- At this point, you should see a screen like that:

    ![ASUS Setup Tool first screen](/Source/Images/screen1.png?raw=true)

  - In case you see an "PowerShell file script policy execution is disabled", type `[ENTER]` to open an new POWERSHELL window with the execution policy set to `RemoteSigned` for the process scope, still allowing to execute the setup, like in the screen below:

    ![ASUS Setup Tool first screen](/Source/Images/screen7.png?raw=true)

- Choose if you want to install LiveDash. **Note that the installation of LiveDash implies using older Aura Sync dependencies, which may be incompatible with products released after 2020. This will also affect AuraSync installation.**
- The tools LiveDash (if you chose), AuraSync, AiSuite 3, Armoury Uninstall Tool will be downloaded. The AiSuite3 is downloaded for correctly setting some services, but installation is optional.
- After the download and patches applied, you should see an option to choose which AuraSync modules you want to add. Mark the checkboxes for the modules you want. AuraSync have a modular component design to control a variety of devices. By the default, the setup will install all modules even if you don't have the device. If you want a cleaner installation, you can check here which modules are relevant for your case. If you type `N` you should see the following screens:

    ![ASUS Setup Tool add modules](/Source/Images/screen2.png?raw=true)

  - Some modules for brand specific is usually to control RGB Ram with AuraSync. If you don't want to use AuraSync to control them, don't check.
- The uninstallation of all ASUS products will begin. This **will remove any related ASUS Software!**. During the uninstallation, the Armoury Crate Uninstall window will show up. This **process can take several minutes, please wait**.
- After uninstallation, you should choose if you want to install the apps now. Use this if you only wanted to uninstall ASUS software.

    ![ASUS Setup Tool installation step](/Source/Images/screen3.png?raw=true)

- Choose if you want to install AiSuite3. Notice that if you had AiSuite3 installed prior to executing ASUS Setup Tool, a reboot is required to proceed with manual installation. In this case, you can find AiSuite3 inside `Apps` folder.

    ![ASUS Setup Tool AiSuite 3 installation](/Source/Images/screen4.png?raw=true)

- You can choose to reboot system now (recommended) or later

    ![ASUS Setup Tool AiSuite 3 reboot](/Source/Images/screen5.png?raw=true)

- Finally, if everything went well you now have a functional installation of AuraSync, LiveDash or AiSuite 3!

    ![ASUS Setup Tool Finished with success](https://www.memesmonkey.com/images/memesmonkey/ba/ba0418a6baea139993fc38eb95f5da04.jpeg)

## Automatic set of profiles

If you create a folder "Profiles" inside "Patches" and put the files `LastProfile.xml` and `OledLastProfile.xml` from previous `LightingService` installations, the ASUS Setup Tool will set those profiles after the installation. Also, a new option will appear to set "Set services to manual startup and disable tasks". This will disable ASUS Tasks (mostly for ASUS Update), update the services `ASUS Com Service`, `ASUS HM Com Service` (LiveDash only), `AsusCertService` and `LightingService` to manual startup, and also update their dependencies to they start properly when launching the applications. Note, the apps may take a while to start using this.

## Known Issues

Some of known issues:

- AuraSync takes too long to open: This can happen due to the module's initialization of `LightingService`. You can opt to no install some modules during setup.
- AuraSync is not opening: This is due to `LightingService` not running or even not installed.
  - Reboot the system.
  - Go to the `Apps\AuraSync` folder of the ASUS Setup Tool and locate the `AuraServiceSetup.exe` file inside `LightingService` folder.
  - Run the setup to check if shows a button with `uninstall`. If so, uninstall and rerun the ASUS Setup Tool again.

    ![ASUS Setup Tool LightingService uninstall](/Source/Images/screen6.png?raw=true)

- Aura Sync failed to install: This usually happens due to failure of installation of `LightingService`. Reboot the system and run ASUS Setup Tool again.
- Waiting to service stop: Sometimes some services or running drivers don't have an easy stop during the uninstallation. Reboot the system and try again.
- The `GET ASUS SETUP` fails: This usually happens due to changing a setup from with to without LiveDash or vice versa. Just try again.
- The `SET ASUS SERVER` fails: Reboot the system and try again. You may have to disable or uninstall the antivirus.
- The [Windows core insolation](https://www.makeuseof.com/core-isolation-memory-integrity-windows/#:~:text=On%20the%20left%20side%20menu%20of%20the%20Windows%20Security%20app,the%20changes%20to%20take%20effect.) can interphere with the operation of ASUS Kernerl drivers.

If you still have errors using the tool, open a PowerShell as a Administrator, navigate to the directory where you extract the tool, type the command `$global:DebugPreference = 'Continue'` and then `.\Setup.bat` to run ASUS Setup Tool. Copy the text for a `.txt` file and open a issue.

## Settings

Inside `Source` folder have a `settings.json` configuration file which determines URLs for downloading the applications. Note if you change it you must update hash file integrity validation.

## How it works

This was years in the making, trying to understand what's going on every spare time that I had. ASUS software still to this day is messy, bloated and potentially insecure. For many people this tool may not even be ideal to be frank, you may want to ditch ASUS products or even go for alternative software like [OpenRGB](https://openrgb.org/), [FanContol](https://getfancontrol.com/), [SignalRGB](https://signalrgb.com/).

One of the main issues of ASUS software, it's the **dependency nightmare**. Multiple setups depend on the same library, services and assets, but that aren't consistent between installations. ASUS has a very modular setup, which can be seen as a good thing, but not in the way it was implemented, with almost no cohesion, and end up with a lot of services and maybe unnecessary Kernel level access drivers. ASUS software have key software components:

- ASUS COM Service (atkexCom, aka AXSP)
- ASUS Cert Service
- AsIO 2 and 3 Kernel Drivers

In the past the ASUS Cert Service did not exist, but after the [vulnerabilities](https://syscall.eu/blog/2020/03/30/asus_gio/) and the [Signature SSL Key was compromised](https://www.vice.com/en/article/pan9wn/hackers-hijacked-asus-software-updates-to-install-backdoors-on-thousands-of-computers), ASUS created this extra service in an attempt to mitigate the issues. So on specially Windows 11 ASUS Com Service that used to come on older AuraSync setups stopped from working.

Knowing this, what is done here was:

- Create a better consistent dependency services and assets, for ASIO, AXSP, using the latest files from Armoury Crate installation. You can find them on `Patches` folder
- Proper setup of AXSP and AsusCertService before AuraSync/LiveDash installation. The easiest way found was just launching the AiSuite 3 setup. When launched, both services are installed, even if you don't do anything in the wizard setup. The ASUS Setup quickly launches the AiSuite 3 after being patched and as soon the wizard opens the services are installed and setup can be closed
- LiveDash was the hardest to understand, and the solution found still not optimal but functional. The problem of installing LiveDash after or before AuraSync is that it is very likely you see a message like `ASUS's device no found !!` or the App won't even open. After decompiling the application, it was noticed that was related to the LightingService and MBIsSupported.dll, but not entirely. This section inside `MainWindow.xaml.cs` is key for LiveDash function:

    ```c#
    private void GetCOMService()
    {
        try
        {
            //Calls LightingService
            Type typeFromProgId = Type.GetTypeFromProgID("AsRogAuraService.ServiceMediator");
            object instance = Activator.CreateInstance(typeFromProgId);
            object[] args = new object[0];

            //Returns a XML that supposedly is dinamically built from LightingService (no LastProfile.xml or OledLastProfile.xml)
            this.m_XmlCap = (string) typeFromProgId.InvokeMember("Oled_GetCapability", BindingFlags.InvokeMethod, (Binder) null, instance, args);


            new Thread(new ThreadStart(this.ComService_Oled_RestoreLastProfile)).Start();
            ParsingXML parsingXml = new ParsingXML(this.m_XmlCap);
        }
        catch (Exception ex)
        {
            MainWindow.OutputDebugString("********" + ex.ToString());
        }
    }
    ```

- This will determine what kind of device you have installed, and despite AuraSync may work and detect the products, LiveDash won't. If the `Oled_GetCapability` returns an XML with `<AsusMB>0</AsusMB>` the LiveDash won't work or even open for motherboard products. In order to "fix this" it was necessary to get the older `AuraServiceSetup.exe` aka LightingService, and most importantly the `AacMBSetup.exe` from [AuraSync 1.07.22](https://www.reddit.com/r/ASUS/comments/eh1ouk/asus_aura_archived_versions/).
- The older `AacMBSetup.exe` and `AuraServiceSetup.exe` replaces the existing setups inside AuraSync before installation. Strangely enougth the main components of `AacMBSetup.exe` are the dlls `Aac3572MbHal` aren't the cause of incompatibility, so because of this the newer `AacMBSetup.exe` is reinstalled after to make AuraSync functions properly. The key thing here is something is register in the system using the old `AacMBSetup.exe` which makes LiveDash, even if it doesn't depend on it.
In addition to this, the old `LightingService.exe` is also required to LiveDash actually works, not just launch.

## Final considerations

I don't have a lot of experience with .NET or PowerShell projects, so feel free to help to improve this project and the setup process, specially in relation to LiveDash installation. Another thing is about [VirusTotal](https://www.virustotal.com/gui/file/78bde958298ff88d674a11d3ab17aac0dcad324e86e86b39f45297a996b8ab80/relations) detections, all patches assets used are from the latest ArmouryCrate, and the older `AacMBSetup.exe` and `AuraServiceSetup` are necessary for LiveDash installtion in the current state of the tool, **so use this tool at your own risk**.

It's not necessary to leave `LightingService`, `ASUS COM Service` running all the time to keep your RGB settings. Once you set, you can [open the services](https://www.wikihow.com/Open-Windows-Services) to open the properties of each service and set the initialization type for manual. You only need to reopen the AuraSync if a power loss happens.

This tool was making in the feeling of **REALLY NOT LIKING ARMOURY CRATE**. I hope this helps, I finally bring some balance to the force 😁

> Made with :heart: by [@lucasmarotta](https://github.com/lucasmarotta).
