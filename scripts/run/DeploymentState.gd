class_name DeploymentState
extends RefCounted

## True while you're placing your roster in your zone before a run match.
var active: bool = false

## The bench piece (roster id) picked up and waiting for a square, or -1.
var armed_id: int = -1

## The match to start once you press Start Match (see RunConfig.match_setup).
var setup: Dictionary = {}

func begin(new_setup: Dictionary) -> void:
	active = true
	armed_id = -1
	setup = new_setup

func finish() -> void:
	active = false
	armed_id = -1
