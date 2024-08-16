#include "CAS_maths.sqf";
#include "CAS_tasking.sqf";

casLoop = {
	private _activeTasks = 0;
	private _taskID = "";
	private _group = _this select 0;
	private _targetGroup = objNull;
	private _isAlive = true;

	while { _isAlive } do {
		_isAlive = units _group findIf {
			alive _x
		} > -1;

		if (!_isAlive) exitWith {
			if (_activeTasks > 0) then {
				[_group, _taskID, "FAILED"] call updateCASTaskStatus;
			};
		};

		if (activeGlobalTasks < maxGlobalTasks) then {
			_targetGroup = [_group] call detectTargetGroup;

			if (!isNull _targetGroup) then {
				_lastTaskTime = _group getVariable ["timeTaskEnded", -newGroupTaskCooldown];

				_chanceData = [_group] call calcSurvivalChance;
				private _forceDiff = _chanceData select 0;
				private _friendCount = _chanceData select 1;
				private _groupsDistance = leader _group distance leader _targetGroup;

				if (_activeTasks < maxTasksPerUnit &&
				_forceDiff >= maxForceDiff &&
				_groupsDistance < maxGroupDistance &&
				_groupsDistance >= minGroupDistance &&
				_friendCount >= minFriendCount &&
				_lastTaskTime + newGroupTaskCooldown <= time) then {
					_activeTasks = _activeTasks + 1;
					activeGlobalTasks = activeGlobalTasks + 1;
					_taskID = [_group, _targetGroup] call callCAS;
					_group setVariable ["taskID", _taskID];
				};

				if (_activeTasks > 0) then {
					if (_forceDiff < maxForceDiff) then {
						_activeTasks = _activeTasks - 1;
						[_group, _taskID, "SUCCEEDED"] call updateCASTaskStatus;
					} else {
						if (_groupsDistance > maxGroupDistance) then {
							_activeTasks = _activeTasks - 1;
							[_group, _taskID, "CANCELED"] call updateCASTaskStatus;
						};
					};
				};
			} else {
				if (_activeTasks > 0) then {
					_activeTasks = _activeTasks - 1;
					[_group, _taskID, "SUCCEEDED"] call updateCASTaskStatus;
				};
			};
		};

		sleep ([4, 8] call BIS_fnc_randomInt);
	};
};