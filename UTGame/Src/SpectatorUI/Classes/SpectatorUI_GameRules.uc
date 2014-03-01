/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_GameRules extends GameRules;

var SpectatorUI_Mut Mut;

function ScoreKill(Controller Killer, Controller Killed)
{
    Mut.ScoreKill(Killer, Killed);
    
    super.ScoreKill(Killer, Killed);
}
