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
var config bool bNotificationBeep;
var config int NotificationMode;
var config bool bLargerPickupTimers;

var config bool bFollowKiller;
var config bool bFollowPowerup;
var config bool bDefaultFirstPerson;
var config bool bUnattendedMode;

var config Name BookmarkModifierButton;
var config Name ZoomButton;
var config name BehindViewKey;
var config name SwitchViewToButton;

var config float PlayerSwitchDelay;
var config float PostPlayerSwitchDelay;

var config string PickupNotificationPattern;
var config string RedFlagNotificationPattern, BlueFlagNotificationPattern;

struct CustomPickupName {
    var string ClassName;
    var string CustomName;
};

var config array<CustomPickupName> CustomPickupNames;

function bool LookupCustomPickupName(string ClassName, out string PickupName) {
    local int i;
    i = CustomPickupNames.Find('ClassName', ClassName);
    if (i >= 0) {
        PickupName = CustomPickupNames[i].CustomName;
        return true;
    } 
    return false;
}

defaultproperties
{
    bNotificationBeep=true

    BookmarkModifierButton=LeftAlt
    ZoomButton=MiddleMouseButton
    BehindViewKey=Q
    SwitchViewToButton=Multiply
    
    PlayerSwitchDelay=0.5
    PostPlayerSwitchDelay=2.0
}
