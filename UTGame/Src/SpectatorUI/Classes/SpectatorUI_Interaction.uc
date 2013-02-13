class SpectatorUI_Interaction extends Interaction 
    within PlayerController
    config(SpectatorUI);

struct SpectatorUI_SpeedBind {
    var name Key;
    var int Value;
};
var array<SpectatorUI_SpeedBind> SpeedBinds;
var int Speeds[10];

var SpectatorUI_ReplicationInfo RI;

var array<PlayerReplicationInfo> PRIs;
var int SelectedPRIIndex;
enum ESelectionState {
    SS_None,
    SS_InProgress,
    SS_PostSelect
};
var ESelectionState SelectionInProgress;
var config float PlayerSwitchDelay;
var config float PostPlayerSwitchDelay;
var string SelectedPrefix;

var config Name BookmarkModifierButton;
var bool BookmarkModifierButtonHeld;
var SpectatorUI_Bookmarks Bookmarks;
var array<Name> BookmarkKeys;

// the index we saw spectate button
var transient int LastMidGameMenuButtonBarSpectateIndex;

var UIScene ShortManualRef; // reference to the scene containing short manual
var bool bShortManualShown;

static function SpectatorUI_Interaction MaybeSpawnFor(PlayerController PC) {
    local Interaction Interaction;
    local SpectatorUI_Interaction SUI_Interaction;

    foreach PC.Interactions(Interaction) {
        if (SpectatorUI_Interaction(Interaction) != None) {
            return SpectatorUI_Interaction(Interaction);
        }
    }
    
    SUI_Interaction = new(PC) default.class;
    SUI_Interaction.Bookmarks = new(None, PC.WorldInfo.GetMapName(true)) class'SpectatorUI_Bookmarks';
    // have to insert it first so it could intercept
    // bound keys
    PC.Interactions.InsertItem(0, SUI_Interaction);
    return SUI_Interaction;
}

static final function bool SameDirection(vector a, vector b) {
    return a dot b >= 0;
}

function bool ShouldRender() {
    // the same condition appears in UTHUD::DrawGameHud
    return PlayerReplicationInfo != None && (PlayerReplicationInfo.bOnlySpectator || Outer.IsInState('Spectating'));
}

event Tick(float DeltaTime) {
    super.Tick(DeltaTime);

    ModifyMidgameMenu();
}

event PostRender(Canvas Canvas) {
    local vector Loc, Dir;
    local rotator Rot;
    local UTHUD HUD;
    local Actor A;
    
    super.PostRender(Canvas);

    HUD = UTHUD(myHUD);
    if (HUD == None || !ShouldRender()) return;

    if (!bShortManualShown) {
        OpenManual();
        bShortManualShown = true;
    }

    Canvas.Font = HUD.GetFontSizeIndex(0);
    
    GetPlayerViewPoint(Loc, Rot);
    Dir = vector(Rot);

    foreach HUD.PostRenderedActors(A) {
        if (A == None) continue;
        if (!SameDirection(Dir, A.Location - Loc)) continue;

        if (UTPawn(A) != None) {
            UTPawn_PostRenderFor(UTPawn(A), Outer, Canvas, Loc, Dir);
        } else if (UTVehicle(A) != None) {
            UTVehicle_PostRenderFor(UTVehicle(A), Outer, Canvas, Loc, Dir);
        } else if (UTOnslaughtFlag(A) != None) {
            UTOnslaughtFlag_PostRenderFor(UTOnslaughtFlag(A), Outer, Canvas, Loc, Dir);
        }
    }
    if (SelectionInProgress != SS_None) {
        RenderPlayerList(Canvas);
    }
}


function UTUIScene_MidGameMenu GetCurrentMidgameMenu() {
    local UTGameReplicationInfo UTGRI;
    UTGRI = UTGameReplicationInfo(WorldInfo.GRI);
    if (UTGRI != None) {
        return UTGRI.CurrentMidGameMenu;
    }
    return None;
}

function ModifyMidgameMenu() {
    local UTUIScene_MidGameMenu MGM;
    local delegate<UIObject.OnClicked> Delegate_;

    MGM = GetCurrentMidgameMenu();
    if (MGM == None) return;

    // note that it's absolutely necessary to use static function
    // otherwise game crashes will occur due to leakage of World reference
    Delegate_ = class.static.ButtonBarSpectate;

    if (PlayerReplicationInfo != None && !PlayerReplicationInfo.bOnlySpectator) {
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
            SUI = MaybeSpawnFor(PC); // this function doubles as "find"
            SUI.Spectate();

            UIS = UIObject(InButton).GetScene();
            UIS.SceneClient.CloseScene(UIS);
        }
    }
    return true;
}

function Spectate() {
    RI.ServerSpectate();
}

static function UTPawn_PostRenderFor(UTPawn P, PlayerController PC, Canvas Canvas, vector Loc, vector Dir) {
    local bool bPostRenderOtherTeam;
    local float TeamBeaconMaxDist;
    local float TeamBeaconPlayerInfoMaxDist;

    bPostRenderOtherTeam = P.bPostRenderOtherTeam;
    TeamBeaconMaxDist = P.TeamBeaconMaxDist;
    TeamBeaconPlayerInfoMaxDist = P.TeamBeaconPlayerInfoMaxDist;

    P.bPostRenderOtherTeam = true;
    P.TeamBeaconMaxDist *= 3;
    P.TeamBeaconPlayerInfoMaxDist *= 3;

    P.NativePostRenderFor(PC, Canvas, Loc, Dir);

    P.bPostRenderOtherTeam = bPostRenderOtherTeam;
    P.TeamBeaconMaxDist = TeamBeaconMaxDist;
    P.TeamBeaconPlayerInfoMaxDist = TeamBeaconPlayerInfoMaxDist;
}

static function UTVehicle_PostRenderFor(UTVehicle V, PlayerController PC, Canvas Canvas, vector Loc, vector Dir) {
    local bool bPostRenderOtherTeam;
    local float TeamBeaconMaxDist;
    local float TeamBeaconPlayerInfoMaxDist;

    bPostRenderOtherTeam = V.bPostRenderOtherTeam;
    TeamBeaconMaxDist = V.TeamBeaconMaxDist;
    TeamBeaconPlayerInfoMaxDist = V.TeamBeaconPlayerInfoMaxDist;

    V.bPostRenderOtherTeam = true;
    V.TeamBeaconMaxDist *= 3;
    V.TeamBeaconPlayerInfoMaxDist *= 3;

    V.NativePostRenderFor(PC, Canvas, Loc, Dir);

    V.bPostRenderOtherTeam = bPostRenderOtherTeam;
    V.TeamBeaconMaxDist = TeamBeaconMaxDist;
    V.TeamBeaconPlayerInfoMaxDist = TeamBeaconPlayerInfoMaxDist;
}

static function UTOnslaughtFlag_PostRenderFor(UTOnslaughtFlag O, PlayerController PC, Canvas Canvas, vector Loc, vector Dir) {
    O.PostRenderFor(PC, Canvas, Loc, Dir);
}

exec function SpectatorUI_SetSpeed(int x)
{
    bRun = clamp(x - 1, 0, 255);
}

exec function SpectatorUI_AddSpeed(int x)
{
    bRun = clamp(bRun + x, 0, 255);
}

exec function SpectatorUI_MultiplySpeed(int x)
{
    bRun = clamp((1 + bRun << x) - 1, 0, 255);
}

exec function SpectatorUI_DivideSpeed(int x)
{
    bRun = clamp((1 + bRun >> x) - 1, 0, 255);
}

static final operator(18) float mod(int a, int b)
{
    local int res;
    res = a - (a / b) * b;
    if (res < 0) res += b;
    return res;
}

function bool HandleInputKey(int ControllerId, name Key, EInputEvent EventType, float AmountDepressed, bool bGamepad)
{
    local int i;
    local string BindString;
    local vector Loc;
    local rotator Rot;

    if (LocalPlayer(Player) != None && LocalPlayer(Player).ControllerId == ControllerId) {
        if (ShouldRender()) {
            if (EventType == IE_Pressed) {
                i = SpeedBinds.Find('Key', Key);
                if (i != INDEX_NONE) {
                    bRun = Speeds[SpeedBinds[i].Value];
                } else if (key == BookmarkModifierButton) {
                    BookmarkModifierButtonHeld = true;
                } else if (Key == 'Multiply') {
                    RI.ViewPointOfInterest();
                } else if (BookmarkKeys.Find(Key) != INDEX_NONE) {
                    BookmarkButtonPressed(Key); 
                } else {
                    BindString = PlayerInput.GetBind(Key);
                    if (BindString == "GBA_NextWeapon") {
                        PlayerSelect(+1);
                        return true;
                    } else if (BindString == "GBA_PrevWeapon") {
                        PlayerSelect(-1);
                        return true;
                    } else if (BindString == "GBA_AltFire") {
                        if (AnimatedCamera(PlayerCamera) == None) {
                            GetPlayerViewPoint(Loc, Rot);
                            SetLocation(Loc);
                            SetRotation(Rot);
                            ServerViewSelf();
                            return true;
                        }
                    } else if (BindString == "GBA_Fire") {
                        if (ShortManualRef != None) {
                            CloseManual();
                            return true;
                        }
                    }
                }
            } else if (EventType == IE_Released) {
                if (key == BookmarkModifierButton) {
                    BookmarkModifierButtonHeld = false;
                }
            }
        }
    }
    return false;
}

function bool IsValidSpectatorTarget(PlayerReplicationInfo PRI)
{
    return PRI != None && !PRI.bOnlySpectator;
}

function PlayerSelect(int increment)
{
    local PlayerReplicationInfo PRI;
    local TeamInfo TI;
    local UTGameReplicationInfo UTGRI;
    local int TeamIndex;

    if (SelectionInProgress == SS_None) {
        SelectionInProgress = SS_InProgress;
        PRIs.Length = 0;

        UTGRI = UTHUD(myHUD).UTGRI;
        
        for (TeamIndex = 0; TeamIndex < UTGRI.Teams.Length + 1; TeamIndex++) {
            TI = TeamIndex < UTGRI.Teams.Length ? UTGRI.Teams[TeamIndex] : None;
            foreach UTGRI.PRIArray(PRI) {
                if (PRI.Team == TI && IsValidSpectatorTarget(PRI)) {
                    PRIs.AddItem(PRI);
                    if (RealViewTarget == PRI) {
                        SelectedPRIIndex = PRIs.Length - 1;
                    }
                }
            }
        }
    }
    if (PRIs.Length == 0) {
        SelectionInProgress = SS_None;
        return;
    }
        
    SelectedPRIIndex = (SelectedPRIIndex + increment) mod PRIs.Length;
    if (SelectionInProgress == SS_PostSelect) {
        SelectionInProgress = SS_InProgress;
    }
    SetTimer(PlayerSwitchDelay, false, 'EndPlayerSelect', self);
}

function EndPlayerSelect()
{
    if (SelectionInProgress == SS_InProgress) {
        SelectionInProgress = SS_PostSelect;
    
        RI.ViewPlayer(PRIs[SelectedPRIIndex]);
        SetTimer(PostPlayerSwitchDelay, false, 'EndPlayerSelect', self);
    } else if (SelectionInProgress == SS_PostSelect) {
        SelectionInProgress = SS_None;
        PRIs.Length = 0;
    }
}

function string GetPlayerString(PlayerReplicationInfo PRI) {
    local string s;
    s = PRI.GetPlayerAlias();
    if (PRI.bHasFlag) {
        if (UTOnslaughtGRI(WorldInfo.GRI) != None) {
            s @= "[ORB]";
        } else {
            s @= "[FLAG]";
        }
    }
    return s;
}

function float GetLongestPlayerListEntry(Canvas C)
{
    local PlayerReplicationInfo PRI;
    local float XL, YL;
    local float Res;
    foreach PRIs(PRI) {
        C.StrLen(GetPlayerString(PRI), XL, YL);
        if (XL > Res) Res = XL;
    }
    return Res;
}

function RenderPlayerList(Canvas C)
{
    local UTHUD HUD;
    local PlayerReplicationInfo PRI;
    local int Index;
    local LinearColor LC;
    local float XL, YL;
    local vector2d POS;
    HUD = UTHUD(myHUD);
    if (HUD == None) return;
    
    C.Reset();
    C.Font = HUD.GetFontSizeIndex(1);

    C.StrLen(SelectedPrefix, XL, YL);
    
    POS = HUD.ResolveHudPosition(HUD.ClockPosition, 0, 0);
    POS.x += 28 * HUD.ResolutionScale;

    C.SetOrigin(0.0, C.ClipY / 6);
    C.ClipX = GetLongestPlayerListEntry(C) + 2 * POS.x;

    C.SetPos(0.0, 0.0);
    C.SetDrawColor(0, 0, 0, 100);
    C.DrawRect(C.ClipX, YL * PRIs.Length);

    foreach PRIs(PRI, Index) {
        if (PRI == None) continue;

        if (Index == SelectedPRIIndex) {
            // background for currently selected player
            // should be darker
            C.SetDrawColor(0, 0, 0, 200);
            C.SetPos(0.0, Index * YL);
            C.DrawRect(C.ClipX, YL);
        }

        if (PRI.Team != None) {
            HUD.GetTeamcolor(PRI.GetTeamNum(), LC);
            C.SetDrawColor(
                Clamp(LC.R * 255.0, 0, 255), 
                Clamp(LC.G * 255.0, 0, 255),
                Clamp(LC.B * 255.0, 0, 255)
            );
        } else {
            C.DrawColor = class'Canvas'.default.DrawColor;
        }
        if (Index == SelectedPRIIndex) {
            C.SetPos(POS.x - XL, Index * YL);
            C.DrawTextClipped(SelectedPrefix);
        }
        C.SetPos(POS.x, Index * YL);
        C.DrawTextClipped(GetPlayerString(PRI)); 
    }
}

function BookmarkButtonPressed(Name Key)
{
    local SpectatorUI_Bookmarks.BookmarkStruct B;
    B.Name = Key;

    if (BookmarkModifierButtonHeld) {
        B.Location = Location;
        B.Rotation = Rotation;
        Bookmarks.SaveBookmark(B);
    } else {
        if (Bookmarks.LoadBookmark(B)) {
            ServerViewSelf();
            SetLocation(B.Location);
            SetRotation(B.Rotation);
        } else {
            ClientMessage("Bookmark" @ Key @ "is not set. Press" @ BookmarkModifierButton $ "+" $ Key @ "to set it.");
        }
    }
}

function OpenManual() {
    local GameUISceneClient SC;
    local UIScene UIS;
    
    SC = class'UIRoot'.static.GetSceneClient();
    if (SC != None) {
        UIS = UIScene(DynamicLoadObject(class.GetPackageName() $ ".SpectatorUI_Content.ShortManual", class'UIScene'));
        UIS.OnSceneActivated = static.OnShortManualActivated;
        if (UIS != None && SC.OpenScene(UIS)) {
            ShortManualRef = UIS;
        }
    }
}

static function OnShortManualActivated(UIScene UIS, bool bInitialActivation) {
    if (bInitialActivation) {
        UILabel(UIS.FindChild('ManualLabel', true)).SetValue(
            "Number row - camera speed (exponential)\n" $
            "Left Alt + Keypad number - save bookmark (camera position)\n" $
            "Keypad number - load bookmark\n" 
        );
    }
}

function CloseManual() {
    local GameUISceneClient SC;
    SC = class'UIRoot'.static.GetSceneClient();
    if (SC != None) {
        if (SC.CloseScene(ShortManualRef)) {
            ShortManualRef = None;
        }
    }
}

defaultproperties
{
    OnReceivedNativeInputKey=HandleInputKey
    LastMidGameMenuButtonBarSpectateIndex=-1

    PlayerSwitchDelay=0.5
    PostPlayerSwitchDelay=2.0
    SelectedPrefix=">  "

    BookmarkModifierButton=LeftAlt

    SpeedBinds.Add((Key=one,Value=0))
    SpeedBinds.Add((Key=two,Value=1))
    SpeedBinds.Add((Key=three,Value=2))
    SpeedBinds.Add((Key=four,Value=3))
    SpeedBinds.Add((Key=five,Value=4))
    SpeedBinds.Add((Key=six,Value=5))
    SpeedBinds.Add((Key=seven,Value=6))
    SpeedBinds.Add((Key=eight,Value=7))
    SpeedBinds.Add((Key=nine,Value=8))
    SpeedBinds.Add((Key=zero,Value=9))

    //SpeedBinds.Add((Key=NumPadone,Value=1))
    //SpeedBinds.Add((Key=NumPadtwo,Value=2))
    //SpeedBinds.Add((Key=NumPadthree,Value=3))
    //SpeedBinds.Add((Key=NumPadfour,Value=4))
    //SpeedBinds.Add((Key=NumPadfive,Value=5))
    //SpeedBinds.Add((Key=NumPadsix,Value=6))
    //SpeedBinds.Add((Key=NumPadseven,Value=7))
    //SpeedBinds.Add((Key=NumPadeight,Value=8))
    //SpeedBinds.Add((Key=NumPadnine,Value=9))
    //SpeedBinds.Add((Key=NumPadzero,Value=0))

    BookmarkKeys.Add(NumPadOne)
    BookmarkKeys.Add(NumPadTwo)
    BookmarkKeys.Add(NumPadThree)
    BookmarkKeys.Add(NumPadFour)
    BookmarkKeys.Add(NumPadFive)
    BookmarkKeys.Add(NumPadSix)
    BookmarkKeys.Add(NumPadSeven)
    BookmarkKeys.Add(NumPadEight)
    BookmarkKeys.Add(NumPadNine)
    BookmarkKeys.Add(NumPadZero)

    Speeds[0] = 0
    Speeds[1] = 1
    Speeds[2] = 2
    Speeds[3] = 4
    Speeds[4] = 8
    Speeds[5] = 16
    Speeds[6] = 32
    Speeds[7] = 64
    Speeds[8] = 128
    Speeds[9] = 255
}
