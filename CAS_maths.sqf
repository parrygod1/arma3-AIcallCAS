#include "utils.sqf";

determineMunitions = {
	params ["_group", "_targetGroup"];

	private _unit = leader _group;
	private _nearestEnemy = _unit findNearestEnemy _unit;
	private _distanceToEnemy = _unit distance _nearestEnemy;
	private _enemyUnit = leader _targetGroup;

	private _nearbyVehicles = nearestObjects [_enemyUnit, ["Car", "Tank", "Wheeled_APC_F", "IFV"], 500];
	private _nearbyBuildings = nearestObjects [_enemyUnit, ["House"], 100];

	private _gunScore = 0;
	private _bombScore = 0;
	private _agmScore = 0;

	if (_distanceToEnemy <= dangerCloseDistance) then {
		_gunScore = _gunScore + 3;
	} else {
		if (_distanceToEnemy <= 650) then {
			_bombScore = _bombScore + 2;
			_gunScore = _gunScore + 1;
		} else {
			_agmScore = _agmScore + 3;
			_bombScore = _bombScore + 1;
		};
	};

	if (count _nearbyVehicles > 0) then {
		_agmScore = _agmScore + 2;
	};

	if (count _nearbyBuildings > 0) then {
		_bombScore = _bombScore + 2;
	};

	private _hint = "";
	if (_gunScore >= _bombScore && _gunScore >= _agmScore) then {
		_hint = "Gun";
	} else {
		if (_bombScore >= _gunScore && _bombScore >= _agmScore) then {
			_hint = "Bomb/Rockets";
		} else {
			_hint = "AGM";
		};
	};

	_hint;
};

calcSurvivalChance = {
	private _group = _this select 0;
	private _targetGroup = _this select 1;

	private _survivalChance = 0;
	private _noAmmoUnitsCount = 0;
	private _lowHealthUnitsCount = 0;
	private _friendGroupVehicles = 0;
	private _enemyGroupVehicles = 0;
	private _friendGroupMen = 0;
	private _enemyGroupMen = 0;

	{
		if (damage _x > unitMaxDamage) then {
			_lowHealthUnitsCount = _lowHealthUnitsCount + 1;
		};
		if (!(someAmmo _x)) then {
			_noAmmoUnitsCount = _noAmmoUnitsCount + 1;
		};

		if (_x isKindOf "Man") then {
			_friendGroupMen = _friendGroupMen + 1;
		};
	} forEach units _group;
	{
		if (_x isKindOf "Tank" or _x isKindOf "Wheeled_APC_F" or _x isKindOf "IFV" or _x isKindOf "StaticWeapon") then {
			_friendGroupVehicles = _friendGroupVehicles + 1;
		};
	} forEach ([_group, true] call BIS_fnc_groupVehicles);

	{
		if (_x isKindOf "Man") then {
			_enemyGroupMen = _enemyGroupMen + 1;
		};
	} forEach units _targetGroup;
	{
		if (_x isKindOf "Tank" or _x isKindOf "Wheeled_APC_F" or _x isKindOf "IFV" or _x isKindOf "StaticWeapon") then {
			_enemyGroupVehicles = _enemyGroupVehicles + 1;
		};
	} forEach ([_targetGroup, true] call BIS_fnc_groupVehicles);

	private _unitsDiff = _enemyGroupMen - _friendGroupMen;
	private _vehiclesDiff = _enemyGroupVehicles - _friendGroupVehicles;

	_survivalChance = _survivalChance - (_vehiclesDiff * 30);
	_survivalChance = _survivalChance - (_unitsDiff * 15);
	_survivalChance = _survivalChance - (_lowHealthUnitsCount * 10);
	_survivalChance = _survivalChance - (_noAmmoUnitsCount * 5);
	_survivalChance = _survivalChance max 0 min 100;

	// hint format ["%1", _survivalChance];

	_survivalChance;
};

calculateCASWaypoints = {
	params ["_callerGroup", "_targetPos", "_munitionsType"];

	_friendlyPos = position leader _callerGroup;
	_enemyPos = _targetPos;

	private _safeDistance = 1000; // Safe distance from friendly forces in meters
	private _offsetDistance = 500; // distance offset for IP and egress points
	private _egressAngleOffset = 45;

	// Vector from friendly to enemy
	private _attackVector = _enemyPos vectorFromTo _friendlyPos;

	// Normalize the attack vector (direction)
	private _attackDirection = vectorNormalized _attackVector;

	// Determine the Initial Point (IP) based on the munitions type
	private _ipDistance = switch (_munitionsType) do {
		case "Gun": {
			1500
		};
		case "Bomb/Rockets": {
			3000
		};
		case "AGM": {
			4000
		};
		default {
			3000
		};
	};

	// If it's a gun run, make the approach perpendicular to the attack vector
	_ipPos = [];
	if (_munitionsType == "Gun") then {
		_perpendicularVector = [_attackDirection select 1, - (_attackDirection select 0), 0];
		_ipPos = _enemyPos vectorAdd (_perpendicularVector vectorMultiply _ipDistance);
	} else {
		_ipPos = _enemyPos vectorAdd (_attackDirection vectorMultiply _ipDistance);
	};

	// Calculate the egress position
	_egressPos = [];
	if (_munitionsType == "Gun") then {
		// for a gun run, egress should also avoid flying over enemy lines
		private _egressDirection = [_attackDirection select 1, -(_attackDirection select 0), 0];
		_egressPos = _enemyPos vectorAdd (_egressDirection vectorMultiply _offsetDistance);
	} else {
		// for other munitions, offset egress direction by a certain angle to avoid overflying enemy
		private _egressAngle = _egressAngleOffset * (pi / 180); // Convert degrees to radians
		private _cosTheta = cos _egressAngle;
		private _sinTheta = sin _egressAngle;
		private _rotatedVector = [
			(_attackDirection select 0) * _cosTheta - (_attackDirection select 1) * _sinTheta,
			(_attackDirection select 0) * _sinTheta + (_attackDirection select 1) * _cosTheta,
			0
		];
		_egressPos = _enemyPos vectorAdd (_rotatedVector vectorMultiply _offsetDistance);
	};

	// Ensure IP and Egress points are not too close to friendly forces
	if (_ipPos distance _friendlyPos < _safeDistance) then {
		_ipPos = _friendlyPos vectorAdd (_attackDirection vectorMultiply _safeDistance);
	};
	if (_egressPos distance _friendlyPos < _safeDistance) then {
		_egressPos = _friendlyPos vectorAdd (_attackDirection vectorMultiply (-_safeDistance));
	};

	// Return the waypoints
	[_ipPos, _enemyPos, _egressPos];
};

createCASMarkers = {
	params ["_waypoints, _callerGroup"];
	_ipPos = _waypoints select 0;
	_targetPos = _waypoints select 1;
	_egressPos = _waypoints select 2;
	_friendPos = getPos leader _callerGroup;

	_markerTarget = createMarker [format ["par_CAS_TARGET_%1", taskIDCounter], _targetPosition];
	_markerTarget setMarkerType "mil_circle";
	_markerTarget setMarkerColor "Color3_FD_F";
	_markerTarget setMarkerText "TARGET";
	_markerTarget setMarkerAlphaLocal 0;

	_markerIP = createMarker [format ["par_CAS_IP_%1", taskIDCounter], _ipPos];
	_markerIP setMarkerType "mil_circle";
	_markerIP setMarkerColor "Color3_FD_F";
	_markerIP setMarkerText "IP";
	_markerIP setMarkerAlphaLocal 0;

	_markerEgress = createMarker [format ["par_CAS_EGRESS_%1", taskIDCounter], _egressPos];
	_markerEgress setMarkerType "mil_circle";
	_markerEgress setMarkerColor "Color3_FD_F";
	_markerEgress setMarkerText "EGRESS";
	_markerEgress setMarkerAlphaLocal 0;

	_markerFriend = createMarker [format ["par_CAS_FRIENDLIES_%1", taskIDCounter], _friendPos];
	_markerFriend setMarkerType "mil_box";
	_markerFriend setMarkerColor "ColorGreen";
	_markerFriend setMarkerText "FRIENDLY";
	_markerFriend setMarkerAlphaLocal 0;

	[_markerIP, _markerTarget, _markerEgress, _markerFriend];
};

drawOnMap = {
	waitUntil {
		!isNull findDisplay 12
	};

	_map = findDisplay 12 displayCtrl 51;
	_map ctrlAddEventHandler ["Draw", {
		_currentTask = player call BIS_fnc_taskCurrent;

		if ("par_CAS_Task" in _currentTask) then {
			_map = _this select 0;
			_waypoints = taskWaypointsMap get _currentTask;
			_ipPos = _waypoints select 0;
			_targetPos = _waypoints select 1;
			_egressPos = _waypoints select 2;

			_map drawArrow [
				_ipPos,
				_targetPos,
				[1, 0, 0, 1]
			];

			_map drawArrow [
				_targetPos,
				_egressPos,
				[1, 0, 0, 1]
			];
		};
	}];

	waitUntil {
		!isNull (uiNamespace getVariable ["RscCustomInfoMiniMap", displayNull])
	};

	private _display = uiNamespace getVariable ["RscCustomInfoMiniMap", displayNull];
	private _miniMapControlGroup = _display displayCtrl 13301;
	private _miniMap = _miniMapControlGroup controlsGroupCtrl 101;

	_miniMap ctrlAddEventHandler ["Draw", {
		_currentTask = player call BIS_fnc_taskCurrent;

		if ("par_CAS_Task" in _currentTask) then {
			_map = _this select 0;
			_waypoints = taskWaypointsMap get _currentTask;
			_ipPos = _waypoints select 0;
			_targetPos = _waypoints select 1;
			_egressPos = _waypoints select 2;

			_map drawArrow [
				_ipPos,
				_targetPos,
				[1, 0, 0, 1]
			];

			_map drawArrow [
				_targetPos,
				_egressPos,
				[1, 0, 0, 1]
			];
		};
	}];
};