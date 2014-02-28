class UTSeqEvent_FlagEvent_Delegate extends UTSeqEvent_FlagEvent;

function Trigger(name EventType, Controller EventInstigator)
{
    // don't call super
    OnTrigger(UTGameObjective(Originator), EventType, EventInstigator);
}

delegate OnTrigger(UTGameObjective EventOriginator, name EventType, Controller EventInstigator);
