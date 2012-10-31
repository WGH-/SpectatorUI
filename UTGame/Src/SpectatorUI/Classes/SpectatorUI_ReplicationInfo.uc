class SpectatorUI_ReplicationInfo extends ReplicationInfo;

var repnotify Actor Owner_;

// set only on clients
var SpectatorUI_Interaction SUI;

// set only on server
var Actor PointOfInterest;

replication {
    if (bNetOwner && bNetDirty)
        Owner_;
}

simulated event ReplicatedEvent(name VarName)
{
    super.ReplicatedEvent(VarName);

    if (VarName == 'Owner_') {
        SetOwner(Owner_);
        if (WorldInfo.NetMode != NM_DedicatedServer && PlayerController(Owner) != None) {
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

simulated event Destroyed() {
    local int i;
    local PlayerController PC;

    if (WorldInfo.NetMode != NM_DedicatedServer) {
        PC = PlayerController(Owner);

        for (i = 0; i < PC.Interactions.Length; i++) {
            if (SpectatorUI_Interaction(PC.Interactions[i]) != None) {
                PC.Interactions.Remove(i, 1);
                break;
            }
        }
    }

    super.Destroyed();
}

reliable server function ServerViewPlayer(PlayerReplicationInfo PRI) {
    if (PlayerController(Owner).IsSpectating()) {
        PlayerController(Owner).SetViewTarget(PRI); 
    }
}

function InterestingPickupTaken(Pawn Other, class<Inventory> ItemClass, Actor Pickup) {
    if (Other.Controller != None && Other.Controller.PlayerReplicationInfo != None) {
        PointOfInterest = Other.Controller.PlayerReplicationInfo;
        ClientInterestingPickupTaken(ItemClass, Other.Controller.PlayerReplicationInfo.GetPlayerAlias());
    }
}

reliable client function ClientInterestingPickupTaken(class<Inventory> What, string Who) {
    PlayerController(Owner).ClientMessage(
        What.default.ItemName @ "has been picked up by" @ Who $ "." $
        " Press * to jump to that player."
    );
}

reliable server function ServerViewPointOfInterest() {
    if (PlayerController(Owner).IsSpectating()) {
        PlayerController(Owner).SetViewTarget(PointOfInterest); 
    }
}

defaultproperties
{
    bOnlyRelevantToOwner=true
}
