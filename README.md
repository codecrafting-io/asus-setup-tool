# ASUS Setup Tool

![ASUS Setup Tool](/Source/Images/title.png?raw=true)

[![GitHub Release](https://img.shields.io/github/v/tag/codecrafting-io/asus-setup-tool?label=version)](https://github.com/codecrafting-io/asus-setup-tool/releases)
[![Issues](https://img.shields.io/github/issues/codecrafting-io/asus-setup-tool)](https://github.com/codecrafting-io/asus-setup-tool/issues)
[![Github All Releases](https://img.shields.io/github/downloads/codecrafting-io/asus-setup-tool/total?color=blueviolet)](https://github.com/codecrafting-io/asus-setup-tool/releases)
[![Reddit](https://img.shields.io/badge/Reddit-%23FF4500.svg?logo=Reddit&logoColor=white)](https://reddit.com/r/ASUS/comments/15ij4wv/i_created_a_tool_that_finally_manages_to_properly/?sort=confidence)

This is an PowerShell script tool that manages the setup installation for the legacy [Aura Sync](https://www.ASUS.com/campaign/aura), LiveDash, [AiSuite3](https://www.youtube.com/watch?v=MVS2Bx8Uofg), to FINNALY resolve installation errors on **Windows 10/11**. With this tool, you will:

- Download Aura Sync, LiveDash, AiSuite3 directly from ASUS site.
- Proper uninstall all ASUS products and pieces of software, including Armoury Crate.
- Patch ASUS setup files for a correct installation, mostly resolving `AsIO` errors.
- Choose which modules from Aura Sync you want.
- Install Aura Sync, LiveDash (optional), AiSuite 3 (optional).

## Preparations

**NOTE: Before you proceed, note that this tool is experimental, still in early stages, provided as is and may not work or require manual tweaking.**

- Create a System Restore point (recommended), [Instructions Here](https://support.microsoft.com/en-us/windows/create-a-system-restore-point-77e02e2a-3298-c869-9974-ef5658ea3be9#:~:text=In%20the%20search%20box%20on,and%20then%20select%20Create%20%3E%20OK.)
- Download [ASUS Setup Tool here](/../../releases/download/v0.7.1/Asus-Setup-Tool.zip).
- Extract the zip contents to a folder.
- The [Windows core insolation](https://www.makeuseof.com/core-isolation-memory-integrity-windows/#:~:text=On%20the%20left%20side%20menu%20of%20the%20Windows%20Security%20app,the%20changes%20to%20take%20effect.) can interfere with the operation of ASUS Kernel drivers, so you may have to disable it.
- If you have a third party antivirus, you **may have to disable file and thread security check features or even uninstall it**. After this reboot the system and then proceed. You can re-enable/re-install the antivirus later.
- For Intel CPUs you may have to disable "Execute Disable Bit" in BIOS settings.
- Using ArmouryCrate with AuraSync is possible but not recommended.

## Instructions

- Right click on `setup.bat` and `run as administrator`.
- For question prompts, `[Y] Yes [N] No` just type `Y` or `N` followed by `ENTER`
- At this point, you should see a screen like that:

    ![ASUS Setup Tool first screen](/Source/Images/screen1.png?raw=true)

- In case you see an "PowerShell file script policy execution is restricted", type `[ENTER]` to execute an POWERSHELL script to set to `Bypass` for the process scope, still allowing to execute the setup, like in the screen below:

    ![ASUS Setup Tool powershell execution policy](/Source/Images/screen2.png?raw=true)

- Choose `Y` for just uninstall apps, or `n` no to select which apps to install. The setup will first uninstall everything.

    ![ASUS Setup Tool AuraSync version](/Source/Images/screen3.png?raw=true)

- Select which version of AuraSync you want, by typing `1`, `2`, `3` to no install:
  - 1 - **NEW:** Version **1.07.84_v2** if you want the latest hardware support available, but this version has more bloated modules, which leads to more processes running on the system.
  - 2 - **OLD:** Version **1.07.66** has a less bloated module installation, but may not have support for products launched after 2020.
  - 3 - **Do not install:** Use this to **not** install aura sync.

- Choose if you want to install LiveDash. **The installation of LiveDash requires patching LightingService, which may lead to incompatibility for products launched after 2020. This will also affect AuraSync installation.**. The "OLD" AuraSync version recommended if you install LiveDash.
- Choose if you want to install AiSuite3. Notice that if you had AiSuite3 installed prior to executing ASUS Setup Tool, a reboot is required. You can install manually later. In this case, you can find AiSuite3 inside `Apps` folder.
- The selected applications will be downloaded along with the Armoury Crate Uninstall Tool. AiSuite3 is used to set up some services correctly, but installation is optional. If you choose "Uninstall only", only the Uninstall Tool will be downloaded.
- The uninstallation of all ASUS products will begin. This **will remove any related ASUS Software!**. This **process can take several minutes, please wait**.

    ![ASUS Setup Tool installation step](/Source/Images/screen5.png?raw=true)

- After the download and uninstall process, patches will be applied to the installation. If you chose to install AuraSync and/or LiveDash in this step, you can select which modules you want by typing `Y` to the next question. AuraSync has a modular component design to control a variety of devices. By default, the setup will install all modules even if you don't have the device. If you want a cleaner installation, you can check here which modules are relevant for your case. Some brand specific modules is usually to control RGB Ram with AuraSync. If you don't want to use AuraSync to control them, don't check it. However if you want to control the RAM you need to check "RAM" + the specific brand module if exist If you type `n` all modules will installed.

    ![ASUS Setup Tool add modules](/Source/Images/screen4.png?raw=true)

- The installation process will begin. In this step you can choose if you want let Asus services and tasks to start with Windows. By typing `N` ASUS Tasks (mostly for ASUS Update) and the services `ASUS Com Service`, `ASUS HM Com Service` (LiveDash only), `AsusCertService` and `LightingService` will be set to manual startup, ie only starting by demand. The reason behind this is to leave a minimal or no extra processes running if they don't need to. It's not necessary to leave `LightingService`, `ASUS COM Service`, `ASUS Cert Service` running all the time to keep your RGB settings for many type of devices. Note that when services are set to manual, the applications will take longer to start.

    ![ASUS Setup Tool Finished](/Source/Images/screen6.png?raw=true)

Finally, if everything went well you now have a functional installation of AuraSync, LiveDash or AiSuite 3

![ASUS Setup Tool Finished](/Source/Images/screen7.png?raw=true)

![Yea Baby](https://www.memesmonkey.com/images/memesmonkey/ba/ba0418a6baea139993fc38eb95f5da04.jpeg)

## Automatic set of profiles

If you create a folder "Profiles" inside "Patches" and put the files `LastProfile.xml` and `OledLastProfile.xml` from previous `LightingService` installations, the ASUS Setup Tool will set those profiles after the installation. Those profiles can be located in `%PROGRAMFILES(X86%)\LightingService` folder after installation and configuration.

## Known Issues

Some of known issues:

- AuraSync takes too long to open: This can happen due to the module's initialization of `LightingService`. You can opt to not install some modules during setup.
- AuraSync is not opening: This is due to `LightingService` not running or even not installed.
  - Reboot the system.
  - Go to the `Apps\AuraSync` folder of the ASUS Setup Tool and locate the `AuraServiceSetup.exe` file inside `LightingService` folder.
  - Run the setup to check if shows a button with `uninstall`. If so, uninstall it and rerun the ASUS Setup Tool again.

    ![ASUS Setup Tool LightingService uninstall](/Source/Images/screen8.png?raw=true)

- LightingService failed to install: This usually happens due to failure of installation of `LightingService`. Reboot the system and run ASUS Setup Tool again or execute the steps above.
- Waiting to service stop: Sometimes some services or running drivers don't have an easy stop during the uninstallation. Reboot the system and try again.
- The InstallShield Engine could not be installed: This likely happens during the uninstallation of one of the Apps, as a result of setup interruption or failure to uninstall. Click ok and then proceed. This won't interfere on uninstallation.
- The `GET ASUS SETUP` fails: This can happen if you interrupt the process and tried again later. Just run Asus Setup again.
- The `SET ASUS SERVICE` fails: Reboot the system and try again. You may have to disable or uninstall the antivirus or Windows core isolation.
- The POWERSHELL file script execution are managed by a group policy. When the execution policy of POWERSHELL file scripts are managed by a system group policy (User or Machine), you have to change to at least `RemoteSigned (allow local and remote)` before proceed. Check more with [this link](https://www.youtube.com/watch?v=zW69MisrsWk) to see more.
- POWERSHELL is not in "FullLanguage" mode. When POWERSHELL is not set to "FullLanguage" mode, it is not possible to run the setup properly. To see more, check [this link](https://youtu.be/zW69MisrsWk?si=xLg4FjN4tbdveeP7&t=142).
- Failed to remove file. Restart the pc and try again. Sometimes files fail to remove, so restart the PC and try again.
- Failed to remove service. Sometimes services failed to be removed, reboot and try again
- Failed to remove AiSuite3. Reboot and try again.
- AuraSync does not detect my devices. This is due to LightingService not being started or not detecting devices properly. Try the new AuraSync version and select only the modules that fit your needs. If that doesn't work and your product is released after the first half of 2023, AuraSync may simply not support it.
- Asus Cert Service still running at startup. After AXSP service version 4.02.32, it changes Asus Cert Service to automatic every time the service is started. The only solution is to downgrade to version 4.02.23 (present on <=v0.6.0), or manually revert to manual startup every time.

## Still have problems?

Sometimes it is very difficult to understand the behavior of Asus software, especially related to system or antivirus blocking actions. If you still have problems with this tool, open a [issue](https://github.com/codecrafting-io/asus-setup-tool/issues), print your terminal and send the latest log file inside `Source\Log`.

## Settings

Inside `Source` folder have a `settings.json` configuration file which determines URLs for downloading the applications. Note if you change it, you must update hash file integrity validation.

## How it works

This was years in the making, trying to understand what's going on every spare time that I had. ASUS software still to this day is messy, bloated and potentially insecure. For many people this tool may not even be ideal to be frank, you may want to ditch ASUS products or even go for alternative software like [OpenRGB](https://openrgb.org/), [FanContol](https://getfancontrol.com/), [SignalRGB](https://signalrgb.com/).

One of the main issues of ASUS software, it's the **dependency nightmare**. Multiple setups depend on the same library, services and assets, but that aren't consistent between installations. ASUS has a very modular setup, which can be seen as a good thing, but not in the way it was implemented, with almost no cohesion, and end up with a lot of services and maybe unnecessary Kernel level access drivers. ASUS software has the following key software components:

- ASUS COM Service (atkexCom, aka AXSP)
- ASUS Cert Service
- AsIO 2 and 3 Kernel Drivers
- LightingService Windows service

In the past the ASUS Cert Service did not exist, but after the [vulnerabilities](https://syscall.eu/blog/2020/03/30/asus_gio/) and the [Signature SSL Key was compromised](https://www.vice.com/en/article/pan9wn/hackers-hijacked-asus-software-updates-to-install-backdoors-on-thousands-of-computers), ASUS created this extra service in an attempt to mitigate the issues. So on specially Windows 11 ASUS Com Service that used to come on older AuraSync setups stopped from working.

Knowing this, what is done here was:

- Create a better consistent dependency services and assets, for ASIO, AXSP, using the latest files from Armoury Crate installation. You can find them on `Patches` folder
- Proper setup of AXSP and AsusCertService before AuraSync/LiveDash installation. The easiest way found was just launching the AiSuite 3 setup. When launched, both services are installed, even if you don't do anything in the wizard setup. The ASUS Setup quickly launches the AiSuite 3 after being patched and as soon the wizard opens the services are installed and setup can be closed.
- Patch LightingService to work with LiveDash. In case you install LiveDash, is necessary to replace the file `MBIsSupported.dll` for the LightingService present on AuraSync version 1.07.60. Without that patching, it is very likely you see a message like `ASUS's device no found !!` or the App won't even open. After decompiling the application, it was noticed that relation looking inside the section of `MainWindow.xaml.cs` function:

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

- This will determine what kind of device you have installed, and despite AuraSync may work and detect the products, LiveDash won't. If the `Oled_GetCapability` returns an XML with `<AsusMB>0</AsusMB>` the LiveDash won't work or even open for motherboard products.
- To "fix this" it is necessary to set the AXSP, ASIO2/ASIO3 first, update the MBIsSupported.dll, and an older ASIO have to be installed in SysWOW64 drivers, which can be done by the files inside "Io" folder of LiveDash setup. This Io folder contains the ASIO2, but a different one, so not all of them are installed when ASIO2 already is, resulting in only installing ASIO inside SysWOW64.
- The older AuraSync 1.07.60 was found in [this link](https://www.reddit.com/r/ASUS/comments/eh1ouk/asus_aura_archived_versions/).
- I believe that replacing the MBIsSupported.dll may result in incompatibility with newer Motherboards released after 2020, but I can't test this.
- Decompiling the `MBIsSupported.dll` is much more dificult since is C++ library, and I don't think is worth it to change the LiveDash app code, so for now it's the best solution found with the least alteration of the existing files.

## Final considerations

I don't have a lot of experience with .NET or PowerShell projects, so help is welcome to this project, especially in relation to LiveDash installation. Another thing is about [VirusTotal](https://www.virustotal.com/gui/file/f4965ac6b5894628fa78201d83d0c790916f5e1f4ae30ff966127b1cbda9c3cc/relations) detections, all patches assets used are from the latest ArmouryCrate, **so install them at your own risk**.

This tool was making in the feeling of **REALLY NOT LIKING ARMOURY CRATE**. I hope this helps to finally bring some balance to the force 😁

> Made with :heart: by [@lucasmarotta](https://github.com/lucasmarotta)
