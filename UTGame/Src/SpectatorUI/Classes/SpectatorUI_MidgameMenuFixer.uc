class SpectatorUI_MidgameMenuFixer extends Info;

// the index we saw spectate button
var transient int LastMidGameMenuButtonBarSpectateIndex;

function UTUIScene_MidGameMenu GetCurrentMidgameMenu() {
    local UTGameReplicationInfo UTGRI;
    UTGRI = UTGameReplicationInfo(WorldInfo.GRI);
    if (UTGRI != None) {
        return UTGRI.CurrentMidGameMenu;
    }
    return None;
}

event Tick(float DeltaTime) {
    ModifyMidgameMenu();
}

function ModifyMidgameMenu() {
    local UTUIScene_MidGameMenu MGM;
    local delegate<UIObject.OnClicked> Delegate_;
    local PlayerReplicationInfo PRI;

    MGM = GetCurrentMidgameMenu();
    if (MGM == None) return;

    // note that it's absolutely necessary to use static function
    // otherwise game crashes will occur due to leakage of World reference
    Delegate_ = class.static.ButtonBarSpectate;

    PRI = PlayerController(Owner).PlayerReplicationInfo;

    if (PRI != None && !PRI.bOnlySpectator) {
        if (LastMidGameMenuButtonBarSpectateIndex == INDEX_NONE || MGM.ButtonBar.Buttons[LastMidGameMenuButtonBarSpectateIndex].OnClicked != Delegate_) {
            LastMidGameMenuButtonBarSpectateIndex = MGM.ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.SpectateServer>", Delegate_);
        }
    }
}

static function bool ButtonBarSpectate(UIScreenObject InButton, int InPlayerIndex) {
    local LocalPlayer LP;
    local PlayerController PC;
    local SpectatorUI_Interaction SUI;
    local UIScene UIS;
    
    LP = InButton.GetPlayerOwner(InPlayerIndex);
    if (LP != None) {
        PC = LP.Actor;
        if (PC != None) {
            SUI = class'SpectatorUI_Interaction'.static.MaybeSpawnFor(PC); // this function doubles as "find"
            SUI.Spectate();

            UIS = UIObject(InButton).GetScene();
            UIS.SceneClient.CloseScene(UIS);
        }
    }
    return true;
}

defaultproperties
{
    bAlwaysTick=true
    TickGroup=TG_DuringAsyncWork
    
    LastMidGameMenuButtonBarSpectateIndex=-1
}
