class SpectatorUI_Mut extends Mutator;

function PostBeginPlay() {
    super.PostBeginPlay();
    Spawn(class'SpectatorUI_ReplicationInfo');
    Destroy(); // job's done, destroying
}
