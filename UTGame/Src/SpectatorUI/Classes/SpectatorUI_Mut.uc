class SpectatorUI_Mut extends UTMutator;

function NotifyLogin(Controller NewPlayer) {
    super.NotifyLogin(NewPlayer);

    if (NewPlayer.PlayerReplicationInfo.bOnlySpectator) {
        Spawn(class'SpectatorUI_ReplicationInfo', NewPlayer);
    }
}

function NotifyBecomeActivePlayer(PlayerController Player) {
    local SpectatorUI_ReplicationInfo RI;

    super.NotifyBecomeActivePlayer(Player);

    foreach DynamicActors(class'SpectatorUI_ReplicationInfo', RI) {
        if (RI.Owner == Player) {
            RI.Destroy();
            break;
        }
    }
}
