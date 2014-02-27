class SpectatorUI_GameRules extends GameRules;

var SpectatorUI_Mut Mut;

function ScoreKill(Controller Killer, Controller Killed)
{
    Mut.ScoreKill(Killer, Killed);
    
    super.ScoreKill(Killer, Killed);
}
