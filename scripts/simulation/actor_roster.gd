class_name ActorRoster
extends RefCounted

## Authored identity and display data. IDs are permanent, not roster positions.
const CULTIST_NAMES := {1: "Vera", 2: "Iris", 3: "Otto"}

const FULL_NIGHT_GROUP_DEFINITIONS: Array[Dictionary] = [
	{
		"id": &"arrival_group_pair_01",
		"label": "June + Mara",
		"arrival_at": 3.0,
		"patrons": [4, 5],
	},
	{
		"id": &"arrival_group_solo_01",
		"label": "Elias",
		"arrival_at": 93.0,
		"patrons": [6],
	},
	{
		"id": &"arrival_group_trio_01",
		"label": "Ruth + Walter + Nell",
		"arrival_at": 213.0,
		"patrons": [7, 8, 9],
	},
	{
		"id": &"arrival_group_pair_02",
		"label": "Vincent + Clara",
		"arrival_at": 333.0,
		"patrons": [10, 11],
	},
]
const FULL_NIGHT_PATRON_DEFINITIONS: Array[Dictionary] = [
	{
		"id": 4, "name": "June", "group_id": &"arrival_group_pair_01",
		"seed_key": &"patron_june",
		"companions": [5], "bladder_gain": 75.0, "service_delay": 9.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
	{
		"id": 5, "name": "Mara", "group_id": &"arrival_group_pair_01",
		"seed_key": &"patron_mara",
		"companions": [4], "bladder_gain": 45.0, "service_delay": 13.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
	{
		"id": 6, "name": "Elias", "group_id": &"arrival_group_solo_01",
		"seed_key": &"patron_elias",
		"companions": [], "bladder_gain": 60.0, "service_delay": 10.0,
		"victim_value": "Promising", "victim_risk": "Low", "friendship_capturable": true,
	},
	{
		"id": 7, "name": "Ruth", "group_id": &"arrival_group_trio_01",
		"seed_key": &"patron_ruth",
		"companions": [8, 9], "bladder_gain": 55.0,
		"service_delay": 9.0, "victim_value": "Ordinary", "victim_risk": "Medium",
	},
	{
		"id": 8, "name": "Walter", "group_id": &"arrival_group_trio_01",
		"seed_key": &"patron_walter",
		"companions": [7, 9], "bladder_gain": 70.0,
		"service_delay": 12.0, "victim_value": "Ordinary", "victim_risk": "Medium",
	},
	{
		"id": 9, "name": "Nell", "group_id": &"arrival_group_trio_01",
		"seed_key": &"patron_nell",
		"companions": [7, 8], "bladder_gain": 40.0,
		"service_delay": 15.0, "victim_value": "Ordinary", "victim_risk": "Medium",
	},
	{
		"id": 10, "name": "Vincent", "group_id": &"arrival_group_pair_02",
		"seed_key": &"patron_vincent",
		"companions": [11], "bladder_gain": 65.0, "service_delay": 11.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
	{
		"id": 11, "name": "Clara", "group_id": &"arrival_group_pair_02",
		"seed_key": &"patron_clara",
		"companions": [10], "bladder_gain": 50.0, "service_delay": 14.0,
		"victim_value": "Ordinary", "victim_risk": "Low",
	},
]

static func display_name(actor_id: int) -> String:
	if CULTIST_NAMES.has(actor_id):
		return CULTIST_NAMES[actor_id]
	for definition in FULL_NIGHT_PATRON_DEFINITIONS:
		if definition["id"] == actor_id:
			return definition["name"]
	return "Actor %d" % actor_id

static func kind(actor_id: int) -> StringName:
	if CULTIST_NAMES.has(actor_id):
		return &"cultist"
	for definition in FULL_NIGHT_PATRON_DEFINITIONS:
		if definition["id"] == actor_id:
			return &"patron"
	return &""
