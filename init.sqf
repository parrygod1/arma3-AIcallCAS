test = "";

infantryGroups = [];
airVehicles = [];

maxTasksPerUnit = 1;
minSurvivalChance = 70;
taskIDCounter = 0;
unitMaxDamage = 0.5;
maxGroupDistance = 1000;
minGroupDistance = 50;

callCAS = {
	_callerGroup = _this select 0;
	_targetGroup = _this select 1;

	_aircraft = airVehicles select 0;
	_pilot = driver _aircraft;

	private _targetPosition = getPos leader _targetGroup;

	private _taskID = format ["CAS%1", taskIDCounter];
	private _taskDescription = format ["CAS %1", groupId _callerGroup];
	private _taskDestination = _targetPosition;
	taskIDCounter = taskIDCounter + 1;

	[_pilot, _taskID, ["Provide CAS at the location", _taskDescription, _taskDescription], _taskDestination, 1, 2, true] call BIS_fnc_taskCreate;
	[_taskID, "ASSIGNED"] call BIS_fnc_taskSetState;

	_taskID;
};

calcSurvivalChance = {
	private _group = _this select 0;
	private _targetGroup = _this select 1;

	private _survivalChance = 100;
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

	hint format ["%1", _survivalChance];

	_survivalChance;
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

		if (_isAlive) then {
			_chance = [_group, _targetGroup] call calcSurvivalChance;
			_groupsDistance = leader (_group) distance leader (_targetGroup);

			if (!isNull (getAttackTarget (leader _group))) then {
				_targetGroup = group getAttackTarget (leader _group);
			};

			if (_chance < minSurvivalChance && _activeTasks < maxTasksPerUnit && _groupsDistance < maxGroupDistance && _groupsDistance >= minGroupDistance) then {
				_activeTasks = _activeTasks + 1;
				_taskID = [_group, _targetGroup] call callCAS;
				_group setVariable ["taskID", _taskID];
			};

			if (_activeTasks > 0 && _chance > minSurvivalChance) then {
				_activeTasks = _activeTasks - 1;
				[_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
				_group setVariable ["taskID", ""];
			};

			if (_activeTasks > 0 && _groupsDistance > maxGroupDistance) then {
				_activeTasks = _activeTasks - 1;
				[_taskID, "CANCELED"] call BIS_fnc_taskSetState;
				_group setVariable ["taskID", ""];
			};

			sleep 5;
		};
	};

	if (_activeTasks > 0 && !_isAlive) then {
		[_taskID, "FAILED"] call BIS_fnc_taskSetState;
		_group setVariable ["taskID", ""];
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
						};
					}
				};
			}];
		};
	};
} forEach allGroups;

{
	private _unit = _x;
	if (vehicle _x isKindOf "Plane") then {
		airVehicles pushBack _unit;
	};
} forEach allUnits;