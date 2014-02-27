class SpectatorUI_Mut extends UTMutator
    config(SpectatorUI);

var array<class<Inventory> > InterestingPickupClasses;

var array<SpectatorUI_ReplicationInfo> RIs;
var array<PickupFactory> WatchedPickupFactories;

var int TicksToWait;

//function InitMutator(string Options, out string ErrorMessage) {
//    super.InitMutator(Options, ErrorMessage);
//}

function PostBeginPlay() {
    local SpectatorUI_GameRules GR;

    super.PostBeginPlay();

    if (bDeleteMe) return;

    // delay until the next tick for two reasons:
    // 1. until AllNavigationPoints becomes avaiable
    // 2. to give other mutators chance to disable pickups, if they wish so
    SetTimer(0.001, false, 'AttachSequenceObjectsToPickups');

    GR = Spawn(class'SpectatorUI_GameRules');
    GR.Mut = self;
    if (WorldInfo.Game.GameRulesModifiers == None) {
        WorldInfo.Game.GameRulesModifiers = GR;
    } else {
        WorldInfo.Game.GameRulesModifiers.AddGameRules(GR);
    }
}

function bool CheckReplacement(Actor Other) {
    if (DemoRecSpectator(Other) != None) {
        RIs.AddItem(Spawn(class'SpectatorUI_ReplicationInfo', Other));
    }
    return true;
}

function NotifyLogin(Controller NewPlayer) {
    local SpectatorUI_ReplicationInfo RI;

    if (UTPlayerController(NewPlayer) != None) { // skip e.g. bots
        RI = Spawn(class'SpectatorUI_ReplicationInfo', NewPlayer);
        RI.Mut = self;
        RIs.AddItem(RI);
        
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

// called by SpectatorUI_GameRules::ScoreKill
function ScoreKill(Controller Killer, Controller Killed) {
    local SpectatorUI_ReplicationInfo RI;
    foreach RIs(RI) {
        RI.ScoreKill(Killer, Killed);
    }
}

function DelayedUpdateRespawnTimesForEveryone(int Ticks) {
    TicksToWait = Ticks;
    Enable('Tick');
}

event Tick(float DeltaTime) {
    if (TicksToWait-- <= 0) {
        UpdateAllRespawnTimesForEveryone();
        Disable('Tick');
    }
}

function Reset() {
    super.Reset();
    // due to way how latent functions work, we have to wait a bit
    // 2 ticks is enough, but let's use 3, just in case
    DelayedUpdateRespawnTimesForEveryone(3);
}

function MatchStarting() {
    super.MatchStarting();
    // due to way how latent functions work, we have to wait a bit
    DelayedUpdateRespawnTimesForEveryone(3);
}

function OnPickupStatusChange(PickupFactory F, Pawn EventInstigator) {
    local SpectatorUI_ReplicationInfo RI;

    if (EventInstigator != None) {
        // taken
        foreach RIs(RI) {
            RI.InterestingPickupTaken(EventInstigator, F, None);
        }
        UpdateRespawnTime(F, , , true);
    } else {
        // available   
    }
}

function UpdateAllRespawnTimesForEveryone() {
    UpdateAllRespawnTimesFor(None);
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
    optional SpectatorUI_ReplicationInfo RI = None,
    optional bool bJustPickedUp = false
) 
{
    local float EstimatedRespawnTime;
    local UTPickupFactory UTPF;
        
    EstimatedRespawnTime = WorldInfo.TimeSeconds;

    if (F.IsInState('WaitingForMatch') || F.IsInState('Disabled') || F.IsInState('SleepInfinite') || F.IsInState('WaitingForDeployable')) {
        EstimatedRespawnTime = -1;
    } else if (bJustPickedUp) {
        EstimatedRespawnTime += F.GetRespawnTime();
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
    
    if (i == INDEX_NONE) {
        i = WatchedPickupFactories.Find(F);
    }

    if (i == INDEX_NONE) {
        `warn("Tried to update respawn time of unregistered factory");
        return;
    }
    
    if (RI == None) {
        foreach RIs(RI) {
            RI.UpdateRespawnTime(F, i, EstimatedRespawnTime);
        }
    } else {
        RI.UpdateRespawnTime(F, i, EstimatedRespawnTime);
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

    // if it's enabled by means of kismet,
    // there's no defined respawn timer
    if (F.IsInState('SleepInfinite')) return false;

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
    // 4. Powerups (UD, Berserk)
    // 3. Super-weapons
    // 2. Armors and health
    // 1. Misc (jump boots, deployables) and everthing else

    if (UTPowerupPickupFactory(F) != None && F.bIsSuperItem) return 4;
    if (UTWeaponPickupFactory(F) != None && F.bIsSuperItem) return 3;
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

    for (i = 0; i < WatchedPickupFactories.Length; i++) {
        if (ComparePickupFactories(WatchedPickupFactories[i], F) >= 0) {
            break;
        }
    }
    WatchedPickupFactories.InsertItem(i, F);
}

function AttachSequenceObjectsToPickups() {
    local UTPickupFactory Factory;
    local SeqEvent_PickupStatusChange_Delegate PSC;
    local Sequence FakeParent;
    
    `log("Attaching sequence objects to pickup factories...");
    
    FakeParent = WorldInfo.GetGameSequence();
    
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

        `log("Attached" @ PSC @ "to" @ Factory);
    }
}

defaultproperties
{
    bExportMenuData=false
}
