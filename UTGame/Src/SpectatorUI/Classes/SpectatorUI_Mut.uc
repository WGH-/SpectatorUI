class SpectatorUI_Mut extends UTMutator;

var array<class<Inventory> > InterestingPickupClasses;

var array<SpectatorUI_ReplicationInfo> RIs;

function InitMutator(string Options, out string ErrorMessage) {
    class'SpectatorUI_GameRules'.static.AddRulesTo(WorldInfo.Game, self);    

    super.InitMutator(Options, ErrorMessage);
}

function bool CheckReplacement(Actor Other) {
    if (DemoRecSpectator(Other) != None) {
        RIs.AddItem(Spawn(class'SpectatorUI_ReplicationInfo', Other));
    }
    return true;
}

function NotifyLogin(Controller NewPlayer) {
    if (PlayerController(NewPlayer) != None) { // skip e.g. bots
        RIs.AddItem(Spawn(class'SpectatorUI_ReplicationInfo', NewPlayer));
    }
    super.NotifyLogin(NewPlayer);
}

// called by SpectatorUI_GameRules
function NotifyInventoryPickup(Pawn Other, class<Inventory> ItemClass, Actor Pickup) {
    local class<Inventory> klass;
    local bool bInteresting;
    local SpectatorUI_ReplicationInfo RI;

    foreach InterestingPickupClasses(klass) {
        if (ClassIsChildOf(ItemClass, klass)) {
            bInteresting = true;
            break;
        }
    }

    if (bInteresting) {
        foreach RIs(RI) {
            RI.InterestingPickupTaken(Other, ItemClass, Pickup);
        }
    }
}

defaultproperties
{
    InterestingPickupClasses.Add(class'UTWeap_Redeemer')
    InterestingPickupClasses.Add(class'UTUDamage')
    InterestingPickupClasses.Add(class'UTBerserk')
    InterestingPickupClasses.Add(class'UTDeployableShapedCharge')
}
