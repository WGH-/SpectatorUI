class SeqAct_Delegate extends SequenceAction;

var array<Object> Args;

event Activated() {
    OnActivated(self);
}

delegate OnActivated(SeqAct_Delegate X);

defaultproperties
{
    bCallHandler=false
}
