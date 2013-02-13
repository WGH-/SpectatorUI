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

simulated function AddInterestingActor(Actor A) {
    PointsOfInterest.Actors[PointsOfInterest.Ptr] = A;
    PointsOfInterest.ReadPtr = PointsOfInterest.Ptr;
    if (++PointsOfInterest.Ptr == ArrayCount(PointsOfInterest.Actors)) {
        PointsOfInterest.Ptr = 0;
    }
}

reliable demorecording function DemoAddInterestingActor(Actor A) {
    AddInterestingActor(A);
}   

simulated function Actor GetNextInterestingActor() {
    local Actor A;
    local int MinPtr;
    A = PointsOfInterest.Actors[PointsOfInterest.ReadPtr];
    MinPtr = PointsOfInterest.Ptr - 1;
    if (MinPtr < 0) MinPtr = ArrayCount(PointsOfInterest.Actors) - 1; 
    do {
        if (--PointsOfInterest.ReadPtr < 0) PointsOfInterest.ReadPtr = ArrayCount(PointsOfInterest.Actors) - 1;
    } until (PointsOfInterest.ReadPtr == MinPtr || PointsOfInterest.Actors[PointsOfInterest.ReadPtr] != None);
    return A;
}

simulated event ReplicatedEvent(name VarName)
{
    super.ReplicatedEvent(VarName);

    if (VarName == 'Owner_') {
        SetOwner(Owner_);
        if (WorldInfo.NetMode != NM_DedicatedServer && PlayerController(Owner) != None) {
            TryAttachInteraction();
        }
    }
}

simulated function TryAttachInteraction() {
    local PlayerController PC;
    PC = PlayerController(Owner);
    
    if (PC.Player == None) {
        // hack: don't do that unless PC has player
        SetTimer(0.1, false, 'TryAttachInteraction');
        return;
    }
    SUI = class'SpectatorUI_Interaction'.static.MaybeSpawnFor(PC);
    SUI.RI = self;
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

simulated function ViewPlayer(PlayerReplicationInfo PRI) {
    if (DemoRecSpectator(Owner) != None) {
        DemoViewPlayer(PRI); 
    } else {
        ServerViewPlayer(PRI);
    }
}

reliable server protected function ServerViewPlayer(PlayerReplicationInfo PRI) {
    if (PlayerController(Owner).IsSpectating()) {
        PlayerController(Owner).SetViewTarget(PRI); 
    }
}

simulated protected function DemoViewPlayer(PlayerReplicationInfo PRI) {
    DemoRecSpectator(Owner).ClientSetRealViewTarget(PRI);
}

function InterestingPickupTaken(Pawn Other, class<Inventory> ItemClass, Actor Pickup) {
    local Actor A;
    local PlayerReplicationInfo PRI;

    PRI = Controller(Owner).PlayerReplicationInfo;
    if (PRI == None || (!PRI.bOnlySpectator && !Owner.IsInState('Spectating'))) return;

    if (Other.Controller != None && Other.Controller.PlayerReplicationInfo != None) {
        A = Other.Controller.PlayerReplicationInfo;
        AddInterestingActor(A);
        DemoAddInterestingActor(A); // XXX call it only on DRC-owned RI?
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

simulated function ViewPointOfInterest() {
    if (DemoRecSpectator(Owner) != None) {
        DemoViewPointOfInterest();
    } else {
        ServerViewPointOfInterest();
    }
}

reliable server protected function ServerViewPointOfInterest() {
    local Actor A;
    if (PlayerController(Owner).IsSpectating()) {
        A = GetNextInterestingActor();
        if (A == None) return;
        PlayerController(Owner).SetViewTarget(A); 
    }
}

simulated protected function DemoViewPointOfInterest() {
    local Actor A;
    A = GetNextInterestingActor();
    if (A == None) return;
    if (PlayerReplicationInfo(A) != None) {
        DemoViewPlayer(PlayerReplicationInfo(A));
    } else {
        PlayerController(Owner).SetViewTarget(A); 
    }
}

reliable server function ServerSpectate() {
    local PlayerController PC;
    local PlayerReplicationInfo PRI;
    local GameInfo G;

    PC = PlayerController(Owner);
    if (PC == None) return;
    PRI = PC.PlayerReplicationInfo;
    if (PRI == None) return;

    G = WorldInfo.Game;

    if (!PRI.bOnlySpectator &&
        G.NumSpectators < G.MaxSpectators &&
        G.GameReplicationInfo.bMatchHasBegun &&
        !PC.IsInState('RoundEnded') &&
        (G.BaseMutator == None || G.BaseMutator.AllowBecomeSpectator(PC))
        )
    {
        PRI.bOnlySpectator = true;
        PRI.bIsSpectator = true;

        if (PC.Pawn != None) {
            PC.Pawn.Suicide();
        }

        PC.GotoState('Spectating');
        PC.ServerViewNextPlayer();

        if (PRI.Team != None) {
            PRI.Team.RemoveFromTeam(PC);
            PRI.Team = None;
        }

        if (G.BaseMutator != None) {
            G.BaseMutator.NotifyBecomeSpectator(PC);
        }

        if (UTGame(G) != None && UTGame(G).VoteCollector != None && UTPlayerController(PC) != None) {
            UTGame(G).VoteCollector.NotifyBecomeSpectator(UTPlayerController(PC));
        }

        G.NumPlayers--;
        G.NumSpectators++;

        G.UpdateGameSettingsCounts();

        G.BroadcastLocalizedMessage(G.GameMessageClass, 14, PRI);
    }
}

defaultproperties
{
    bOnlyRelevantToOwner=true
}
