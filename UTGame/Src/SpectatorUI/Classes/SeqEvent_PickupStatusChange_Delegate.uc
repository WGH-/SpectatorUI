/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SeqEvent_PickupStatusChange_Delegate extends SeqEvent_PickupStatusChange;

event Activated() {
    OnActivated(PickupFactory(Originator), Pawn(Instigator));
    
    // reset active status so it can be activated again
    // usually, it's handled by parent sequence
    // but on maps where there's no default sequence,
    // we use a fake one, which doesn't "tick" its children
    if (FakeSequence(ParentSequence) != None) {
        bActive = false;
    }
}

delegate OnActivated(PickupFactory ThisFactory, Pawn EventInstigator);
