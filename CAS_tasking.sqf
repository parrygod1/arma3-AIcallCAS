#include "CAS_maths.sqf";
#include "utils.sqf";
#include "CAS_drawing.sqf";

// Calc chance of markers
getInfoFlags = {
	params [_callerGroup];

	_JTACNearby = 0;
	_maxChance = 101; // will be 100 because of random

	_waypointsChance = 30 + 60 * _JTACNearby;
	_doCreateWaypoints = random _maxChance <= _waypointsChance;

	_gridPosTgtChance = 10 + 60 * _JTACNearby;
	_showGridPosTgt = random _maxChance <= _gridPosTgtChance;

	_gridPosFriendlyChance = 60 + 40 * _JTACNearby;
	_showGridPosFriendly = random _maxChance <= _gridPosFriendlyChance;

	_smokeMarkTgtChance = 10 + 40 * _JTACNearby;
	_doSmokeMarkTgt = random _maxChance <= _smokeMarkTgtChance;

	_smokeMarkFriendlyChance = 70;
	_doSmokeMarkFriendly = random _maxChance <= _smokeMarkFriendlyChance;

	[_doCreateWaypoints, _showGridPosTgt, _showGridPosFriendly, _doSmokeMarkTgt, _doSmokeMarkFriendly];
};

getInfo = {
	params ["_infoFlags"];

	_doCreateWaypoints = _infoFlags select 0;
	_showGridPosTgt = _infoFlags select 1;
	_showGridPosFriendly = _infoFlags select 2;
	_doSmokeMarkTgt = _infoFlags select 3;
	_doSmokeMarkFriendly = _infoFlags select 4;
};

setupTaskEvent = {
	_pilot = _this select 0;

	_pilot addEventHandler ["TaskSetAsCurrent", {
		params ["_unit", "_task"];

		private _currentTask = _unit call BIS_fnc_taskCurrent;
		private _taskVar = _unit getVariable ["CAS_Task_ID", ""];

		private _setMarkerVisibility = {
			params ["_id", "_alpha"];

			private _markerTarget = format ["par_CAS_TARGET_%1", _id];
			private _markerIP = format ["par_CAS_IP_%1", _id];
			private _markerEgress = format ["par_CAS_EGRESS_%1", _id];
			private _markerFriend = format ["par_CAS_FRIENDLIES_%1", _id];

			{
				_x setMarkerAlphaLocal _alpha;
			} forEach [_markerTarget, _markerIP, _markerEgress, _markerFriend];
		};

		// Check for CAS task unassignment
		if ("par_CAS_Task" in _taskVar && !(_currentTask isEqualTo _taskVar)) then {
			private _id = (_taskVar splitString "_") select 3;
			_unit setVariable ["CAS_Task_ID", ""];
			[_id, 0] call _setMarkerVisibility;
		};

		// Check for CAS task assignment
		if ("par_CAS_Task" in _currentTask) then {
			private _id = (_currentTask splitString "_") select 3;
			_unit setVariable ["CAS_Task_ID", _currentTask];
			[_id, 1] call _setMarkerVisibility;
		};
	}];
};

createCASTask = {
	params ["_callerGroup", "_targetGroup", "_waypoints", "_munitions", "_markers"];

	private _targetPosition = getPos leader _targetGroup;
	private _friendlyPosition = getPos leader _callerGroup;
	private _taskDestination = _targetPosition;

	_targetElevation = (getPosASL leader _targetGroup) select 2;

	_ipPos = mapGridPosition (_waypoints select 0);
	_egressPos = mapGridPosition (_waypoints select 2);

	_distance = (_waypoints select 0) distance (_waypoints select 1);
	_gridPosTgt = mapGridPosition _targetPosition;
	_gridPosFriendly = mapGridPosition _friendlyPosition;
	_heading = (_waypoints select 0) getDir (_waypoints select 1);

	_dangerClose = _targetPosition distance _friendlyPosition <= dangerCloseDistance;

	_details = format [
		"
		9-LINE: <br/><br/>
		IP: <marker name='par_CAS_IP_%12'>%1</marker><br />
		HEADING: %2<br />
		distance: %3<br />
		TGT ELEVATION: %4<br />
		TGT DESCRIPTION: %5<br />
		TGT LOCATION: <marker name='par_CAS_TARGET_%12'>%6</marker> <br />
		MARK: %7<br />
		FRIENDLIES: <marker name='par_CAS_FRIENDLIES_%12'>%8</marker><br />
		EGRESS: <marker name='par_CAS_EGRESS_%12'>%9</marker><br />
		REMARKS:<br />
		<p> DANGER CLOSE: %10</p><br />
		<p> ORDANANCE: %11</p>",
		_ipPos,
		_heading,
		_distance,
		_targetElevation,
		"NONE",
		_gridPosTgt,
		"NONE",
		_gridPosFriendly,
		_egressPos,
		_dangerClose,
		_munitions,
		taskIDCounter
	];

	_details;
};

taskWaypointsMap = createHashMap;

handleCASTasking = {
	params ["_callerGroup", "_targetGroup", "_pilot"];

	private _taskID = format ["par_CAS_Task_%1", taskIDCounter];
	private _taskDescription = format ["CAS %1", groupId _callerGroup];
	private _targetPosition = getPos leader _targetGroup;
	private _taskDestination = _targetPosition;

	_munitions = [_callerGroup, _targetGroup] call determineMunitions;
	/*_infoFlags = [_callerGroup] call getInfoFlags;
		
		_doCreateWaypoints = _infoFlags select 0;
		_doSmokeMarkTgt = _infoFlags select 3;
	_doSmokeMarkFriendly = _infoFlags select 4;*/

	_waypoints = [];
	_markers = [];

	_waypoints = [_callerGroup, _targetPosition, _munitions] call calculateCASWaypoints;
	_markers = [_waypoints, _callerGroup] call createCASMarkers;

	/*if (_doSmokeMarkTgt) then {
			[_targetPosition, "red"] call createSmoke;
		}
		
		if (_doSmokeMarkFriendly) then {
			[getPos leader _callerGroup, "blue"] call createSmoke;
	}*/

	_details = [_callerGroup, _targetGroup, _waypoints, _munitions, _markers] call createCASTask;

	// [_midPoint, "green"] call createSmoke;
	// [_waypoints] call drawOnMap;

	taskWaypointsMap set [_taskID, _waypoints];

	{
		_doNotify = false;
		if (_x call BIS_fnc_taskCurrent isEqualTo "") then {
			_doNotify = true;
		};
		[_x, _taskID, [_details, _taskDescription, _taskDescription], _taskDestination, "CREATED", 2, _doNotify] call BIS_fnc_taskCreate;
	} forEach pilots;

	_taskID;
};