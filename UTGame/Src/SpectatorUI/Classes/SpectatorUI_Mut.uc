/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_Mut extends UTMutator
    config(SpectatorUI);

var array<SpectatorUI_ReplicationInfo> RIs;
var array<PickupFactory> WatchedPickupFactories;

var array<PickupFactory> PendingUpdates;
var bool bPendingUpdateAll;

var int TicksToWait;

const WAITING_FOR_DEPLOYABLE_POLLING_INTERVAL = 1.0;
var array<PickupFactory> WaitingForDeployablePolling;

var SpectatorUI_ServerSettings Settings;

//function InitMutator(string Options, out string ErrorMessage) {
//    super.InitMutator(Options, ErrorMessage);
//}

function PostBeginPlay() {
    local SpectatorUI_GameRules GR;

    super.PostBeginPlay();

    if (bDeleteMe) return;

    Settings = new(None, "SpectatorUI") class'SpectatorUI_ServerSettings';

    // delay until the next tick for two reasons:
    // 1. until AllNavigationPoints becomes avaiable
    // 2. to give other mutators chance to disable pickups, if they wish so
    if (Settings.bPowerupTimers) {
        SetTimer(0.001, false, 'AttachSequenceObjectsToPickups');
    }

    GR = Spawn(class'SpectatorUI_GameRules');
    GR.Mut = self;
    if (WorldInfo.Game.GameRulesModifiers == None) {
        WorldInfo.Game.GameRulesModifiers = GR;
    } else {
        WorldInfo.Game.GameRulesModifiers.AddGameRules(GR);
    }
}

function bool CheckReplacement(Actor Other) {
    local SpectatorUI_ReplicationInfo RI;

    if (DemoRecSpectator(Other) != None) {
        RI = Spawn(class'SpectatorUI_ReplicationInfo', Other);
        RI.Mut = self;
        RIs.AddItem(RI);
        RI.Init();

        // since it's not properly initialized yet
        // delay the call for one tick
        RI.SetTimer(0.001, false, 'NotifyBecomeSpectator');
    }
    return true;
}

function NotifyLogin(Controller NewPlayer) {
    local SpectatorUI_ReplicationInfo RI;

    if (UTPlayerController(NewPlayer) != None) { // skip e.g. bots
        RI = Spawn(class'SpectatorUI_ReplicationInfo', NewPlayer);
        RI.Mut = self;
        RIs.AddItem(RI);
        RI.Init();
        
        // XXX what about duel players going to queue?
        if (NewPlayer.PlayerReplicationInfo.bOnlySpectator) {
            RI.NotifyBecomeSpectator();
        } else {
            RI.NotifyBecomeActive();
        }

        UpdateAllRespawnTimesFor(RI);
    }
    super.NotifyLogin(NewPlayer);
}

function NotifyLogout(Controller Exiting) {
    local int i;
    local SpectatorUI_ReplicationInfo RI;

    while (i < RIs.Length) {
        RI = RIs[i];
        if (RI.Owner == Exiting || RI.Owner == None) {
            RI.Destroy();
            RIs.Remove(i, 1);
        } else {
            i++;
        }
    }
    super.NotifyLogout(Exiting);
}

function NotifyBecomeSpectator(PlayerController PC) {
    // XXX what about duel players going to queue?

    local SpectatorUI_ReplicationInfo RI;
    
    super.NotifyBecomeSpectator(PC);

    foreach RIs(RI) {
        if (RI.Owner == PC) {
            RI.NotifyBecomeSpectator();
            break;
        }
    }
}

function NotifyBecomeActivePlayer(PlayerController PC) {
    local SpectatorUI_ReplicationInfo RI;

    super.NotifyBecomeActivePlayer(PC);

    foreach RIs(RI) {
        if (RI.Owner == PC) {
            RI.NotifyBecomeActive();
            break;
        }
    }
}

function bool AllowBecomeActivePlayer(PlayerController PC) {
    local SpectatorUI_ReplicationInfo RI;

    if (PC.PlayerReplicationInfo != None && !PC.PlayerReplicationInfo.bAdmin) {
        foreach RIs(RI) {
            if (RI.Owner == PC) {
                if (RI.LastBecomeSpectatorTime >= 0 && WorldInfo.TimeSeconds - RI.LastBecomeSpectatorTime < Settings.RejoinDelay) {
                    return false;
                }
                break;
            }
        }
    }

    return super.AllowBecomeActivePlayer(PC);

}

// called by SpectatorUI_GameRules::ScoreKill
function ScoreKill(Controller Killer, Controller Killed) {
    local SpectatorUI_ReplicationInfo RI;
    foreach RIs(RI) {
        RI.ScoreKill(Killer, Killed);
    }
}

function DelayedUpdateRespawnTimesEverything(int Ticks) {
    if (!Settings.bPowerupTimers) return;

    TicksToWait = Max(Ticks, TicksToWait);
    bPendingUpdateAll = true;
    Enable('Tick');
}

function DelayedUpdateRespawnTime(int Ticks, PickupFactory F) {
    if (!Settings.bPowerupTimers) return;

    TicksToWait = Max(Ticks, TicksToWait);
    if (PendingUpdates.Find(F) == INDEX_NONE) {
        PendingUpdates.AddItem(F);
    }
    Enable('Tick');
}

function DoDelayedUpdate() {
    local PickupFactory F;

    if (bPendingUpdateAll) {
        UpdateAllRespawnTimesFor(None);
        bPendingUpdateAll = false;
    } else {
        foreach PendingUpdates(F) {
            UpdateRespawnTime(F);
        }
    }
    PendingUpdates.Length = 0;
}

event Tick(float DeltaTime) {
    if (TicksToWait-- <= 0) {
        DoDelayedUpdate();
        Disable('Tick');
    }
}

function Reset() {
    super.Reset();
    // due to way how latent functions work, we have to wait a bit
    // 2 ticks is enough, but let's use 3, just in case
    DelayedUpdateRespawnTimesEverything(3);
}

function MatchStarting() {
    super.MatchStarting();
    // due to way how latent functions work, we have to wait a bit
    DelayedUpdateRespawnTimesEverything(3);
}

function OnPickupStatusChange(PickupFactory F, Pawn EventInstigator) {
    local SpectatorUI_ReplicationInfo RI;
    
    if (!Settings.bPowerupTimers) return;

    if (EventInstigator != None) {
        // taken
        foreach RIs(RI) {
            RI.InterestingPickupTaken(EventInstigator, F, None);
        }
        DelayedUpdateRespawnTime(3, F);
    } else {
        // available
        DelayedUpdateRespawnTime(1, F);
    }
}

function UpdateAllRespawnTimesFor(SpectatorUI_ReplicationInfo RI) {
    local int i;
    local PickupFactory F;

    foreach WatchedPickupFactories(F, i) {
        UpdateRespawnTime(F, i, RI);
    }
}

function UpdateRespawnTime(
    PickupFactory F, 
    optional int i = INDEX_NONE, 
    optional SpectatorUI_ReplicationInfo RI = None
) 
{
    local float EstimatedRespawnTime;
    local UTPickupFactory UTPF;
    local int flags;

    if (!Settings.bPowerupTimers) return;
        
    EstimatedRespawnTime = WorldInfo.TimeSeconds;
    
    if (i == INDEX_NONE) {
        i = WatchedPickupFactories.Find(F);
    }

    if (i == INDEX_NONE) {
        `warn("Tried to update respawn time of unregistered factory");
        return;
    }

    if (F.IsInState('Disabled')) {
        EstimatedRespawnTime = -1;
    } else if (F.IsInState('SleepInfinite') || F.IsInState('Inactive')) {
        EstimatedRespawnTime = -1;
        flags = flags | class'SpectatorUI_Interaction'.const.PICKUPTIMER_SCRIPTACTIVATED;
    } else if (F.IsInState('WaitingForDeployable')) {
        EstimatedRespawnTime = -1;
        flags = flags | class'SpectatorUI_Interaction'.const.PICKUPTIMER_WAITINGFORDEPLOYABLE;
        AddWaitingForDeployableFactory(F);
    } else if (F.IsInState('WaitingForMatch')) {
        EstimatedRespawnTime = -1;
        flags = flags | class'SpectatorUI_Interaction'.const.PICKUPTIMER_WAITINGFORMATCH;
    } else if (F.IsInState('Pickup')) {
        // it's available right now
    } else if (F.IsInState('Sleeping')) {
        UTPF = UTPickupFactory(F);
        if (F.LatentFloat <= 0.0) {
            // state code hasn't started executing yet OR just finished
            if (UTPF != None && UTPF.bIsRespawning) {
                EstimatedRespawnTime += F.RespawnEffectTime;
            } else {
                EstimatedRespawnTime += F.GetRespawnTime();
            }
        } else {
            EstimatedRespawnTime += F.LatentFloat;

            if (UTPF != None && !UTPF.bIsRespawning) {
                EstimatedRespawnTime += F.RespawnEffectTime;
            }
        }
    } 
    
    if (RI == None) {
        foreach RIs(RI) {
            RI.UpdateRespawnTime(F, i, EstimatedRespawnTime, flags);
        }
    } else {
        RI.UpdateRespawnTime(F, i, EstimatedRespawnTime, flags);
    }
}

static function ModifyParentSequence(SequenceObject Seq, SequenceObject NewParent) {
    // this function is a basis of terrible hack
    // ParentSequence is a const member
    // so in order to assign to it, I modify UnrealScript bytecode after compilation
    // in such way so this assignment's operands are swapped
    NewParent = Seq.ParentSequence;
}

function bool IsPickupFactoryInteresting(UTPickupFactory F) {
    local bool bBigGameType;

    if (F.bIsDisabled) return false;
    if (F.bIsSuperItem) return true;
    
    // all powerups - DD, berserk, jump boots, etc. - are interesting
    if (UTPowerupPickupFactory(F) != None) return true;

    bBigGameType = UTOnslaughtGame(WorldInfo.Game) != None || UTVehicleCTFGame(WorldInfo.Game) != None;

    if (!bBigGameType && UTArmorPickupFactory(F) != None) {
        return true;
    }

    return false;
}

function int GetCategory(PickupFactory F, out int additional)
{
    // 4. Super-weapons
    // 3. Powerups (UD, Berserk)
    // 2. Armors and health
    // 1. Misc (jump boots, deployables) and everthing else

    if (UTWeaponPickupFactory(F) != None && F.bIsSuperItem) return 4;
    if (UTPowerupPickupFactory(F) != None && F.bIsSuperItem) return 3;
    if (UTArmorPickupFactory(F) != None ) {
        additional = UTArmorPickupFactory(F).ShieldAmount;
        return 2;
    }
    if (UTHealthPickupFactory(F) != None) {
        additional = UTHealthPickupFactory(F).HealingAmount;
        return 2;
    }
    return 1;
}

function int ComparePickupFactories(PickupFactory A, PickupFactory B)
{
    local int res, extra_a, extra_b;
    res = GetCategory(B, extra_b) - GetCategory(A, extra_a);
    if (res == 0) res = extra_b - extra_a;
    if (res == 0) res = (A.InventoryType == B.InventoryType ? 0 : -1);
    return res;
}

function AddWatchedFactory(PickupFactory F) {
    local int i;

    // insert sort
    for (i = 0; i < WatchedPickupFactories.Length; i++) {
        if (ComparePickupFactories(WatchedPickupFactories[i], F) >= 0) {
            break;
        }
    }
    WatchedPickupFactories.InsertItem(i, F);
}

function AddWaitingForDeployableFactory(PickupFactory F) {
    if (WaitingForDeployablePolling.Find(F) == INDEX_NONE) {
        WaitingForDeployablePolling.AddItem(F);
    }
    if (!IsTimerActive('PollWaitingForDeployableFactories')) {
        SetTimer(WAITING_FOR_DEPLOYABLE_POLLING_INTERVAL, true, 'PollWaitingForDeployableFactories');
    }
}

function PollWaitingForDeployableFactories() {
    local int i;
    for (i = 0; i < WaitingForDeployablePolling.Length; i++) {
        if (!WaitingForDeployablePolling[i].IsInState('WaitingForDeployable')) {
            UpdateRespawnTime(WaitingForDeployablePolling[i]);
            WaitingForDeployablePolling.Remove(i, 1);
            i--;
        }
    }
    if (WaitingForDeployablePolling.Length == 0) {
        ClearTimer('PollWaitingForDeployableFactories');
    }
}

function OnFlagEventTrigger(UTGameObjective EventOriginator, name EventType, Controller EventInstigator) {
    local SpectatorUI_ReplicationInfo RI;

    foreach RIs(RI) {
        RI.FlagEvent(EventOriginator, EventType, EventInstigator);
    }   
}

function OnOnslaughtNodeEventTrigger(UTOnslaughtNodeObjective Node, Controller EventInstigator)
{
    local UTDeployableNodeLocker L;

    foreach Node.DeployableLockers(L) {
        DelayedUpdateRespawnTime(3, L);
    }
}

function OnPickupFactoryRelatedSeqActToggleActivate(SeqAct_Delegate SeqAct)
{
    local Object Obj;

    foreach SeqAct.Args(Obj) {
        DelayedUpdateRespawnTime(3, PickupFactory(Obj));
    }
}

function HookKismetToggleActions(Sequence FakeParent) {
    local array<SequenceObject> SeqObjects;
    local SequenceObject SO;

    local SequenceAction SA;
    local SeqVar_Object SVO;
    local PickupFactory PF;

    local SeqAct_Delegate SAD;

    local SeqOpOutputInputLink OutputLink;

    local array<Object> Args;

    if (WorldInfo.GetGameSequence() != None) {
        WorldInfo.GetGameSequence().FindSeqObjectsByClass(class'SeqAct_Toggle', true, SeqObjects);
    }

    foreach SeqObjects(SO) {
        SA = SequenceAction(SO);
        Args.Length = 0;
        foreach SA.LinkedVariables(class'SeqVar_Object', SVO) {
            PF = PickupFactory(SVO.GetObjectValue());
            if (PF != None && WatchedPickupFactories.Find(PF) != INDEX_NONE) {
                Args.AddItem(PF);
            }
        }

        if (Args.Length > 0) {
            SAD = new(None) class'SeqAct_Delegate';
            SAD.Args = Args;
            SAD.OnActivated = OnPickupFactoryRelatedSeqActToggleActivate;

            OutputLink.LinkedOp = SAD;
            OutputLink.InputLinkIdx = 0;
            SA.OutputLinks[0].Links.AddItem(OutputLink);

            ModifyParentSequence(SAD, FakeParent);
        }
    }
}

function AttachSequenceObjectsToPickups() {
    local UTPickupFactory Factory;
    local UTGameObjective UTGameObjective;
    local UTOnslaughtNodeObjective Node;

    local SeqEvent_PickupStatusChange_Delegate PSC;
    local UTSeqEvent_FlagEvent_Delegate FE;
    local UTSeqEvent_OnslaughtNodeEvent_Delegate ONE;

    local Sequence FakeParent;
    
    `log("Attaching sequence objects to pickup factories...",, 'SpectatorUI');
    
    FakeParent = WorldInfo.GetGameSequence();
    if (FakeParent == None) {
        FakeParent = new(None) class'FakeSequence';
    }
    
    foreach WorldInfo.AllNavigationPoints(class'UTPickupFactory', Factory) {
        if (!IsPickupFactoryInteresting(Factory)) continue;

        PSC = new(None) class'SeqEvent_PickupStatusChange_Delegate';
        PSC.Originator = Factory;
        PSC.OnActivated = OnPickupStatusChange;
        ModifyParentSequence(PSC, FakeParent);
        Factory.GeneratedEvents.AddItem(PSC);
        
        AddWatchedFactory(Factory);

        // push update to existing spectators, though it's unlikely there are any
        UpdateRespawnTime(Factory, WatchedPickupFactories.Length - 1);

        `log("Attached" @ PSC @ "to" @ Factory,, 'SpectatorUI');
    }

    foreach WorldInfo.AllNavigationPoints(class'UTGameObjective', UTGameObjective) {
        if (UTCTFBase(UTGameObjective) == None && UTOnslaughtFlagBase(UTGameObjective) == None) {
            // we're only interested in CTF flags and WAR orbs
            continue;
        }

        FE = new(None) class'UTSeqEvent_FlagEvent_Delegate';
        FE.Originator = UTGameObjective;
        FE.OnTrigger = OnFlagEventTrigger;
        ModifyParentSequence(FE, FakeParent);
        UTGameObjective.GeneratedEvents.AddItem(FE);
    }

    foreach WorldInfo.AllNavigationPoints(class'UTOnslaughtNodeObjective',Node) {
        ONE = new(None) class'UTSeqEvent_OnslaughtNodeEvent_Delegate';
        ONE.Originator = Node;
        ONE.OnTrigger = OnOnslaughtNodeEventTrigger;
        ModifyParentSequence(ONE, FakeParent);
        Node.GeneratedEvents.AddItem(ONE);
    }

    HookKismetToggleActions(FakeParent);
}

defaultproperties
{
    bExportMenuData=false
}
