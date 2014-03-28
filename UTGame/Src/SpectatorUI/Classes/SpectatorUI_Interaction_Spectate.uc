/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_Interaction_Spectate extends Interaction 
    within SpectatorUI_Interaction
    config(SpectatorUI);

exec function BecomeSpectator() {
    Spectate();
}
