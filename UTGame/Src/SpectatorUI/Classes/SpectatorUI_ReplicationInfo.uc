/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_ReplicationInfo extends ReplicationInfo;

// resynch time every this seconds
const TIME_SYNCH_INTERVAL = 30.0;

// force additional synch after this many seconds
// to avoid connection saturation and other shit
const INITIAL_TIME_SYNCH_RETRY_DELAY = 2.5;


struct PointsOfInterestContainer {
    var Actor Actors[3];
    var int Ptr; // current pos 
    var int ReadPtr;
};

struct ServerClientSettings {
    var bool bEnableBecomeSpectator;
};

// set only on clients
var SpectatorUI_Interaction SUI;
var float ServerTimeDelta;
var ServerClientSettings Settings;
var repnotify Actor Owner_;

// set only on server
var PointsOfInterestContainer PointsOfInterest;
var SpectatorUI_Mut Mut;
var bool bTimeReplicated;
var bool bOwnerReplicated;
var bool bFollowKiller;
var bool bUnattendedMode;

// set on both
var float ServerTimeSeconds; // time of last update

replication {
    if (bNetInitial)
        Owner_;
}

var float LastBecomeSpectatorTime;

// struct PointsOfInterestContainer "methods"

// note: simulated only to support demos
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

// note: simulated only to support demos
simulated function Actor GetBestViewTarget(Actor A) {
    if (UTCTFFlag(A) != None) {
        return UTCTFFlag(A).HomeBase.GetBestViewTarget();
    }
    if (UTOnslaughtFlag(A) != None) {
        return UTOnslaughtFlag(A).HomeBase.GetBestViewTarget();
    }
    return A;
}

// note: simulated only to support demos
simulated function Actor GetNextInterestingActor() {
    local Actor A;
    local int MinPtr;
    A = PointsOfInterest.Actors[PointsOfInterest.ReadPtr];
    MinPtr = PointsOfInterest.Ptr - 1;
    if (MinPtr < 0) MinPtr = ArrayCount(PointsOfInterest.Actors) - 1; 
    do {
        if (--PointsOfInterest.ReadPtr < 0) PointsOfInterest.ReadPtr = ArrayCount(PointsOfInterest.Actors) - 1;
    } until (PointsOfInterest.ReadPtr == MinPtr || PointsOfInterest.Actors[PointsOfInterest.ReadPtr] != None);
    return GetBestViewTarget(A);
}

simulated event ReplicatedEvent(name VarName)
{
    super.ReplicatedEvent(VarName);

    if (VarName == 'Owner_' && Owner == None) {
        SetOwner(Owner_);
        ServerOwnerReady();
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

simulated function Init() {
     if (Role == ROLE_Authority) {
        if (PlayerController(Owner).IsLocalPlayerController()) {
            ServerTimeDelta = 0; // it's always zero for local players
            TryAttachInteraction();
            
            ServerOwnerReady();
        } else {
            Owner_ = Owner;
            if (DemoRecSpectator(Owner) != None) {
                if (Owner.GetStateName() == Owner.Class.Name) {
                    // DemoRecSpectator isn't ready yet
                    // try again later
                    SetTimer(0.01, false, 'Init');
                    return;
                }
                ServerOwnerReady();
            }
            // and continue from ReplicatedEvent
        }
    }  
}

reliable server function ServerOwnerReady() {
    local ServerClientSettings NewSettings;

    bOwnerReplicated = true;
    
    NewSettings.bEnableBecomeSpectator = Mut.Settings.bEnableBecomeSpectator;
    ClientUpdateSettings(NewSettings);

    Mut.UpdateAllRespawnTimesFor(self);

    SetTimer(INITIAL_TIME_SYNCH_RETRY_DELAY * (1.0 + FRand()), false, 'ForceReplicateTimeDelta'); 
}

reliable client function ClientUpdateSettings(ServerClientSettings NewSettings) {
    Settings = NewSettings;
    SUI.SettingsUpdated(); 
}

function NotifyBecomeSpectator() {
    if (PlayerController(Owner).IsLocalPlayerController()) {
        ServerTimeDelta = 0; // it's always zero for local players
    }

    UpdateUnattendedMode();

    Mut.UpdateAllRespawnTimesFor(self);
}

function NotifyBecomeActive() {
    // clear timer, in case it's active
    ClearTimer('TryReplicateTimeDelta');
    UpdateUnattendedMode();
}

function ForceReplicateTimeDelta() {
    bTimeReplicated = false;
    TryReplicateTimeDelta();
}

function TryReplicateTimeDelta() {
    if (IsTimerActive('TryReplicateTimeDelta')) {
        return;
    }
    if (bTimeReplicated) {
        if (WorldInfo.TimeSeconds - ServerTimeSeconds > TIME_SYNCH_INTERVAL) {
            bTimeReplicated = false;
        } else {
            return;
        }
    }

    //`log("Trying to replicate server time" @ WorldInfo.TimeSeconds);
    ServerTimeSeconds = WorldInfo.TimeSeconds;
    ClientReplicateTimeDelta(ServerTimeSeconds);

    if (DemoRecSpectator(Owner) != None) {
        bTimeReplicated = true;
        return;
    }

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
    bTimeReplicated = true;
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
    
    // important check
    // BaseSpectating shouldn't pass here
    if (!Owner.IsInState('Spectating')) return;

    if (Other.Controller != None && Other.Controller.PlayerReplicationInfo != None) {
        A = Other.Controller.PlayerReplicationInfo;
        AddInterestingActor(A);
        DemoAddInterestingActor(A); // XXX call it only on DRC-owned RI?
        ClientInterestingPickupTaken(F, GetPickupClass(F), Other.Controller.PlayerReplicationInfo);
    }
}

reliable client function ClientInterestingPickupTaken(PickupFactory F, class<Actor> What, PlayerReplicationInfo Who) {
    SUI.InterestingPickupTaken(F, What, Who); 
}

function UpdateRespawnTime(PickupFactory F, int i, float ExpectedTime, int flags) {
    // important check, again
    if (!Owner.IsInState('Spectating')) return;
    if (!bOwnerReplicated) return;
    
    TryReplicateTimeDelta();
    ClientUpdateRespawnTime(F, GetPickupClass(F), i, ExpectedTime, flags);
}

reliable client function ClientUpdateRespawnTime(PickupFactory F, class<Actor> Clazz, int i, float ExpectedTime, int flags) {
    SUI.UpdateRespawnTime(F, Clazz, i, ExpectedTime, flags);
}

// called from interaction
simulated function ViewPointOfInterest() {
    if (DemoRecSpectator(Owner) != None) {
        DemoViewPointOfInterest();
    } else {
        ServerViewPointOfInterest();
    }
}

reliable server protected function ServerViewPointOfInterest() {
    local Actor A;
    if (Owner.IsInState('BaseSpectating')) {
        A = GetNextInterestingActor();
        if (A == None) return;
        SwitchViewToPointOfInterest(A);
    }
}

simulated protected function DemoViewPointOfInterest() {
    local Actor A;
    A = GetNextInterestingActor();
    if (A == None) return;
    SwitchViewToPointOfInterest(A);
}

simulated function SwitchViewToPointOfInterest(Actor A, optional PlayerReplicationInfo PRI) {
    local Actor NewA;
    if (PRI != none) NewA = PRI;
    else if (UTCarriedObject(A) != none) NewA = UTCarriedObject(A).HolderPRI;
    if (NewA != none) A = NewA;
    if (PlayerReplicationInfo(A) != None) {
        ViewPlayer(PlayerReplicationInfo(A));
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
        Mut.Settings.bEnableBecomeSpectator && 
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

        LastBecomeSpectatorTime = WorldInfo.TimeSeconds;

        G.BroadcastLocalizedMessage(G.GameMessageClass, 14, PRI);

        ClientBecameSpectator();

        if (UTPlayerController(PC) != None && UTPlayerController(PC).VoteRI != None && UTPlayerController(PC).VoteRI.bDeleteMe) {
            // hack that prevents the bug where voting is unavailable to players
            // that do spectate-join cycle without GC running in between
            UTPlayerController(PC).VoteRI = None;
        }
    } else {
        PC.ReceiveLocalizedMessage(G.GameMessageClass, 12);
    }
}

reliable client function ClientBecameSpectator() 
{
    PlayerController(Owner).UpdateURL("SpectatorOnly", "1", false);    
}

function ScoreKill(Controller Killer, Controller Killed)
{
    if (Killer == Killed || Killer == None) {
        // ignore suicides
        return;
    }

    if (DemoRecSpectator(Owner) != None) {
        DemoScoreKill(Killer.PlayerReplicationInfo, Killed.PlayerReplicationInfo);
    } else {
        RealScoreKill(Killer.PlayerReplicationInfo, Killed.PlayerReplicationInfo);
    }

}

reliable demorecording function DemoScoreKill(PlayerReplicationInfo Killer, PlayerReplicationInfo Killed) {
    RealScoreKill(Killer, Killed);
}

simulated function RealScoreKill(PlayerReplicationInfo Killer, PlayerReplicationInfo Killed) {
    if (bFollowKiller && Killed == PlayerController(Owner).RealViewTarget) {
        ViewPlayer(Killer);
    }
}

function FlagEvent(UTGameObjective FlagBase, name EventType, Controller EventInstigator)
{
    local UTCarriedObject Subject;

    if (UTCTFBase(FlagBase) != None) {
        Subject = UTCTFBase(FlagBase).myFlag;
    } else if (UTOnslaughtFlagBase(FlagBase) != None) {
        Subject = UTOnslaughtFlagBase(FlagBase).myFlag;
    }

    if (Owner.IsInState('Spectating')) {
        AddInterestingActor(Subject);
        DemoAddInterestingActor(Subject);
        ClientFlagEvent(Subject, EventType, EventInstigator.PlayerReplicationInfo);
    }   
}

reliable client function ClientFlagEvent(UTCarriedObject Flag, name EventType, PlayerReplicationInfo Who) {
    SUI.FlagEvent(Flag, EventType, Who);
}

reliable server function ServerSetFollowKiller(bool x)
{
    bFollowKiller = x;
}

simulated function SetFollowKiller(bool x)
{
    if (DemoRecSpectator(Owner) != None) {
        bFollowKiller = x;
    } else {
        ServerSetFollowKiller(x);
    }
}

simulated function SetUnattendedMode(bool x) {
    // note that it won't work with DemoRecSpectator
    // unattended demoplaying doesn't makes much sense anyway
    ServerSetUnattendedMode(x);
}

reliable protected server function ServerSetUnattendedMode(bool x) {
    bUnattendedMode = x;
    UpdateUnattendedMode();
}

protected function UpdateUnattendedMode() {
    if (!bUnattendedMode || !Owner.IsInState('Spectating')) {
        ClearTimer('UnattendedTimer');
    } else {
        UnattendedTimer();
        SetTimer(1.0, true, 'UnattendedTimer');
    }
}

function PlayerReplicationInfo GetBestPlayer() {
    local PlayerReplicationInfo PRI, BestPRI;

    foreach WorldInfo.Game.GameReplicationInfo.PRIArray(PRI) {
        if (class'SpectatorUI_Interaction'.static.IsValidSpectatorTarget(PRI) && (BestPRI == None || PRI.Score > BestPRI.Score)) {
            BestPRI = PRI;
        }
    }
    return BestPRI;
}

function UnattendedTimer() {
    local PlayerReplicationInfo PRI;

    if (!Owner.IsInState('Spectating')) {
        UpdateUnattendedMode();
        return;
    }

    if (PlayerController(Owner).RealViewTarget == None) {
        // try to find anyone to watch
        PRI = GetBestPlayer();
        if (PRI != None) {
            PlayerController(Owner).ClientMessage("Switching view target. Type 'SpectatorUI_UnattendedMode 0' to disable unattended mode.");
            ViewPlayer(PRI);
        }
    }
}

defaultproperties
{
    bOnlyRelevantToOwner=true
    bAlwaysTick=True
    LastBecomeSpectatorTime=-1
}
