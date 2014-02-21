class SpectatorUI_Interaction extends Interaction 
    within UTPlayerController
    config(SpectatorUI);

struct SpectatorUI_SpeedBind {
    var name Key;
    var int Value;
};
var array<SpectatorUI_SpeedBind> SpeedBinds;

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
var config Name ZoomButton;
var config name BehindViewKey;
var bool BookmarkModifierButtonHeld;
var SpectatorUI_Bookmarks Bookmarks;
var array<Name> BookmarkKeys;

var UIScene ShortManualRef; // reference to the scene containing short manual
var bool bShortManualShown;

var transient bool bZoomButtonHeld;

// pickup respawn timers
struct SpectatorUI_RespawnTimer {
    var string PickupName;
    var float EstimatedRespawnTime;
};
var array<SpectatorUI_RespawnTimer> RespawnTimers;


static function SpectatorUI_Interaction Create(UTPlayerController PC, SpectatorUI_ReplicationInfo newRI) {
    local SpectatorUI_Interaction SUI_Interaction;
    local int i;

    // remove existing one, if it exists
    // because it's left over from previous map after seamless travel
    for (i = 0; i < PC.Interactions.length; i++) {
        if (SpectatorUI_Interaction(PC.Interactions[i]) != None) {
            PC.Interactions.Remove(i--, 1);
        }
    }

    SUI_Interaction = new(PC) default.class;
    SUI_Interaction.Bookmarks = new(None, PC.WorldInfo.GetMapName(true)) class'SpectatorUI_Bookmarks';
    SUI_Interaction.RI = newRI;
    // have to insert it first so it can intercept bound keys
    PC.Interactions.InsertItem(0, SUI_Interaction);

    PC.Spawn(class'SpectatorUI_MidgameMenuFixer', PC);    

    return SUI_Interaction;
}

static function SpectatorUI_Interaction FindInteraction(UTPlayerController PC) {
    local Interaction Interaction;
    foreach PC.Interactions(Interaction) {
        if (SpectatorUI_Interaction(Interaction) != None) {
            return SpectatorUI_Interaction(Interaction);
        }
    }
    return None;
}

static final function bool SameDirection(vector a, vector b) {
    return a dot b >= 0;
}

function bool ShouldRender() {
    // the same condition appears in UTHUD::DrawGameHud
    return PlayerReplicationInfo != None && (PlayerReplicationInfo.bOnlySpectator || Outer.IsInState('Spectating'));
}

event PostRender(Canvas Canvas) {
    local vector Loc, Dir;
    local rotator Rot;
    local UTHUD HUD;
    local Actor A;
    
    super.PostRender(Canvas);

    HUD = UTHUD(myHUD);
    if (HUD == None || !ShouldRender()) return;

    // even though SpectatorUI works fine with "temporary" spectators
    // don't show manual unless spectator is totally spectator
    if (!bShortManualShown && PlayerReplicationInfo != None && PlayerReplicationInfo.bOnlySpectator) {
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
    if (bZoomButtonHeld) {
        RenderZoomUI(Canvas);
    }
    
    RenderPickupTimers(Canvas);
}
exec function BecomeSpectator() {
    Spectate();
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

exec function SpectatorUI_SetSpeed(float speed)
{
    SpectatorCameraSpeed = Speed;
}

exec function SpectatorUI_AddSpeed(float speed)
{
    SpectatorCameraSpeed += Speed;
}

exec function SpectatorUI_MultiplySpeed(float speed)
{
    SpectatorCameraSpeed *= Speed;
}

static final operator(18) float mod(int a, int b)
{
    local int res;
    res = a - (a / b) * b;
    if (res < 0) res += b;
    return res;
}

function float GetCameraSpeedMultiplier(int i) 
{
    return 2 ** (i - 4);
}

function bool HandleInputKey(int ControllerId, name Key, EInputEvent EventType, float AmountDepressed, bool bGamepad)
{
    local int i;
    local string BindString;
    local vector Loc;
    local rotator Rot;

    // TODO I don't remember why it's sometimes 'return true', and sometimes it's not

    if (LocalPlayer(Player) != None && LocalPlayer(Player).ControllerId == ControllerId) {
        if (ShouldRender()) {
            BindString = PlayerInput.GetBind(Key);

            if (InStr(BindString, "SpectatorUI_") != -1) {
                // player manually bound this mutator's exec function
                // let's hope he knows what he's doing
                return false;
            }
    
            if (EventType == IE_Pressed) {
                i = SpeedBinds.Find('Key', Key);
                if (i != INDEX_NONE) {
                    SpectatorCameraSpeed = default.SpectatorCameraSpeed * GetCameraSpeedMultiplier(SpeedBinds[i].Value);
                } else if (key == BookmarkModifierButton) {
                    BookmarkModifierButtonHeld = true;
                } else if (key == ZoomButton) {
                    bZoomButtonHeld = true; 
                    return true;
                } else if (Key == 'Multiply') {
                    RI.ViewPointOfInterest();
                } else if (Key == BehindViewKey) {
                    bForceBehindView = !bForceBehindView;
                    return true;
                } else if (BookmarkKeys.Find(Key) != INDEX_NONE) {
                    BookmarkButtonPressed(Key); 
                } else {
                    if (BindString == "GBA_NextWeapon") {
                        PlayerSelect(+1);
                        return true;
                    } else if (BindString == "GBA_PrevWeapon") {
                        PlayerSelect(-1);
                        return true;
                    } else if (BindString == "GBA_AltFire") {
                        if (AnimatedCamera(PlayerCamera) == None) {
                            GetPlayerViewPoint(Loc, Rot);
                            Rot.Roll = 0; // we don't really want dutch angle, do we?
                            SetLocation(Loc);
                            SetRotation(Rot);
                            ServerViewSelf();
                            // in standalone games, right mouse detaches camera where it is anyway
                            // and, for some reason, camera ignores SetRotation if it's called before ViewSelf
                            // so call it again
                            // although it's not needed in other game modes, it doesn't hurt anyway
                            SetLocation(Loc);
                            SetRotation(Rot);
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
                } else if (key == ZoomButton) {
                    bZoomButtonHeld = false;
                    return true;
                }
            }
        }
    }
    return false;
}

function bool HandleInptAxis(int ControllerId, name Key, float Delta, float DeltaTime, optional bool bGaypad)
{
    if (bZoomButtonHeld) {
        if (Key == 'MouseY') {
            SetFOV(
                FClamp(FOVAngle - 4 * Delta * DeltaTime, 1, 160)
            );
        }
        return true;
    }
    return false;
}

function bool IsValidSpectatorTarget(PlayerReplicationInfo PRI)
{
    if (PRI == None || PRI.bOnlySpectator) return false;
    // XXX is it the best way?
    if (UTDuelPRI(PRI) != None && UTDuelPRI(PRI).QueuePosition >= 0) return false;

    return true;
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
    
    // XXX why clock? to be honest, I forgot
    POS = HUD.ResolveHudPosition(HUD.ClockPosition, 0, 0);
    POS.x += 28 * HUD.ResolutionScale; // XXX magic constant = bad

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
            // same color as in UTHUD::DisplayLeaderboard
            C.SetDrawColor(200, 200, 200, 255);
        }
        if (Index == SelectedPRIIndex) {
            C.SetPos(POS.x - XL, Index * YL);
            C.DrawTextClipped(SelectedPrefix);
        }
        C.SetPos(POS.x, Index * YL);
        C.DrawTextClipped(GetPlayerString(PRI)); 
    }
}

function RenderPickupTimers(Canvas C)
{
    local UTHUD HUD;
    local int i;
    local int SecondsLeft;

    HUD = UTHUD(myHUD);
    if (HUD == None) return;

    C.Reset();
    C.Font = HUD.GetFontSizeIndex(0);

    for (i = 0; i < RespawnTimers.Length; i++) {
        SecondsLeft = Max(0, RespawnTimers[i].EstimatedRespawnTime - WorldInfo.GRI.ElapsedTime);
        C.DrawText(RespawnTimers[i].PickupName @ SecondsLeft);
    }
}

function RenderZoomUI(Canvas C)
{
    local vector2d POS;
    local UTHUD HUD;

    HUD = UTHUD(myHUD);
    if (HUD == None) return;

    C.Reset();
    C.Font = HUD.GetFontSizeIndex(1);

    POS = HUD.ResolveHudPosition(HUD.ClockPosition, 0, 0);
    POS.x += 10 * HUD.ResolutionScale; // XXX another magic constant

    // XXX another set of random values
    C.SetOrigin(0.0, C.ClipY / 5);
    
    C.SetDrawColor(0, 255, 0);
    C.SetPos(POS.x, POS.y);
    C.DrawTextClipped("FOV:" @ Round(FOVAngle) @ "degrees");
}

function BookmarkButtonPressed(Name Key)
{
    local SpectatorUI_Bookmarks.BookmarkStruct B;
    B.Name = Key;

    if (BookmarkModifierButtonHeld) {
        B.Location = Location;
        B.Rotation = Rotation;
        B.FOV = FOVAngle;
        Bookmarks.SaveBookmark(B);
    } else {
        if (Bookmarks.LoadBookmark(B)) {
            ServerViewSelf();
            SetLocation(B.Location);
            SetRotation(B.Rotation);
            SetFOV(B.FOV);
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
            "Number row - camera speed contorl\n" $
            "LeftAlt + NumPad0-9 - save bookmark (camera position)\n" $
            "NumPad0-9 - load bookmark\n" $
            "Middle mouse button + mouse - zoom (field of view)\n" $
            "Q - behind view (3rd person camera)\n"
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

function UpdateRespawnTime(string PickupName, int i, float ExpectedTime) {
    while (RespawnTimers.Length - 1 < i) {
        RespawnTimers.Length = RespawnTimers.Length + 1;
        RespawnTimers[RespawnTimers.Length - 1].EstimatedRespawnTime = -1;
    }

    RespawnTimers[i].PickupName = PickupName;
    RespawnTimers[i].EstimatedRespawnTime = ExpectedTime;
}

defaultproperties
{
    OnReceivedNativeInputKey=HandleInputKey
    OnReceivedNativeInputAxis=HandleInptAxis

    PlayerSwitchDelay=0.5
    PostPlayerSwitchDelay=2.0
    SelectedPrefix=">  "

    BookmarkModifierButton=LeftAlt
    ZoomButton=MiddleMouseButton
    BehindViewKey=Q

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
}
