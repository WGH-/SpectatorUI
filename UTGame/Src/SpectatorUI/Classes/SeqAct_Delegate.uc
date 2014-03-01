/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SeqAct_Delegate extends SequenceAction;

var array<Object> Args;

event Activated() {
    OnActivated(self);
}

delegate OnActivated(SeqAct_Delegate X);

defaultproperties
{
    bCallHandler=false
}
