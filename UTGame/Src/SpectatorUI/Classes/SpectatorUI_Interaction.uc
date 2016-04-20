/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
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

var string SelectedPrefix;

var bool BookmarkModifierButtonHeld;
var SpectatorUI_Bookmarks Bookmarks;
var array<Name> BookmarkKeys;

var UIScene ShortManualRef; // reference to the scene containing short manual
var bool bShortManualShown;

var transient bool bZoomButtonHeld;
var transient float LastDoubleclickCheck;
var transient name LastDoubleclickButton;

var bool bFollowPowerup;

// used for unattended mode
var transient bool bMidgameMenuClosed;

var SpectatorUI_ClientSettings Settings;

// if ExpectedTime < 0, these flags give us additional info
const PICKUPTIMER_WAITINGFORMATCH = 0x1;
const PICKUPTIMER_SCRIPTACTIVATED = 0x2;
const PICKUPTIMER_WAITINGFORDEPLOYABLE = 0x4;

// pickup respawn timers
struct SpectatorUI_RespawnTimer {
    var string PickupName;
    var float EstimatedRespawnTime;
    var PickupFactory PickupFactory;
    var int Flags;
};
var array<SpectatorUI_RespawnTimer> RespawnTimers;


static function SpectatorUI_Interaction Create(UTPlayerController PC, SpectatorUI_ReplicationInfo newRI) {
    local SpectatorUI_Interaction SUI_Interaction, OldInteraction;

    // remove existing one, if it exists
    // because it's left over from previous map after seamless travel
    OldInteraction = FindInteraction(PC);
    if (OldInteraction != None) {
        OldInteraction.Cleanup(); 
    }

    SUI_Interaction = new(PC) default.class;
    SUI_Interaction.Bookmarks = new(None, PC.WorldInfo.GetMapName(true)) class'SpectatorUI_Bookmarks';
    SUI_Interaction.RI = newRI;
    // have to insert it first so it can intercept bound keys
    PC.Interactions.InsertItem(0, SUI_Interaction);

    SUI_Interaction.LoadSettings();

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

function Cleanup() {
    local int i;

    // clean up timers on outer player controller
    for (i = 0; i < Timers.length; i++) {
        if (Timers[i].TimerObj == self) {
            ClearTimer(Timers[i].FuncName, self);
            
            // I don't know how exactly ClearTimer works
            // so restart search from the beginning
            i = 0; 
        }
    }

    PRIs.Length = 0;
    RI = None;
    
    if (ShortManualRef != None) {
        CloseManual();
        ShortManualRef = None;
    }
    
    RespawnTimers.Length = 0;

    Interactions.RemoveItem(self);
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
    local LocalPlayer LP;
    
    super.PostRender(Canvas);

    if (RI == None || RI.bDeleteMe) {
        Cleanup();
        return;
    }

    HUD = UTHUD(myHUD);
    if (HUD == None || RI == None) return;

    if (!ShouldRender()) {
        if (ShortManualRef != None) {
            CloseManual();
        }
        return;
    }

    if (Settings.bUnattendedMode && !bMidgameMenuClosed) {
        if (MaybeCloseMidgameMenu()) {
            bMidgameMenuClosed = true;
        }
    }

    if (!bForceBehindView != Settings.bDefaultFirstPerson) {
        Settings.bDefaultFirstPerson = !bForceBehindView;
        Settings.SaveConfig();
    }

    LP = LocalPlayer(Player);

    // even though SpectatorUI works fine with "temporary" spectators
    // don't show manual unless spectator is totally spectator
    if (!bShortManualShown && !Settings.bDisableHelp && PlayerReplicationInfo != None && PlayerReplicationInfo.bOnlySpectator) {
        if (OpenManual()) {
            bShortManualShown = true;
        }
    }

    Canvas.Font = HUD.GetFontSizeIndex(0);
    
    GetPlayerViewPoint(Loc, Rot);
    Dir = vector(Rot);

    foreach HUD.PostRenderedActors(A) {
        if (A == None) continue;
        if (!LP.GetActorVisibility(A)) continue;

        if (UTPawn(A) != None) {
            UTPawn_PostRenderFor(UTPawn(A), Outer, Canvas, Loc, Dir);
        } else if (UTVehicle(A) != None) {
            UTVehicle_PostRenderFor(UTVehicle(A), Outer, Canvas, Loc, Dir);
        } else if (UTOnslaughtFlag(A) != None) {
            UTOnslaughtFlag_PostRenderFor(UTOnslaughtFlag(A), Outer, Canvas, Loc, Dir);
        }
    }
    RenderPickupTimers(Canvas);

    if (SelectionInProgress != SS_None) {
        RenderPlayerList(Canvas);
    }

    if (bZoomButtonHeld) {
        RenderZoomUI(Canvas);
    }

    RenderNowViewing(Canvas);
}

// returns true if menu was closed
function bool MaybeCloseMidgameMenu() {
    local UTGameReplicationInfo GRI;
    GRI = UTGameReplicationInfo(WorldInfo.GRI);
    
    if (GRI != None && GRI.CurrentMidGameMenu != None) {
        GRI.CurrentMidGameMenu.CloseScene(GRI.CurrentMidGameMenu);
        return true;
    }
    return false;
}

function LoadSettings() {
    Settings = new(None, "SpectatorUI") class'SpectatorUI_ClientSettings';

    if (Settings.bFollowPowerup) {
        SpectatorUI_FollowPowerup(true);
    }
    if (Settings.bFollowKiller) {
        SpectatorUI_FollowKiller(true);
    }
    if (Settings.bDefaultFirstPerson) {
        bForceBehindView = false; 
    }
    if (Settings.bUnattendedMode) {
        SpectatorUI_UnattendedMode(true);
    }
}

function Spectate() {
    RI.ServerSpectate();
}

exec function cg_followPowerup(bool x) {
    SpectatorUI_FollowPowerup(x);
}

exec function SpectatorUI_FollowPowerup(bool x) {
    bFollowPowerup = x;
    Settings.bFollowPowerup = bFollowPowerup;
    Settings.SaveConfig();
}

exec function cg_followKiller(bool x) {
    SpectatorUI_FollowKiller(x);

    Settings.bFollowKiller = x;
    Settings.SaveConfig();
}

exec function SpectatorUI_FollowKiller(bool x) {
    RI.SetFollowKiller(x);
}

exec function Ghost() {
    if (CheatManager != None) {
        // pass it to CheatManager
        CheatManager.Ghost();
    } else {
        // toggle it here
        bCollideWorld = !bCollideWorld;
    }
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

exec function SpectatorUI_UnattendedMode(bool bEnable) 
{
    if (bEnable) {
        // don't need manual
        bShortManualShown = true;
    }

    RI.SetUnattendedMode(bEnable);
    
    Settings.bUnattendedMode = bEnable;
    Settings.SaveConfig();
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
    
    // true is returned when I totally want to override something
    // like builtin view target switching

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
                } else if (key == Settings.BookmarkModifierButton) {
                    BookmarkModifierButtonHeld = true;
                } else if (key == Settings.ZoomButton) {
                    if (IsKeyDoubleclicked(Key, EventType)) {
                        ZoomButtonReset();
                    } else {
                        bZoomButtonHeld = true; 
                    }
                } else if (Key == 'Multiply') {
                    RI.ViewPointOfInterest();
                } else if (Key == Settings.BehindViewKey) {
                    BehindView(); 
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
                            
                            ServerViewSelf();

                            // set position after ServerViewSelf because:
                            // 1. on clients, it doesn't make any difference, as call is asynchronous
                            // 2. on authority, ServerViewSelf sets position immediately,
                            //    and thus ignores Roll set to zero
                            SetLocation(Loc);
                            SetRotation(Rot);
                            return true;
                        }
                    } else if (BindString == "GBA_Fire") {
                        if (ShortManualRef != None) {
                            CloseManual();
                            return true;
                        }
                        // otherwise, let ViewObjective handle it
                    }
                }
            } else if (EventType == IE_Released) {
                if (key == Settings.BookmarkModifierButton) {
                    BookmarkModifierButtonHeld = false;
                } else if (key == Settings.ZoomButton) {
                    bZoomButtonHeld = false;
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

static function bool IsValidSpectatorTarget(PlayerReplicationInfo PRI)
{
    if (PRI == None || PRI.bOnlySpectator) return false;
    // special duel handling
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
    if (Settings.PlayerSwitchDelay > 0) {
        SetTimer(Settings.PlayerSwitchDelay, false, 'EndPlayerSelect', self);
    } else {
        EndPlayerSelect();
    }
}

function EndPlayerSelect()
{
    if (SelectionInProgress == SS_InProgress) {
        SelectionInProgress = SS_PostSelect;
    
        RI.ViewPlayer(PRIs[SelectedPRIIndex]);
        if (Settings.PostPlayerSwitchDelay > 0) {
            SetTimer(Settings.PostPlayerSwitchDelay, false, 'EndPlayerSelect', self);
        } else {
            EndPlayerSelect();
        }
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
    local float OldClipX;
    HUD = UTHUD(myHUD);
    if (HUD == None) return;
    
    C.Reset();
    C.Font = HUD.GetFontSizeIndex(1);

    C.StrLen(SelectedPrefix, XL, YL);
    
    // XXX why clock? to be honest, I forgot
    POS = HUD.ResolveHudPosition(HUD.ClockPosition, 0, 0);
    POS.x += 28 * HUD.ResolutionScale; // XXX magic constant = bad

    C.SetOrigin(0.0, C.ClipY / 6);
    OldClipX = C.ClipX;
    C.ClipX = GetLongestPlayerListEntry(C) + 2 * POS.x;

    C.SetPos(0.0, 0.0);
    C.SetDrawColor(0, 0, 0, 150);
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

    C.ClipX = OldClipX;
}

function RenderPickupTimers(Canvas C)
{
    local UTHUD HUD;
    local int i;
    local int SecondsLeft;
    local string s;
    local float XL, YL;
    local float FirstColumnSize;
    local color VisibleColor, HiddenColor;
    local LocalPlayer LP;
    local int flags;

    HUD = UTHUD(myHUD);
    if (HUD == None) return;

    LP = LocalPlayer(Player);

    VisibleColor = HUD.GoldColor;
    HiddenColor.R = VisibleColor.R / 5 * 3;
    HiddenColor.G = VisibleColor.G / 5 * 3;
    HiddenColor.B = VisibleColor.B / 5 * 3;
    HiddenColor.A = VisibleColor.A;

    C.Reset();
    C.Font = HUD.GetFontSizeIndex(Settings.bLargerPickupTimers ? 1 : 0);

    C.SetOrigin(14.0, C.ClipY / 8);

    C.TextSize("000 ", FirstColumnSize, YL);

    for (i = 0; i < RespawnTimers.Length; i++) {
        flags = RespawnTimers[i].Flags;
        if (RespawnTimers[i].EstimatedRespawnTime < 0 && flags == 0) {
            // disabled, inactive, or something like that
            continue;
        }

 
    
        // add 1.0 because I want it to respawn when timer hits exactly zero
        SecondsLeft = (RespawnTimers[i].EstimatedRespawnTime - (WorldInfo.TimeSeconds - RI.ServerTimeDelta)) / WorldInfo.TimeDilation + 1.0;

        s = "";
        if ((flags & PICKUPTIMER_WAITINGFORMATCH) != 0) {
            // just don't display anything
        } else if ((flags & PICKUPTIMER_SCRIPTACTIVATED) != 0) {
            // same for now
        } else if ((flags & PICKUPTIMER_WAITINGFORDEPLOYABLE) != 0) {
            s $= "W";
        } else {
           s = (SecondsLeft <= 0 ? "+" : string(SecondsLeft)); 
        }

        s = s $ "  ";
        
        C.TextSize(s, XL, YL);
        
        if (LP.GetActorVisibility(RespawnTimers[i].PickupFactory)) {
            C.DrawColor = VisibleColor;
        } else {
            C.DrawColor = HiddenColor;
        }

        C.CurX = FirstColumnSize - XL;
        DrawTextClippedWithShadow(C, s);

        C.CurX = FirstColumnSize;
        DrawTextClippedWithShadow(C, RespawnTimers[i].PickupName);
        C.CurY += YL;
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

final function DrawTextClippedWithShadow(Canvas C, string S, float Offset=2.0) {    
    local Color SavedColor;

    Offset = Offset * UTHUD(myHUD).ResolutionScale;

    SavedColor = C.DrawColor;
    
    C.CurX = C.CurX + Offset;
    C.CurY = C.CurY + Offset;
    C.SetDrawColor(0, 0, 0);
    C.DrawTextClipped(s);
    
    C.CurX = C.CurX - Offset;
    C.CurY = C.CurY - Offset;
    C.DrawColor = SavedColor;
    C.DrawTextClipped(s);
}   

function RenderNowViewing(Canvas C) {
    local PlayerReplicationInfo TargetPRI;
    local float XL, YL;
    local string s;

    if (bBehindView) {
        // in third person mode, game already handles that
        // see UTHUD::DrawGameHud
        return;
    }

    TargetPRI = RealViewTarget;

    if (TargetPRI == None) return;

    C.Reset();
    C.SetOrigin(C.ClipX - 20.0, C.ClipY / 5.0 * 3.0);
    C.Font = myHUD.GetFontSizeIndex(2);
    C.SetDrawColor(255, 255, 0);

    s = "Now viewing";
    C.TextSize(s, XL, YL);
    C.CurX = -XL;
    DrawTextClippedWithShadow(C, s);

    C.CurY += YL;

    C.Font = myHUD.GetFontSizeIndex(3);
    s = TargetPRI.GetPlayerAlias();
    if (UTPlayerReplicationInfo(TargetPRI) != None && UTPlayerReplicationInfo(TargetPRI).ClanTag != "") {
        s = "[" $ UTPlayerReplicationInfo(TargetPRI).ClanTag $ "]" $ s;
    }
    C.TextSize(s, XL, YL);
    C.CurX = -XL;
    DrawTextClippedWithShadow(C, s);
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
            ClientMessage("Bookmark" @ Key @ "is not set. Press" @ Settings.BookmarkModifierButton $ "+" $ Key @ "to set it.");
        }
    }
}

function ZoomButtonReset()
{
    ResetFOV();
}

function bool OpenManual() {
    local GameUISceneClient SC;
    local UIScene UIS;
    
    SC = class'UIRoot'.static.GetSceneClient();
    if (SC != None && !SC.IsUIActive(0x00000020)) {
        UIS = UIScene(DynamicLoadObject(class.GetPackageName() $ ".SpectatorUI_Content.ShortManual", class'UIScene'));
        UIS.OnSceneActivated = static.OnShortManualActivated;
        if (UIS != None && SC.OpenScene(UIS)) {
            ShortManualRef = UIS;
            return true;
        }
    }

    return false;
}

static function OnShortManualActivated(UIScene UIS, bool bInitialActivation) {
    if (bInitialActivation) {
        UILabel(UIS.FindChild('ManualLabel', true)).SetValue(
            "Number row - camera speed control\n" $
            "LeftAlt + NumPad0-9 - save bookmark (camera position)\n" $
            "NumPad0-9 - load bookmark\n" $
            "Middle mouse button + mouse - zoom (field of view) [double click to reset]\n" $
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

function SettingsUpdated() {
    if (RI.Settings.bEnableBecomeSpectator) {
        Interactions.InsertItem(0, new(self) class'SpectatorUI_Interaction_Spectate');
        Spawn(class'SpectatorUI_MidgameMenuFixer', Outer);    
    }
}

// extract human-readable pickup name on the client
function string GetPickupName(class<Actor> Clazz) {
    local class<UTItemPickupFactory> IPFClass;
    local class<Inventory> InvClass;
    local string Res;

    if (Settings.LookupCustomPickupName(Clazz.GetPackageName() $ "." $ Clazz.Name, Res)) {
        return Res; 
    }

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

function UpdateRespawnTime(PickupFactory F, class<Actor> Clazz, int i, float ExpectedTime, int flags) {
    local string PickupName;
    while (RespawnTimers.Length - 1 < i) {
        RespawnTimers.Length = RespawnTimers.Length + 1;
        RespawnTimers[RespawnTimers.Length - 1].EstimatedRespawnTime = -1;
    }

    PickupName = GetPickupName(Clazz);

    //`log("Updated pickup timer" @ PickupName @ ExpectedTime);

    RespawnTimers[i].PickupFactory = F;
    RespawnTimers[i].PickupName = PickupName;
    RespawnTimers[i].EstimatedRespawnTime = ExpectedTime;
    RespawnTimers[i].Flags = flags;
}

function bool ShouldFollowPickup(class<Actor> What) {
    if (!bFollowPowerup) return false;

    // ignore armor and (super-)health
    if (class<UTArmorPickupFactory>(What) != None || class<UTHealthPickupFactory>(What) != None) return false;
    
    // everything else is fine
    return true;
}

function InterestingPickupTaken(PickupFactory F, class<Actor> What, PlayerReplicationInfo Who) {
    local string Desc;

    if (Settings.PickupNotificationPattern != "") {
        Desc = Settings.PickupNotificationPattern;
    } else {
        Desc = "`o has been picked up by `s.";
        if (!bFollowPowerup) {
            Desc = Desc @ "Press * to jump to that player.";
        }
    }

    Desc = Repl(Desc, "`o", GetPickupName(What));
    Desc = Repl(Desc, "`s", Who.GetPlayerAlias());

    if (ShouldFollowPickup(What)) {
        RI.ViewPointOfInterest(); 
    }
    
    PrintNotification(Desc);
}

function FlagEvent(UTCarriedObject Flag, name EventType, PlayerReplicationInfo Who) {
    local string Verb, Desc, Object;
    local byte Team;

    Team = Flag.GetTeamNum();

    Desc = Who.GetPlayerAlias();

    switch (EventType) {
        case 'Taken': 
            Verb = "taken"; 
            break;
        case 'Captured': 
            if (UTOnslaughtFlag(Flag) != None) {
                Verb = "captured node";
            } else {
                Verb = "captured";
            }
            break;
        case 'Returned':
            Verb = "returned";
            break;
        case 'Dropped':
            Verb = "dropped";
            break;
        default:
            Verb = "did something";
            break;
    }

    if (Team == 0) {
        Object = "Red";
    } else {
        Object = "Blue";
    }
    if (UTOnslaughtFlag(Flag) != None) {
        Object = Object @ "orb";
    } else {
        Object = Object @ "flag";
    }
    
    Desc = Object @ Verb;
    if (Who != None) {
        Desc = Desc @ "(by " $ Who.GetPlayerAlias() $ ")";
    }
    Desc = Desc $ ".";
    if (!bFollowPowerup) {
        Desc = Desc @ "Press * to jump to the objective.";
    }

    if (bFollowPowerup) {
        RI.ViewPointOfInterest();
    }

    PrintNotification(Desc);
}

function PrintNotification(string Message) {
    local bool bOldBeep;
    bOldBeep = myHUD.bMessageBeep;
    if (!Settings.bNotificationBeep) {
        myHUD.bMessageBeep = false;
    }
    ClientMessage(Message);
    if (!Settings.bNotificationBeep) {
        myHUD.bMessageBeep = bOldBeep;
    }
}

function bool IsKeyDoubleclicked(name Key, EInputEvent EventType)
{
    local bool bIsDoubleclick;

    // RealTimeSeconds as TimeSeconds is dilated therefore Doublelick would be different
    bIsDoubleclick = EventType == IE_DoubleClick;
    if (!bIsDoubleclick && WorldInfo.RealTimeSeconds - LastDoubleclickCheck < class'PlayerInput'.default.DoubleClickTime)
    {
        bIsDoubleclick = LastDoubleclickButton == Key;
    }

    LastDoubleclickCheck = WorldInfo.RealTimeSeconds;
    LastDoubleclickButton = Key;
    return bIsDoubleclick;
}

defaultproperties
{
    OnReceivedNativeInputKey=HandleInputKey
    OnReceivedNativeInputAxis=HandleInptAxis

    SelectedPrefix=">  "


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
