class SpectatorUI_Mut extends UTMutator
    config(SpectatorUI);

var array<class<Inventory> > InterestingPickupClasses;

var array<SpectatorUI_ReplicationInfo> RIs;
var array<PickupFactory> WatchedPickupFactories;

//function InitMutator(string Options, out string ErrorMessage) {
//    super.InitMutator(Options, ErrorMessage);
//}

function PostBeginPlay() {
    super.PostBeginPlay();

    if (bDeleteMe) return;

    // delay until the next tick for two reasons:
    // 1. until AllNavigationPoints becomes avaiable
    // 2. to give other mutators chance to disable pickups, if they wish so
    SetTimer(0.001, false, 'AttachSequenceObjectsToPickups');
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

function Reset() {
    super.Reset();
    SetTimer(0.001, false, 'UpdateAllRespawnTimesForEveryone');
}

function MatchStarting() {
    super.MatchStarting();
    SetTimer(0.001, false, 'UpdateAllRespawnTimesForEveryone');
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

    if (F.IsInState('WaitingForMatch')) {
        EstimatedRespawnTime = -1;
    } else {
        if (bJustPickedUp) {
            EstimatedRespawnTime += F.GetRespawnTime();
        } else {
            EstimatedRespawnTime += F.LatentFloat;

            UTPF = UTPickupFactory(F);
            if (UTPF != None && !UTPF.bIsRespawning) {
                EstimatedRespawnTime += F.RespawnEffectTime;
            }
        } 
        EstimatedRespawnTime += WorldInfo.TimeSeconds;
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

    bBigGameType = UTOnslaughtGame(WorldInfo.Game) != None || UTVehicleCTFGame(WorldInfo.Game) != None;

    if (!bBigGameType && UTArmorPickupFactory(F) != None) {
        return true;
    }

    return false;
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
        
        WatchedPickupFactories.AddItem(Factory);

        // push update to existing spectators, though it's unlikely there are any
        UpdateRespawnTime(Factory, WatchedPickupFactories.Length - 1);

        `log("Attached" @ PSC @ "to" @ Factory);
    }
}

defaultproperties
{
    bExportMenuData=false
}
