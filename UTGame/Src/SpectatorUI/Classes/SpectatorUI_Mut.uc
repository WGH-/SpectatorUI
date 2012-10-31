class SpectatorUI_Mut extends UTMutator;

var array<SpectatorUI_ReplicationInfo> RIs;

function NotifyLogin(Controller NewPlayer) {
    if (NewPlayer.PlayerReplicationInfo.bOnlySpectator) {
        RIs.AddItem(Spawn(class'SpectatorUI_ReplicationInfo', NewPlayer));
    }
    super.NotifyLogin(NewPlayer);
}

function NotifyBecomeActivePlayer(PlayerController Player) {
    local int i;

    for (i = 0; i < RIs.Length; i++) {
        if (RIs[i].Owner == Player) {
            RIs[i].Destroy();
            RIs.Remove(i, 1);
            break;
        }
    }
    super.NotifyBecomeActivePlayer(Player);
}
