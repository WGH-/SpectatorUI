class SpectatorUI_Interaction extends Interaction within PlayerController;

simulated static function SpectatorUI_Interaction MaybeSpawnFor(PlayerController PC) {
    local Interaction Interaction;
    local SpectatorUI_Interaction SUI_Interaction;

    foreach PC.Interactions(Interaction) {
        if (SpectatorUI_Interaction(Interaction) != None) {
            return SpectatorUI_Interaction(Interaction);
        }
    }
    
    SUI_Interaction = new(PC) default.class;
    PC.Interactions.AddItem(SUI_Interaction);
    return SUI_Interaction;
}

static final function bool SameDirection(vector a, vector b) {
    return a dot b >= 0;
}

simulated function bool ShouldRender() {
    return IsSpectating();
}

simulated event PostRender(Canvas Canvas) {
    local vector Loc, Dir;
    local rotator Rot;
    local UTHUD HUD;
    local Actor A;
    
    super.PostRender(Canvas);

    HUD = UTHUD(myHUD);
    if (HUD == None || !ShouldRender()) return;

    Canvas.Font = HUD.GetFontSizeIndex(0);
    
    GetPlayerViewPoint(Loc, Rot);
    Dir = vector(Rot);

    foreach HUD.PostRenderedActors(A) {
        if (A == None) continue;
        if (!SameDirection(Dir, A.Location - Loc)) continue;

        if (UTPawn(A) != None) {
            UTPawn_PostRenderFor(UTPawn(A), Outer, Canvas, Loc, Dir);
        } else if (UTVehicle(A) != None) {
            UTVehicle_PostRenderFor(UTVehicle(A), Outer, Canvas, Loc, Dir);
        }
    }
}

simulated static function UTPawn_PostRenderFor(UTPawn P, PlayerController PC, Canvas Canvas, vector Loc, vector Dir) {
    local bool old;
    old = P.bPostRenderOtherTeam;
    P.bPostRenderOtherTeam = true;
    P.NativePostRenderFor(PC, Canvas, Loc, Dir);
    P.bPostRenderOtherTeam = old;
}

simulated static function UTVehicle_PostRenderFor(UTVehicle V, PlayerController PC, Canvas Canvas, vector Loc, vector Dir) {
    local bool old;
    old = V.bPostRenderOtherTeam;
    V.bPostRenderOtherTeam = true;
    V.NativePostRenderFor(PC, Canvas, Loc, Dir);
    V.bPostRenderOtherTeam = old;
}
