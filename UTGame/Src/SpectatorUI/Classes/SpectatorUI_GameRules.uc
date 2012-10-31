class SpectatorUI_GameRules extends GameRules;

static function SpectatorUI_GameRules AddRulesTo(GameInfo Game, optional Actor Owner_) {
    local SpectatorUI_GameRules ret;

    // could've used GameInfo::AddGameRules,
    // but it doesn't allow Owner to be modified

    ret = Game.Spawn(default.class, Owner_);

    if (Game.GameRulesModifiers == None) {
        Game.GameRulesModifiers = ret;
    } else {
        Game.GameRulesModifiers.AddGameRules(ret);
    }
    return ret;
}

function bool OverridePickupQuery(Pawn Other, class<Inventory> ItemClass, Actor Pickup, out byte bAllowPickup) {
    local bool ret;
    
    ret = super.OverridePickupQuery(Other, ItemClass, Pickup, bAllowPickup);

    if (!ret || bool(bAllowPickup)) {
        if (SpectatorUI_Mut(Owner) != None) {
            SpectatorUI_Mut(Owner).NotifyInventoryPickup(Other, ItemClass, Pickup);
        }
    }
 
    return ret;
}


