class UTSeqEvent_OnslaughtNodeEvent_Delegate extends UTSeqEvent_OnslaughtNodeEvent;

function NotifyNodeChanged(Controller EventInstigator)
{
    `log(Originator @ "NodeChanged");
    // don't call super
    OnTrigger(UTOnslaughtNodeObjective(Originator), EventInstigator);
}

delegate OnTrigger(UTOnslaughtNodeObjective EventOriginator, Controller EventInstigator);
