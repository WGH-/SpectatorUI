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
var bool SelectionInProgress;
var config float PlayerSwitchDelay;

var config Name BookmarkModifierButton;
var bool BookmarkModifierButtonHeld;
var SpectatorUI_Bookmarks Bookmarks;
var array<Name> BookmarkKeys;

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
    // XXX change to IsInState('Spectating')?
    return IsSpectating();
}

event PostRender(Canvas Canvas) {
    local vector Loc, Dir;
    local rotator Rot;
    local UTHUD HUD;
    local Actor A;
    
    super.PostRender(Canvas);

    HUD = UTHUD(myHUD);
    if (HUD == None || !ShouldRender()) return;

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
        }
    }
    if (SelectionInProgress) {
        RenderPlayerList(Canvas);
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

    if (ShouldRender() && LocalPlayer(Player) != None && LocalPlayer(Player).ControllerId == ControllerId) {
        if (EventType ==  IE_Released) {
            i = SpeedBinds.Find('Key', Key);
            if (i != INDEX_NONE) {
                bRun = Speeds[SpeedBinds[i].Value];
            } else if (key == BookmarkModifierButton) {
                BookmarkModifierButtonHeld = false;
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
                }
            }
        } else if (EventType == IE_Pressed) {
            if (key == BookmarkModifierButton) {
                BookmarkModifierButtonHeld = true;
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

    if (!SelectionInProgress) {
        SelectionInProgress = true;
        PRIs.Length = 0;
        foreach UTHUD(myHUD).UTGRI.PRIArray(PRI) {
            if (IsValidSpectatorTarget(PRI)) {
                PRIs.AddItem(PRI);
                if (RealViewTarget == PRI) {
                    SelectedPRIIndex = PRIs.Length - 1;
                }
            }
        } 
    }
    if (PRIs.Length == 0) {
        SelectionInProgress = false;
        return;
    }
        
    SelectedPRIIndex = (SelectedPRIIndex + increment) mod PRIs.Length;
    SetTimer(PlayerSwitchDelay, false, 'EndPlayerSelect', self);
}

function EndPlayerSelect()
{
    SelectionInProgress = false;
    RI.ServerViewPlayer(PRIs[SelectedPRIIndex]);
    PRIs.Length = 0;
}

function RenderPlayerList(Canvas C)
{
    local UTHUD HUD;
    local PlayerReplicationInfo PRI;
    local string s;
    local int Index;
    local LinearColor LC;
    HUD = UTHUD(myHUD);
    if (HUD == None) return;
    
    C.Reset(true);
    C.SetPos(2.0, C.ClipY / 5);

    foreach PRIs(PRI, Index) {
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
        s = PRI.GetPlayerAlias();
        if (Index == SelectedPRIIndex) {
            s = s $ " <<<";
        }
        C.DrawText(s, true); 
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
        }
    }
}

defaultproperties
{
    OnReceivedNativeInputKey=HandleInputKey

    PlayerSwitchDelay=0.5
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
