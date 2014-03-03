/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_ClientSettings extends Object
    perobjectconfig
    config(SpectatorUI);

var config bool bDisableHelp;

var config Name BookmarkModifierButton;
var config Name ZoomButton;
var config name BehindViewKey;

var config float PlayerSwitchDelay;
var config float PostPlayerSwitchDelay;

defaultproperties
{
    BookmarkModifierButton=LeftAlt
    ZoomButton=MiddleMouseButton
    BehindViewKey=Q
    
    PlayerSwitchDelay=0.5
    PostPlayerSwitchDelay=2.0
}
