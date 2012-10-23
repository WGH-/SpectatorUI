class SpectatorUI_ReplicationInfo extends ReplicationInfo;

var repnotify Actor Owner_;

replication {
    if (bNetOwner && bNetDirty)
        Owner_;
}

simulated event ReplicatedEvent(name VarName)
{
    local SpectatorUI_Interaction SUI;

    super.ReplicatedEvent(VarName);

    if (VarName == 'Owner_') {
        SetOwner(Owner_);
        if (PlayerController(Owner) != None) {
            SUI = class'SpectatorUI_Interaction'.static.MaybeSpawnFor(PlayerController(Owner));
            SUI.RI = self;
        }
    }
}

simulated event PostBeginPlay() {
    super.PostBeginPlay(); 

    if (Role == ROLE_Authority) {
        Owner_ = Owner;
    }
}

reliable server function Test() {
    `log("TEST");
}

reliable client function ClientTest() {
    `log("TEST");
}

defaultproperties
{
    bOnlyRelevantToOwner=true
}
