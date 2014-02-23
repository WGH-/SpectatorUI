class SpectatorUI_ReplicationInfo extends ReplicationInfo;

var repnotify Actor Owner_;

// set only on clients
var SpectatorUI_Interaction SUI;
var float ServerTimeDelta;
var float ServerTimeSeconds;

// set only on server
struct PointsOfInterestContainer {
    var Actor Actors[3];
    var int Ptr; // current pos 
    var int ReadPtr;
};
var PointsOfInterestContainer PointsOfInterest;
var bool bIsSpectator;
var SpectatorUI_Mut Mut;

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

    if (VarName == 'Owner_' && Owner == None) {
        SetOwner(Owner_);
        if (WorldInfo.NetMode != NM_DedicatedServer) {
            TryAttachInteraction();
        }
    }
}

simulated function TryAttachInteraction() {
    local UTPlayerController PC;
    PC = UTPlayerController(Owner);
    
    // the check should never pass, but let's be safe
    if (SUI == None) {
        SUI = class'SpectatorUI_Interaction'.static.Create(PC, self);
    }
}

simulated event PostBeginPlay() {
    super.PostBeginPlay(); 

    if (Role == ROLE_Authority) {
        if (PlayerController(Owner).IsLocalPlayerController()) {
            TryAttachInteraction();
        } else {
            Owner_ = Owner;
            // and continue from ReplicatedEvent
        }
    }
}

function NotifyBecomeSpectator() {
    bIsSpectator = true;

    if (PlayerController(Owner).IsLocalPlayerController()) {
        ServerTimeDelta = 0; // it's always zero for local players
    } else {
        TryReplicateTimeDelta();
    }

    Mut.UpdateAllRespawnTimesFor(self);
}

function NotifyBecomeActive() {
    bIsSpectator = false;

    // clear timer, in case it's active
    ClearTimer('TryReplicateTimeDelta');
}

function TryReplicateTimeDelta() {
    //`log("Trying to replicate server time" @ WorldInfo.TimeSeconds);
    ClientReplicateTimeDelta(WorldInfo.TimeSeconds);
    // 16  = 4 (PRI.Ping is stored in byte divided by 4) * 4 (let's give more than enough time to answer)
    SetTimer(FMax(0.5, 0.25 + (16 * PlayerController(Owner).PlayerReplicationInfo.Ping) * 0.001) * WorldInfo.TimeDilation, false, 'TryReplicateTimeDelta');
}

unreliable client function ClientReplicateTimeDelta(float TimeSeconds) {
    if (TimeSeconds < ServerTimeSeconds) {
        // old packet received out of order
        // just ignore
    } else {
        ServerTimeSeconds = TimeSeconds;
        ServerTimeDelta = WorldInfo.TimeSeconds - ServerTimeSeconds;
    }
    AcknowledgeReplicateTimeDelta(TimeSeconds);
}

unreliable server function AcknowledgeReplicateTimeDelta(float TimeSeconds) {
    //`log("replication acknowledged, RTT" @ WorldInfo.TimeSeconds - TimeSeconds);
    ClearTimer('TryReplicateTimeDelta');
}

simulated function ViewPlayer(PlayerReplicationInfo PRI) {
    if (DemoRecSpectator(Owner) != None) {
        DemoViewPlayer(PRI); 
    } else {
        ServerViewPlayer(PRI);
    }
}

reliable server protected function ServerViewPlayer(PlayerReplicationInfo PRI) {
    if (WorldInfo.Game.CanSpectate(PlayerController(Owner), PRI)) {
        PlayerController(Owner).SetViewTarget(PRI); 
    }
}

simulated protected function DemoViewPlayer(PlayerReplicationInfo PRI) {
    DemoRecSpectator(Owner).ClientSetRealViewTarget(PRI);
}

// extract human-readable pickup name on the client
simulated function string GetPickupName(class<Actor> Clazz) {
    local class<UTItemPickupFactory> IPFClass;
    local class<Inventory> InvClass;

    IPFClass = class<UTItemPickupFactory>(Clazz);

    if (IPFClass != None) {
        return IPFClass.default.PickupMessage;
    }
    InvClass = class<Inventory>(Clazz);
    if (InvClass != None) {
        if (InvClass.default.ItemName != "") {
            return InvClass.default.ItemName;
        }
        return InvClass.default.PickupMessage;
    }
    return string(Clazz.name);
}

// the points is, we want to resolve names on the client
// because they may use different language than server
// in order to do so, we send an Inventory class (not instance!)
// but in case of item pickups (armor, health), there is no Inventory class
// so we send a class of Factory instead (it contains PickupMessage property)
function class<Actor> GetPickupClass(PickupFactory F) {
    if (UTItemPickupFactory(F) != None) {
        return F.class;
    } else {
        return F.InventoryType;
    }
}

function InterestingPickupTaken(Pawn Other, PickupFactory F, Actor Pickup) {
    local Actor A;
    local PlayerReplicationInfo PRI;

    PRI = Controller(Owner).PlayerReplicationInfo;
    // XXX again, what about duel players in queue?
    if (!(PRI != None && PRI.bOnlySpectator)) return;

    if (Other.Controller != None && Other.Controller.PlayerReplicationInfo != None) {
        A = Other.Controller.PlayerReplicationInfo;
        AddInterestingActor(A);
        DemoAddInterestingActor(A); // XXX call it only on DRC-owned RI?
        ClientInterestingPickupTaken(GetPickupClass(F), Other.Controller.PlayerReplicationInfo);
    }
}

reliable client function ClientInterestingPickupTaken(class<Actor> What, PlayerReplicationInfo Who) {
    local string Desc;

    Desc = GetPickupName(What); 
    
    PlayerController(Owner).ClientMessage(
        Desc @ "has been picked up by" @ Who.GetPlayerAlias() $ "." $
        " Press * to jump to that player."
    );
}

function UpdateRespawnTime(PickupFactory F, int i, float ExpectedTime) {
    local PlayerReplicationInfo PRI;

    PRI = Controller(Owner).PlayerReplicationInfo;
    // XXX again, what about duel players in queue?
    if (!(PRI != None && PRI.bOnlySpectator)) return;

    ClientUpdateRespawnTime(GetPickupClass(F), i, ExpectedTime);
}

reliable client function ClientUpdateRespawnTime(class<Actor> Clazz, int i, float ExpectedTime) {
    SUI.UpdateRespawnTime(GetPickupName(Clazz), i, ExpectedTime);
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
    // XXX IsSpectating isn't really appopriate, as it includes
    // end game camera, which is technically spectating, but doesn't move freely
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

function DuelSpectate(UTDuelGame G) {
    local int Index;
    local Controller C;
    local UTPlayerController Host;
    local PlayerReplicationInfo Winner;
    local bool HostExiting;
    local PlayerController Exiting;

    Exiting = PlayerController(Owner);

    `log("DuelSpectate");

    Index = G.Queue.Find(UTDuelPRI(Exiting.PlayerReplicationInfo));
    if (Index != INDEX_NONE)
    {
        // if player is in queue, just remove him from there
        G.Queue.Remove(Index, 1);
        G.UpdateQueuePositions();
    } else if (
        (!G.bRotateQueueEachKill || !G.GameReplicationInfo.bMatchHasBegun || WorldInfo.IsInSeamlessTravel()) &&
        Exiting.PlayerReplicationInfo != None && 
        Exiting.PlayerReplicationInfo.Team != None &&
        Exiting.PlayerReplicationInfo.Team.Size == 1 
    )
    {
        // if he's in game...

        if (!G.GameReplicationInfo.bMatchHasBegun || WorldInfo.IsInSeamlessTravel())
        {
            if (G.Queue.length > 0)
            {
                // just add a new player now
                G.GetPlayerFromQueue();
            }
        }
        else if (!G.bGameEnded)
        {
            foreach WorldInfo.AllControllers(class'Controller', C)
            {
                if (C != Exiting && 
                    C.bIsPlayer && 
                    (UTDuelPRI(C.PlayerReplicationInfo) != None) && 
                    (UTDuelPRI(C.PlayerReplicationInfo).QueuePosition < 0)
                )
                {
                    Winner = C.PlayerReplicationInfo;
                    break;
                }
            }
            HostExiting = false;
            foreach LocalPlayerControllers(class'UTPlayerController', Host)
            {
                // see if the host is exiting
                if (Host == Exiting )
                {
                    HostExiting = true;
                }
            }
            // if it's not the host that's leaving
            if (!HostExiting)
            {
                G.EndGame(Winner, "LastMan");
            }
        }
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
        if (UTDuelGame(G) != None) {
            DuelSpectate(UTDuelGame(G));
        }

        PRI.bOnlySpectator = true;
        PRI.bIsSpectator = true;

        if (PC.Pawn != None) {
            PC.Pawn.Suicide();
        }

        PC.GotoState('Spectating');
        PC.ServerViewSelf();

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
    } else {
        PC.ReceiveLocalizedMessage(G.GameMessageClass, 12);
    }
}

defaultproperties
{
    bOnlyRelevantToOwner=true
    bAlwaysTick=True
}
