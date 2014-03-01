SpectatorUI version 2.0

This mutator greatly enhances spectator's convenience.

Author: WGH, wgh@torlan.ru
23.02.2014

== Features ==
 * Works offline, online and in server-recorded demos (provided mutator was active at the time of recording)
 * "Spectate" button available in mid game menu
 * Nicknames are displayed above players
 * Convenient player selection menu available using the mouse scroll
 * Adjustable camera speed and FOV
 * Button that allows to switch to 3rd person camera 
 * Up to ten savable bookmarks per map
 * Clicking right mouse button detaches camera and leaves it where it currently is, not where it was some time ago
 * Notifications of powerups, superweapons, flags being taken, with an option to jump to the player
 * Timer for powerups, armor pickups and super weapons

== Controls ==
 * Number row - camera speed control, ranging from 1/8 to 64 of default speed (exponential scaling)
 * Left mouse button (primary fire) - jump to objective like orb or flag (same as in stock game)
 * Middle mouse button + MouseY - change FOV (zoom)
 * Right mouse button (secondary fire) - detach camera, if it's following player or objective (same as in stock game, but enhanced)
 * Mouse scroll (previous/next weapon) - change players (same as in stock game, but enhanced)
 * Alt + NumPad number - save bookmark
 * NumPad number - load previously saved bookmark
 * NumPad Multiply (*) - jump to the player that caused notification 

== Customization == 
=== Exec functions ===
The mutator exports a couple of exec functions, which you can use in your own binds or in console.

SpectatorUI_SetSpeed <speed> - set camera speed
SpectatorUI_AddSpeed <speed> - increase camera speed by specified amount (can be negative)
SpectatorUI_MultiplySpeed <multiplier> - multiplies camera speed by specified amount
becomespectator - become spectator, if possible

SpectatorUI_FollowPowerup <1|0> - automatically jump to players who takes a powerup
cg_followPowerup <1|0> - same, Quake compatibility

SpectatorUI_FollowKiller <1|0> - automatically jump to player who frags anyone
cg_followKiller <1|0> - same, Quake compatibility

=== Config file ===
==== Server ====
This section is relavant to server administrators willing to use this mutator.

The config file is UTSpectatorUI.ini

[SpectatorUI_2.SpectatorUI_Mut]
RejoinDelay=15.0 ; seconds player must wait before becoming active again after becoming a spectator
bPowerupTimers=true ; if true, spectators will know respawn timers for various powerups

==== Client ====
You can use configuration file to adjust many options to your liking.

To do so, open file UTSpectatorUI.ini (create it, if it doesn't exist), and add the following lines. Omit it if you don't want to change the default.

[SpectatorUI_2.SpectatorUI_Interaction]
PlayerSwitchDelay=0.5 ; the amount of time mutator waits before switch to the player
PostPlayerSwitchDelay=2.0 ; the amount of time selection menu remains on screen after switching

BookmarkModifierButton=LeftAlt ; button you need to hold in order to save bookmark
ZoomButton=MiddleMouseButton ; button you need to hold in order to change FOV
BehindViewKey=Q


