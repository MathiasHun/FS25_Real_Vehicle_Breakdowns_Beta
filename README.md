# FS25_gameplay Real Vehicle Breakdowns Beta

![image](https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta/blob/main/webicon_vehicleBreakdown_NEW.png)

<div style="display: inline-flex; align-items: center;">
  <a href="https://www.youtube.com/watch?v=nu9aUVNbP1o" target="_blank" style="display: inline-block;">
    <img src="https://upload.wikimedia.org/wikipedia/commons/b/b8/YouTube_play_button_icon_%282013%E2%80%932017%29.svg" 
         style="width: 100px; height: auto; margin-left: 5px;">
  </a>
</div></br>
<div style="display: inline-flex; align-items: center;">FS25 Real Vehicle Breakdowns with mod</br>
  <a href="https://www.youtube.com/watch?v=JYzBIWSU2MU" target="_blank" style="display: inline-block;">
    <img src="https://upload.wikimedia.org/wikipedia/commons/b/b8/YouTube_play_button_icon_%282013%E2%80%932017%29.svg" 
         style="width: 100px; height: auto; margin-left: 5px;">
  </a>
</div></br>
<div style="display: inline-flex; align-items: center;">FS25 Real Vehicle Breakdowns without mod</br>
  <a href="https://www.youtube.com/watch?v=HD5Ac-c1v6E" target="_blank" style="display: inline-block;">
    <img src="https://upload.wikimedia.org/wikipedia/commons/b/b8/YouTube_play_button_icon_%282013%E2%80%932017%29.svg" 
         style="width: 100px; height: auto; margin-left: 5px;">
  </a>
</div>
</br>

## ⚠️Warning – Developer (Beta) Version!

This mod is under development, which means bugs, unexpected behavior, unfinished features, and occasional surprises may occur.
I take no responsibility for corrupted savegames, missing vehicles, or heartbroken farmers.

&nbsp;
&nbsp;
## ⚠️ IMPORTANT
Please read this before opening a new issue:
👉 Issue [#114](https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta/issues/114)
&nbsp;

&nbsp;

## 🐞Reporting Issues

If you run into problems, please help improve the mod by following these steps:

1. State your Farming Simulator 25 game version (e.g., FS25: 1.16.0.3)

2. Include the mod version number you are using (e.g., RVB: v0.9.6.1)

3. Restart your savegame, and only enable this mod (and any other absolutely essential mods) when reproducing the issue.

4. Upload your log.txt file to:

   - <a href="https://pastebin.com/">PasteBin</a>

5. Describe the issue in detail:

   - Which vehicle or tool was involved?

   - What were you trying to do?

   - What did you expect to happen, and what actually happened?

## 📌Important Notes

A well-documented bug report helps me find and fix issues faster.

This is not a stable release, but meant for testing and feedback collection.

If you experience excessively fast component wear on a server, it is recommended to shut down the vehicles’ engines before time acceleration or sleeping.
If the issue persists after this, please report it.

Thanks for helping improve the mod!🚜
</br></br>
<!-- -->
# Please don’t share this version on other sites, it’s a VERY early BETA.</br>
## <p dir="auto"><strong><a href="https://farmsim.bltfm.hu/infusions/bltfmhu_downloads_center/downloads.php?cat_id=4&dlc_id=7">Download the latest developer TEST version 0.9.6.3</a></strong> (the file FS25_gameplay_Real_Vehicle_Breakdowns.zip).</p>

## Changelog 0.9.6.3:
- RVBresetVehicle bug - fixed
- MP Bug - fixed
- Code optimization
- Improved debugger system: errors/warnings are always shown, info messages remain menu-toggleable. Function names are now included in log output for easier traceability.
- Moved battery-related functions into a dedicated BatteryManager module.

## Changelog 0.9.6.2:
- Conflict with FS25_EnhancedVehicle mod, TEMP and RMP displays are disabled.
- MP Bug - fixed
- Code optimization (plus 2-5 FPS)
- RVB ExactFillRootNode warning - fixed

</br></br></br><!-- -->
# <p dir="auto"><strong><a href="https://farmsim.bltfm.hu/infusions/bltfmhu_downloads_center/downloads.php?cat_id=4&dlc_id=5">Download the latest developer version</a></strong> (the file FS25_gameplay_Real_Vehicle_Breakdowns.zip).</p>

## Recommended Dependencies (to avoid errors):
- Wind Turbines Charging Station mod (i.e., FS25_electricChargeStation) - by HoT online Team [FS25_electricChargeStation](https://www.kingmods.net/en/fs25/mods/62810/wind-turbines-charging-station)
- JCB E-tech Powerpack (i.e., FS25_JCB_Powerpack) - by RossN Mods [FS25_JCB_Powerpack](https://www.farming-simulator.com/mod.php?mod_id=310865&title=fs2025)

## 🔀Mod Conflict
If you are using the Real Vehicle Breakdowns (RVB) mod, do not use the:
- <strong>FS25_DisableTurnOffMotor</strong> - it will prevent the engine temperature from rising

## Changelog 0.9.6.1:
- github issues#141 - For some players, the game would not start after the update, this issue has now been fixed.

## Changelog 0.9.6.0:
- Rethinking Automatic Engine Shutdown Disable Logic
- Rethinking RVB Specialization Exclusion Logic
- If workshop hours are disabled, the finish time is now calculated correctly.
- Own or mobile workshops are always open; inspections, service, or repairs can be started anytime,
  but the work duration may slightly increase due to mechanic dispatch time being simulated.
- DescVersion increased
- Added new mod icon

## Changelog 0.9.5.9:
- RVB menu optimization
- Keep your vehicle clean! 100% dirt + player-set daily service time = increased wear (engine, thermostat)
- In cold conditions, the usable battery charge decreases, making starting more difficult.
- If the vehicle is not used, the battery loses 3% of its charge per month.
- In the vehicle workshop menu, the status of each vehicle is displayed, indicating whether it is currently under inspection, service, or repair.
  The expected duration of the process is also shown.
- If the vehicle has a hood animation, it automatically opens during inspection/service/repair.
- github issues#138 - Conflict with Dashboard Live

## Changelog 0.9.5.8:
- MP Bug

## Changelog 0.9.5.7:
- Reworked jump-start cable system for more reliable behavior.
The vehicle must be jump-started for 5–15 seconds to start. However, if you turn off the jump-started vehicle and its battery level is still below 10%, it will not start again.
This should now work correctly in multiplayer as well.
- Several functions have been relocated. Hopefully they won’t cause any issues, but extensive testing and feedback are needed.
- The vehicle HUD received a small update. The dashboard icons are now slightly visible even before the engine starts,
and their brightness increases when the headlights are switched on.
- github issues#126
- github issues#124 - Workshop menu bug
- github issues#121 - FR translation update - thanks by Squallqt
- github issues#120 - Fixed DashboardLive compatibility issues
- Fixed missing localization string: “Lépésköz” in RVBMenuPartsSettingsFrame.xml
- Engine wear below 50 °C is now based on engine load instead of speed: above 70 % load, wear increases until the engine reaches 50 °C
- Localization files optimized and completed.
- Update - The following vehicles are “excluded” from RVB mode: https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta/issues/114
This is a quick release intended for testing, so you can try it before it is made available to the general public.

## Changelog 0.9.5.6:
- The difficulty setting has been moved to Gameplay Settings.
- You can now configure whether the vehicle workshop is open.
- Engine Load in HUD
- Engine wear below 50 °C is now based on engine load instead of speed: above 65 % load, wear increases until the engine reaches 50 °C
- Choose the vehicle’s power carefully. If the engine is underpowered, higher engine load can lead to increased engine wear
- Keep your vehicle clean! 100% dirt + 1 hour of operation = increased wear (engine, thermostat)
- github issues#118 - attempt to call missing method 'getIsFaultBattery'
- github issues#116 - Version v0.9.5.5 does not detect the battery
- github issues#112 - Wear values too high
- github issues#110 - RVB does not read the correct tires damage from Use Up Your Tyres mod
- github issues#105 - Divide by zero error.
- github issues#40 - AI workers should automatically shutdown lights/beacons when the vehicle engine stops, fixed
- The following vehicles are “excluded” from RVB mode: https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta/issues/114

## Changelog 0.9.5.5:
- github issues#113 - Game Settings: Lifetime of Parts – Starter Displays Incorrect Value
- github issues#111 - RVB tires repair cost is extremely high
- github issues#109 - Not working on some vehicles
- github issues#108 - Tires are not reset on vehicle reset via workshop reset
- github issues#107 - strange object in 0,0,0 coordinates under vehicle
- github issues#102 - Now compatible with the Highlands Fishing Expansion DLC
- github issues#74 - Just a little compatibility issue between RVB + Vehicle Shop Storage 1.0.0.0 + Use Up Your Tyres 1.0.0.3
- github issues#63 - Fuel gauges
- The following vehicles are “excluded” from RVB mode:
  #### Base game vehicles:
    - piaggio/ape50
    - kubota/rtvxG850
    - kubota/rtvx1140
    - antonioCarraro/tigrecar3200
  #### Mod vehicles:
    - FS25_JohnDeere_330_LawnTractor
    - FS25_JohnDeere445
    - TSN25_2doordefender
  #### DLC vehicles (highlandsFishingPack):
    - canAm/outlanderPro
    - canAm/outlanderMax
    - canAm/defender

## Changelog 0.9.5.4:
- The repair did not finish because a test code was left in. It has now been fixed.
- Compatibility with the Use Up Your Tyres (FS25_useYourTyres) mod has been completed.
In the RVB menu, the tyre lifetime can now be adjusted, for example to 340 km.
Please note that tyre wear is affected by both of the following settings:
Vehicle Failure in the RVB menu
Tyre Usage Rate from the Use Up Your Tyres mod.
- Missing workshop translation added.
- github issues#99

## Changelog 0.9.5.3:
- In MP games, time acceleration incorrectly changed the components’ maximum operating hours, fixed.
- The battery’s lifespan affects its maximum charge capacity.
- Added the ConsoleCommand rvb_VehicleDebug, which displays extended live data of the current vehicle (component condition, battery discharge, battery charge level,
engine temperature, engine performance, etc.).
- When engine faults occur, a reduction in performance and a speed limit have been introduced.
- The Dutch language file has been updated, thanks to NozemOil1982.
- github issues#97
- github issues#62 Conflict with Vehicle Shop Storage, fixed.
- There might have been something else, but I didn’t take notes. :)

## Changelog 0.9.5.2:
- github issues#95
- github issues#94
- github issues#92

## Changelog 0.9.5.1:
- github issues#92
- github issues#90
- github issues#89

## Changelog 0.9.5.0:
- Available on the download page.

## Changelog 0.9.2.9:
- Fixed an issue that prevented saved games from loading after updating to version v0.9.2.8

## Changelog 0.9.2.8:
- github issues#79
- github issues#78
- github issues#76
- github issues#71
- Jump-starting modified

## Changelog 0.9.2.7:
- github issues#75

## Changelog 0.9.2.6:
- Missing value (21) added to WorkshopClose array
- Fixed missing translation during jump-start/charging
- Jumper cable length increased to 10 m
- Now warns and breaks the jumper cable if either vehicle starts.

## Changelog 0.9.2.5:
- github issues#74
- github issues#68
- github issues#66
- github issues#63
- Fixed <part/> issues in vehicles.xml
- RVB on/off - 20 %

## Changelog 0.9.2.4:
- github issues#65
- github issues#64

## Changelog 0.9.2.3:
- Fix for repeated jump-start cable warning message on the server.

## Changelog 0.9.2.2:
- github issues#58
- github issues#55
- github issues#54
- github issues#53
- github issues#51 CZ translation update
- github issues#50
- github issues#47
- github issues#45
- github issues#51 NL translation update - thanks by NozemOil1982
- github issues#31
- github issues#4
- Italian translation added - thanks by caymann lo re

## Changelog 0.9.2.1:
- github issues#44
- github issues#43

## Changelog 0.9.2.0:
- Add new feature: Vehicle Jump Start - github issues#30, issues#37
- Compatible with the FS25_electricChargeStation mod
- github issues#40 - I only made a small change, it needs thorough testing
- github issues#35
- Ukrainian translation added - github issues#34
- github issues#29

## Changelog 0.9.1.1:
- The battery drains quickly - when using the yarder(shadow2391) (Koller K-300-T I tested) or using  Autodrive - fixed
- github issues#27
- github issues#22
- General Settings loading (MP) bug – fixed
 
## Changelog 0.9.1.0:
- github issues#23
- github issues#20 - I hope
- github issues#11 - Again
- Excluded motorbike vehicle types from the mod
- MP bug fixed
- The vehicle's lights were not on, but its operating time increased, fixed.
 
## Changelog 0.9.0.7:
- github issues#19 - Temporary, quick bug fix.
- github issues#16
- github issues#14
- github issues#11
- github issues#10
  
## Changelog 0.9.0.6:
- github issues#18
- github issues#16
- Added Czech translation
- github issues#14 ??
- github issues#13
- github issues#12
- github issues#11
- github issues#10
- github issues#6
- github issues#2
  
## Changelog 0.9.0.5:
- Dynamic battery regeneration
- HUD optimization
- General settings - HUD display
- Added Portuguese translation

## Changelog 0.9.0.4:
- Upgrading from FS22 to FS25
