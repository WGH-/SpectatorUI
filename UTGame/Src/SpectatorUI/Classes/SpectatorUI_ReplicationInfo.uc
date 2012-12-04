class SpectatorUI_ReplicationInfo extends ReplicationInfo;

var repnotify Actor Owner_;

// set only on clients
var SpectatorUI_Interaction SUI;

// set only on server
struct PointsOfInterestContainer {
    var Actor Actors[3];
    var int Ptr; // current pos 
    var int ReadPtr;
};
var PointsOfInterestContainer PointsOfInterest;

replication {
    if (bNetOwner && bNetDirty)
        Owner_;
}

// struct PointsOfInterestContainer "methods"

function AddInterestingActor(Actor A) {
    PointsOfInterest.Actors[PointsOfInterest.Ptr] = A;
    PointsOfInterest.ReadPtr = PointsOfInterest.Ptr;
    if (++PointsOfInterest.Ptr == ArrayCount(PointsOfInterest.Actors)) {
        PointsOfInterest.Ptr = 0;
    }
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
        AddInterestingActor(Other.Controller.PlayerReplicationInfo);
        ClientInterestingPickupTaken(ItemClass, Other.Controller.PlayerReplicationInfo);
    }
}

reliable client function ClientInterestingPickupTaken(class<Inventory> What, PlayerReplicationInfo Who) {
    local string Desc;

    Desc = What.default.ItemName;
    if (Desc == "") {
        Desc = What.default.PickupMessage;
    }
    if (Desc == "") {
        Desc = string(What.name);
    }
    
    PlayerController(Owner).ClientMessage(
        Desc @ "has been picked up by" @ Who.GetPlayerAlias() $ "." $
        " Press * to jump to that player."
    );
}

reliable server function ServerViewPointOfInterest() {
    local Actor A;
    if (PlayerController(Owner).IsSpectating()) {
        A = PointsOfInterest.Actors[PointsOfInterest.ReadPtr];
        if (A == None) return; // empty yet

        PlayerController(Owner).SetViewTarget(A); 

        do {
            if (--PointsOfInterest.ReadPtr < 0) PointsOfInterest.ReadPtr = ArrayCount(PointsOfInterest.Actors) - 1;
        } until (PointsOfInterest.ReadPtr == PointsOfInterest.Ptr || PointsOfInterest.Actors[PointsOfInterest.ReadPtr] != None);
    }
}

defaultproperties
{
    bOnlyRelevantToOwner=true
}
