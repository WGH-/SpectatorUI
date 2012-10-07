class SpectatorUI_ReplicationInfo extends ReplicationInfo;

simulated event PostBeginPlay() {
    super.PostBeginPlay(); 

    if (WorldInfo.NetMode != NM_DedicatedServer) {
        // we can't be sure that PlayerController ad its HUD exist at this point
        SetTimer(1.0f, true);
        Timer();
    }
}

simulated function Timer() {
    local PlayerController PC;
    foreach LocalPlayerControllers(class'PlayerController', PC) {
        if (class'SpectatorUI_Interaction'.static.MaybeSpawnFor(PC) != None) {
            ClearTimer();
        }
    }
}
