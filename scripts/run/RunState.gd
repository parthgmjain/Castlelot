class_name RunState
extends RefCounted

## Everything that lasts across matches within one run. A lost match ends the
## run, which starts over with a fresh RunState.
var currency: int = 0
