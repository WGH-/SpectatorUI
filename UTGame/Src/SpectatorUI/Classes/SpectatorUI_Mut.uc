class SpectatorUI_Mut extends UTMutator;

function NotifyLogin(Controller NewPlayer) {
    super.NotifyLogin(NewPlayer);

    if (true || NewPlayer.PlayerReplicationInfo.bOnlySpectator) {
        Spawn(class'SpectatorUI_ReplicationInfo', NewPlayer);
    }
}
