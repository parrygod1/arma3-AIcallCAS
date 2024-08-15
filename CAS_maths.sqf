#include "utils.sqf";

determineMunitions = {
	params ["_group", "_targetGroup"];

	private _unit = leader _group;
	private _nearestEnemy = _unit findNearestEnemy _unit;
	private _distanceToEnemy = _unit distance _nearestEnemy;
	private _enemyUnit = leader _targetGroup;

	private _nearbyVehicles = nearestObjects [_enemyUnit, ["Car", "Tank", "Wheeled_APC_F", "IFV", "TrackedAPC", "WheeledAPC"], 500];
	private _nearbyBuildings = nearestObjects [_enemyUnit, ["House"], 50];

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

	private _targetList = [leader _group nearTargets 500, _group] call getSortedEnemies;
	private _targetGroup = [];

	{
		_targetGroup pushBack (_x select 4);
	} forEach _targetList;

	private _survivalChance = 100;
	private _noAmmoUnitsCount = 0;
	private _lowHealthUnitsCount = 0;

	private _friendGroupCars = 0;
	private _friendGroupAPCs = 0;
	private _friendGroupTanks = 0;

	private _enemyGroupCars = 0;
	private _enemyGroupAPCs = 0;
	private _enemyGroupTanks = 0;

	private _friendGroupMen = 0;
	private _enemyGroupMen = 0;

	{
		if (alive _x) then {
			if (damage _x > unitMaxDamage) then {
				_lowHealthUnitsCount = _lowHealthUnitsCount + 1;
			};
			if (!(someAmmo _x)) then {
				_noAmmoUnitsCount = _noAmmoUnitsCount + 1;
			};
			if (_x isKindOf "Man") then {
				_friendGroupMen = _friendGroupMen + 1;
			};
		};
	} forEach units _group;

	{
		if (alive _x) then {
			private _types = _x call BIS_fnc_objectType;

			if ("Car" in _types or "StaticWeapon" in _types) then {
				_friendGroupCars = _friendGroupCars + 1;
				continue;
			};
			if ("WheeledAPC" in _types or "TrackedAPC" in _types or "IFV" in _types) then {
				_friendGroupAPCs = _friendGroupAPCs + 1;
				continue;
			};
			if ("Tank" in _types) then {
				_friendGroupTanks = _friendGroupTanks + 1;
				continue;
			};
		};
	} forEach ([_group, true] call BIS_fnc_groupVehicles);

	{
		if (alive _x) then {
			private _types = _x call BIS_fnc_objectType;

			if ("Infantry" in _types) then {
				_enemyGroupMen = _enemyGroupMen + 1;
				continue;
			};
			if ("Car" in _types or "StaticWeapon" in _types) then {
				_enemyGroupCars = _enemyGroupCars + 1;
				continue;
			};
			if ("WheeledAPC" in _types or "TrackedAPC" in _types or "IFV" in _types) then {
				_enemyGroupAPCs = _enemyGroupAPCs + 1;
				continue;
			};
			if ("Tank" in _types) then {
				_enemyGroupTanks = _enemyGroupTanks + 1;
				continue;
			};
		};
	} forEach _targetGroup;

	private _friendForceScore = (_friendGroupMen * 10 +
	_friendGroupCars * 30 +
	_friendGroupAPCs * 120 +
	_friendGroupTanks * 240) -
	_lowHealthUnitsCount * 5 -
	_noAmmoUnitsCount * 2;

	private _enemyForceScore = _enemyGroupMen * 10 +
	_enemyGroupCars * 30 +
	_enemyGroupAPCs * 120 +
	_enemyGroupTanks * 240;

	private _maxScore = _friendForceScore max _enemyForceScore;
	private _diffPercentage = 100 - 100 * _friendForceScore / _maxScore;

	_survivalChance = _diffPercentage;

	/*hint format ["
			friend force: %1 \n
			enemy force: %2 \n
			diff: %3 \n\n
			enemyMen: %4 \n
			enemyCars: %5 \n
			enemyAPC: %6 \n
			enemyTank: %7 \n", 
			_friendForceScore, 
			_enemyForceScore, 
			_survivalChance, 
			_enemyGroupMen, 
			_enemyGroupCars, 
			_enemyGroupAPCs, 
			_enemyGroupTanks
	];*/

	_friendCount = _friendGroupMen + _friendGroupCars + _friendGroupAPCs + _friendGroupTanks;

	[_survivalChance, _friendCount];
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

getSortedEnemies = {
	params ["_targetList", "_group"];

	_sortedList = [
		_targetList,
		[_group],
		{
			_x select 3 // Order by subjectiveCost
		}, "DESCEND", {
			// Is enemy and knows about group
			[side _input0, side (_x select 4)] call BIS_fnc_sideIsEnemy &&
			_input0 knowsAbout (_x select 4) > 0
		}
	] call BIS_fnc_sortBy;

	_sortedList;
};

detectTargetGroup = {
	params ["_group"];

	_targetList = leader _group nearTargets 500;
	_targetGroup = objNull;

	_sortedList = [_targetList, _group] call getSortedEnemies;

	if (count _sortedList > 0) then {
		_targetGroup = group ((_sortedList select 0) select 4);
	};

	_targetGroup;
};