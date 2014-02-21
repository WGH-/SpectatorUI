class SeqEvent_PickupStatusChange_Delegate extends SeqEvent_PickupStatusChange;

event Activated() {
    OnActivated(PickupFactory(Originator), Pawn(Instigator));
}

delegate OnActivated(PickupFactory ThisFactory, Pawn EventInstigator);
