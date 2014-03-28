/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_ServerSettings extends Object
    perobjectconfig
    config(SpectatorUI);

var config float RejoinDelay;
var config bool bPowerupTimers;
var config bool bEnableBecomeSpectator;

defaultproperties
{
    RejoinDelay=15
    bPowerupTimers=true
    bEnableBecomeSpectator=true
}
