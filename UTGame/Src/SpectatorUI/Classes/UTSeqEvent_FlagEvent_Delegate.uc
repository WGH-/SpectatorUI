/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class UTSeqEvent_FlagEvent_Delegate extends UTSeqEvent_FlagEvent;

function Trigger(name EventType, Controller EventInstigator)
{
    // don't call super
    OnTrigger(UTGameObjective(Originator), EventType, EventInstigator);
}

delegate OnTrigger(UTGameObjective EventOriginator, name EventType, Controller EventInstigator);
