/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class UTSeqEvent_OnslaughtNodeEvent_Delegate extends UTSeqEvent_OnslaughtNodeEvent;

function NotifyNodeChanged(Controller EventInstigator)
{
    // don't call super
    OnTrigger(UTOnslaughtNodeObjective(Originator), EventInstigator);
}

delegate OnTrigger(UTOnslaughtNodeObjective EventOriginator, Controller EventInstigator);
