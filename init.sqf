#include "CAS_maths.sqf";
#include "CAS_tasking.sqf";
#include "CAS_drawing.sqf";
#include "CAS_loops.sqf";
test = "";

infantryGroups = [];
airVehicles = [];
pilots = [];

taskIDCounter = 0;

maxGlobalTasks = 3;
activeGlobalTasks = 0;

// min distance between tasks to allow creation of a new one
minTaskDistance = 500;

maxTasksPerUnit = 1;

// Percentage over which CAS will be called for a group
maxForceDiff = 40;

// damage for which a unit is considered low health
unitMaxDamage = 0.5;

// distance limit between friend group and enemy group
maxGroupDistance = 1000;
minGroupDistance = 50;

// Cooldown for group after a task is completed
newGroupTaskCooldown = 200;
dangerCloseDistance = 200;

// min number of units for which a group can call in CAS
// Prevent small units that might get killed very soon to call it in.
minFriendCount = 2;

CASside = west;

taskWaypointsMap = createHashMap;

{
	private _unit = _x;
	if (side _x == CASside && vehicle _x isKindOf "Air") then {
		airVehicles pushBack _unit;
	};
} forEach allUnits;

{
	private _vehicle = _x;

	_gunner = gunner _vehicle;
	_pilot = effectiveCommander _vehicle;

	pilots pushBack _pilot;
	pilots pushBack _gunner;
	pilots pushBack gunner _vehicle;

	[_pilot] call setupTaskEvent;
	[_gunner] call setupTaskEvent;
} forEach airVehicles;

[] call setupArrowDrawing;

handleCombatMode = {
	params ["_group", "_combatMode"];

	private _loopHandle = _group getVariable ["loopHandle", objNull];

	if (_combatMode isEqualTo "COMBAT" && isNull _loopHandle) then {
		private _handle = [_group] spawn casLoop;
		_group setVariable ["loopHandle", _handle];
	} else {
		if (!isNull _loopHandle) then {
			terminate _loopHandle;
			_group setVariable ["loopHandle", objNull];

			private _taskID = _group getVariable "taskID";
			if (!(_taskID isEqualTo "")) then {
				activeGlobalTasks = activeGlobalTasks - 1;
				[_taskID, "CANCELED"] call BIS_fnc_taskSetState;
				_group setVariable ["timeTaskEnded", time];
			};
		};
	};
};

while { true } do {
	{
		private _group = _x;

		if (!(_group in infantryGroups) && !isPlayer leader _group) then {
			if (side _group == CASside) then {
				private _isInfantryGroup = true;

				{
					if (_x isKindOf "Air") exitWith {
						_isInfantryGroup = false;
					};
				} forEach units _group;

				if (!_isInfantryGroup) exitWith {};

				infantryGroups pushBack _group;

				[_group, combatMode _group] call handleCombatMode;

				_group addEventHandler ["CombatModeChanged", {
					params ["_group", "_newMode"];

					[_group, _newMode] call handleCombatMode;
				}];
			};
		};
	} forEach allGroups;

	sleep ([10, 15] call BIS_fnc_randomInt);
};