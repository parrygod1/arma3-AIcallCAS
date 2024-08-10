#include "CAS_maths.sqf";

test = "";

infantryGroups = [];
airVehicles = [];

maxTasksPerUnit = 1;
minSurvivalChance = 70;
taskIDCounter = 0;
unitMaxDamage = 0.5;
maxGroupDistance = 1000;
minGroupDistance = 50;
newTaskCooldown = 200;

callCAS = {
	_callerGroup = _this select 0;
	_targetGroup = _this select 1;

	_aircraft = airVehicles select 0;
	_pilot = driver _aircraft;
	_targetPosition = getPos leader _targetGroup;

	_munitions = [_callerGroup, _targetGroup] call determineMunitions;
	_waypoints = [_callerGroup, _targetPosition, _munitions] call calculateCASWaypoints;
	_markers = [_waypoints, _callerGroup] call createCASMarkers;
	_taskID = [_callerGroup, _targetGroup, _pilot, _waypoints, _munitions] call createCASTask;

	[_waypoints] call drawOnMap;

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
	_targetGroup = group getAttackTarget (leader _group);
	_isAlive = true;

	while { _isAlive } do {
		_isAlive = units _group findIf {
			alive _x
		} > -1;
		_lastTaskTime = _group getVariable ["timeTaskEnded", -newTaskCooldown];

		if (_isAlive) then {
			_chance = [_group, _targetGroup] call calcSurvivalChance;
			_groupsDistance = leader (_group) distance leader (_targetGroup);

			if (!isNull (getAttackTarget (leader _group))) then {
				_targetGroup = group getAttackTarget (leader _group);
			};

			if (_chance < minSurvivalChance &&
			_activeTasks < maxTasksPerUnit &&
			_groupsDistance < maxGroupDistance &&
			_groupsDistance >= minGroupDistance &&
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
	if (vehicle _x isKindOf "Plane" or vehicle _x isKindOf "Helicopter") then {
		airVehicles pushBack _unit;
	};
} forEach allUnits;