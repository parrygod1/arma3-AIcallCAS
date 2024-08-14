#include "CAS_maths.sqf";
#include "CAS_tasking.sqf";
#include "CAS_drawing.sqf";
test = "";

infantryGroups = [];
airVehicles = [];
pilots = [];

taskIDCounter = 0;

maxTasksPerUnit = 1;

// Percentage under which CAS will be called for a group
minSurvivalChance = 70;

// damage for which a unit is considered low health
unitMaxDamage = 0.5;

// distance limit between friend group and enemy group
maxGroupDistance = 1000;
minGroupDistance = 50;

// Cooldown after a task is completed
newTaskCooldown = 200;
dangerCloseDistance = 200;

// min number of units for which a group can call in CAS
// Prevent small units that might get killed very soon to call it in.
minFriendCount = 5;

callCAS = {
	_callerGroup = _this select 0;
	_targetGroup = _this select 1;

	_aircraft = airVehicles select 0;
	_pilot = driver _aircraft;
	_targetPosition = getPos leader _targetGroup;
	_midPoint = [getPos leader _callerGroup, _targetPosition] call getMidPoint;

	_taskID = [_callerGroup, _targetGroup, _pilot] call handleCASTasking;

	taskIDCounter = taskIDCounter + 1;

	{
		_x setSuppression 1;
	} forEach units _callerGroup;

	_taskID;
};

casLoop = {
	private _activeTasks = 0;
	private _taskID = "";
	_group = _this select 0;
	_targetGroup = [_group] call detectTargetGroup;
	_isAlive = true;

	while { _isAlive } do {
		_isAlive = units _group findIf {
			alive _x
		} > -1;
		_lastTaskTime = _group getVariable ["timeTaskEnded", -newTaskCooldown];

		if (_isAlive) then {
			_chanceData = [_group] call calcSurvivalChance;
			_chance = _chanceData select 0;
			_friendCount = _chanceData select 1;
			_groupsDistance = leader (_group) distance leader (_targetGroup);

			_potentialGroup = [_group] call detectTargetGroup;
			if (!(isNull _potentialGroup)) then {
				_targetGroup = _potentialGroup;
			};

			if (_chance < minSurvivalChance &&
			_activeTasks < maxTasksPerUnit &&
			_groupsDistance < maxGroupDistance &&
			_groupsDistance >= minGroupDistance &&
			_friendCount >= minFriendCount &&
			_lastTaskTime + newTaskCooldown <= time) then {
				_activeTasks = _activeTasks + 1;
				_taskID = [_group, _targetGroup] call callCAS;
				_group setVariable ["taskID", _taskID];
			};

			if (_activeTasks > 0 && _chance > minSurvivalChance) then {
				_activeTasks = _activeTasks - 1;
				[_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
				_group setVariable ["taskID", ""];
				_group setVariable ["timeTaskEnded", time];
			};

			if (_activeTasks > 0 && _groupsDistance > maxGroupDistance) then {
				_activeTasks = _activeTasks - 1;
				[_taskID, "CANCELED"] call BIS_fnc_taskSetState;
				_group setVariable ["taskID", ""];
				_group setVariable ["timeTaskEnded", time];
			};

			sleep 5;
		};
	};

	if (_activeTasks > 0 && !_isAlive) then {
		[_taskID, "FAILED"] call BIS_fnc_taskSetState;
		_group setVariable ["taskID", ""];
		_group setVariable ["timeTaskEnded", time];
	};
};

{
	private _group = _x;

	if (side _group == side player) then {
		private _isInfantryGroup = true;
		{
			if (!(_x isKindOf "Man") || (vehicle _x isKindOf "Air")) exitWith {
				_isInfantryGroup = false;
			};
		} forEach units _group;

		if (_isInfantryGroup) then {
			infantryGroups pushBack _group;

			_group addEventHandler ["CombatModeChanged", {
				_group = _this select 0;
				_newMode = _this select 1;

				if (_newMode isEqualTo "COMBAT") then {
					_handle = [_group] spawn casLoop;
					_group setVariable ["loopHandle", _handle];
				} else {
					if (!(isNull (_group getVariable "loopHandle"))) then {
						terminate (_group getVariable "loopHandle");

						_taskID = _group getVariable "taskID";
						if (!(_taskID isEqualTo "")) then {
							[_taskID, "CANCELED"] call BIS_fnc_taskSetState;
							_group setVariable ["timeTaskEnded", time];
						};
					}
				};
			}];
		};
	};
} forEach allGroups;

{
	private _unit = _x;
	if (side _x == west && vehicle _x isKindOf "Air") then {
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

[] call drawOnMap;