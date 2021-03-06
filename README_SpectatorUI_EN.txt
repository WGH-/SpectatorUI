SpectatorUI version 2.5

This mutator greatly enhances spectator's convenience.

Author: WGH, wgh@torlan.ru
13.04.2014

== Features ==
 * Works offline, online and in server-recorded demos (provided mutator was active at the time of recording)
 * "Spectate" button available in mid game menu
 * Nicknames are displayed above players
 * In first person view, POV nickname is displayed in the corner.
 * Convenient player selection menu available using the mouse scroll
 * Adjustable camera speed and FOV
 * Button that allows to switch to 3rd person camera 
 * Up to ten savable bookmarks per map
 * Clicking right mouse button detaches camera and leaves it where it currently is, not where it was some time ago
 * Notifications of powerups, superweapons, flags being taken, with an option to jump to the player
 * Timer for powerups, armor pickups and super weapons (Kismet-activated pickup factories are also supported)

== Installation ==
Contents of Script directory go anywhere in \Documents\My Games\Unreal Tournament 3\UTGame\Published\CookedPC.
Contents of Config directory go in \Documents\My Games\Unreal Tournament 3\UTGame\Config

Once it's done, mutator will be listed in the usual mutator list.

For server administrators, class path is "SpectatorUI_2_5.SpectatorUI_Mut".

== Known bugs ==
 * Pickup timers don't always work correctly with some items whose
   respawn is managed by Kismet or similar means (JB-Makoy is example of such map).

   Most of the time, though, they do work correctly (e.g. in WAR-Avalanche).

 * Jump to objective (primary fire) doesn't work in demos.

== Controls ==
 * Number row - camera speed control, ranging from 1/8 to 64 of default speed (exponential scaling)
 * Left mouse button (primary fire) - jump to objective like orb or flag (same as in stock game)
 * Middle mouse button + MouseY - change FOV (zoom)
 * Right mouse button (secondary fire) - detach camera, if it's following player or objective (same as in stock game, but fixed)
 * Mouse scroll (previous/next weapon) - change players (same as in stock game, but enhanced)
 * Alt + NumPad number - save bookmark
 * NumPad number - load previously saved bookmark
 * NumPad Multiply (*) - jump to the player that caused notification 
 * Q - Toggle first person/third person view

== Customization == 
=== Exec functions ===
The mutator exports a couple of exec functions, which you can use in your own binds or in console.

    SpectatorUI_SetSpeed <speed> - set camera speed
    SpectatorUI_AddSpeed <speed> - increase camera speed by specified amount (can be negative)
    SpectatorUI_MultiplySpeed <multiplier> - multiplies camera speed by specified amount
    becomespectator - become spectator, if possible

    SpectatorUI_FollowPowerup <1|0> - automatically jump to player who takes a powerup
    cg_followPowerup <1|0> - same, Quake compatibility

    SpectatorUI_FollowKiller <1|0> - automatically jump to player who frags anyone
    cg_followKiller <1|0> - same, Quake compatibility

    SpectatorUI_UnattendedMode <1|0> - enable unattended mode (automatically ensure that camera is watching someone)

    ghost - make free camera ignore world geometry, passing right through it

=== Config file ===
==== Server ====
This section is relavant to server administrators willing to use this mutator.

The config file is UTSpectatorUI.ini

    [SpectatorUI SpectatorUI_ServerSettings]
    RejoinDelay=15.0 ; seconds player must wait before becoming active again after becoming a spectator
    bPowerupTimers=true ; if true, spectators will know respawn timers for various powerups
    bEnableBecomeSpectator=true ; if true, players will be able to become spectators at all
                                ; might make sense to disable it if you're using another mutator
                                ; that provides this functionality

==== Client ====
You can use configuration file to adjust many options to your liking.

To do so, open file UTSpectatorUI.ini (create it, if it doesn't exist), and add the following lines. Omit it if you don't want to change the default.

    [SpectatorUI SpectatorUI_ClientSettings]
    ; the amount of time mutator waits before switch to the player
    ; can be used to prevent pickup timer abuse
    PlayerSwitchDelay=0.5  

    ; the amount of time selection menu remains on screen after switching
    PostPlayerSwitchDelay=2.0 

    ; button you need to hold in order to save bookmark
    BookmarkModifierButton=LeftAlt 

    ; button you need to hold in order to change FOV
    ZoomButton=MiddleMouseButton 

    BehindViewKey=Q

    ; if you're already accustomed to the mutator, you might want to dismiss help automatically
    bDisableHelp=false 

    ; set to false if you want to suppress notification beep
    bNotificationBeep=true 

    ; set to true if you want pickup timers to be rendered in larger font
    ; useful for video streaming, where video quality might be terrible
    bLargerPickupTimers=false
    
    ; you can customize pickup notification message here
    ; `o will be replaced with pickup name,
    ; `s - with player nickname
    PickupNotificationPattern=`o picked up by `s 

    ; if you wish, you can customize pickup names like this
    ; full list of pickup classes included in stock game
    ; is listed in the appendix
    CustomPickupNames=(ClassName="UTGame.UTArmorPickup_Vest",CustomName="Armor +50")
    
    ; defaults for various run-time settings
    bDefaultFirstPerson=false
    bFollowKiller=false
    bFollowPowerup=false
    bUnattendedMode=false

== Source code ==
Source code is provided under terms of the Open Unreal Mod License, and is available on GitHub: https://github.com/WGH-/SpectatorUI

== Appendix ==

=== Pickup classes ===
Just copy-paste them in the configuration file and fill in the blanks.

CustomPickupNames=(ClassName="UTGameContent.UTWeap_Redeemer_Content",CustomName="")

CustomPickupNames=(ClassName="UTGameContent.UTUDamage",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTBerserk",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTInvulnerability",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTInvisibility",CustomName="")
CustomPickupNames=(ClassName="UT3Gold.UTSlowField_Content",CustomName="")

CustomPickupNames=(ClassName="UTGameContent.UTPickupFactory_SuperHealth",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTArmorPickup_ShieldBelt",CustomName="")
CustomPickupNames=(ClassName="UTGame.UTArmorPickup_Helmet",CustomName="")
CustomPickupNames=(ClassName="UTGame.UTArmorPickup_Thighpads",CustomName="")
CustomPickupNames=(ClassName="UTGame.UTArmorPickup_Vest",CustomName="")

CustomPickupNames=(ClassName="UTGameContent.UTJumpBoots",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTDeployableEMPMine",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTDeployableEnergyShield",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTDeployableShapedCharge",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTDeployableSlowVolume",CustomName="")
CustomPickupNames=(ClassName="UTGameContent.UTDeployableSpiderMineTrap",CustomName="")

CustomPickupNames=(ClassName="UT3Gold.UTDeployableLinkGenerator",CustomName="")
CustomPickupNames=(ClassName="UT3Gold.UTDeployableXRayVolume",CustomName="")
