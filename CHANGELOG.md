# Changelog

## v0.6.0

- Reworked setup flow. Main questions are asked first now
- Improved 'CLEAR ASUS BLOATWARE' step
- Added uninstall only option
- UninstallTool progress bar window is now hidden due to version 2.2.5.0
- Fixed a error when UninstallTool is not downloaded or extracted
- Set services and tasks to start with Windows question not attached to automatic profiles

## v0.5.1

- Updated references for UninstallTool version 2.2.5.0

## v0.5.0

- Added LiveDash warning before answering question
- Changed installation process to allow installation of LiveDash only
- Fixed error when installing AiSuite3 only
- Improved removal of services and drivers
- Improved update of services dependencies
- Reworked internally GET ASUS SETUP step
- Separated functions module in two: setup and utils
- Show AuraSync version question first
- Show selected AuraSync modules

## v0.4.0

- Improved removal of files
- Migrated internal settings to lock file

## v0.3.2

- Updated references for the new UninstallTool
- Improved message for UninstallTool integrity check

## v0.3.1

- Added POWERSHELL execution policy handling for when it's managed by a system group policy.
- Added handling for POWERSHELL language restriction modes.
- Reduced setup size

## v0.3.0

- Improved POWERSHELL execution policy handling
- Improved removal of ASUS services and drivers
- Improved removal of apps
- Reduced setup size
- Improved compatibility for LiveDash setup
- Added LiveDash support for AuraSync 1.07.84
- Added choice for AuraSync installation version
- Improved file check integrity
- Improved downloading of apps
- Added option to only install AiSuite3
- Windows 10 support

## v0.2.2

- Improved removal of ASUS services and drivers
- Remove Ryzen Master driver added by AiSuite 3 when not uninstalled

## v0.2.1

- Minor code revision
- Correction of some typos

## v0.2.0

- Added support for AuraSync 1.07.84 (LiveDash is only compatible with 1.07.79)
- Added optional setup profiles for `LightingService` after installation
- Fixed emoji corruption
- Improved AuraSync uninstallation
- Added handling of POWERSHELL file script execution policy
- Added repo badges

## v0.1.3

- Fixed option to not install LiveDash
- Removed duplicated check integrity

## v0.1.2

- Fixed file integrity check due to differences of EOL on files

## v0.1.1

- Added file integrity check

## v0.1.0

- First release
