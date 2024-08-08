_aircraft = plane;
_magazines = magazines _aircraft;
_weapons = weapons _aircraft;
munitionCount = createHashMap;

// Function to determine munition type
getMunitionType = {
	params ["_munition"];
	private _config = configFile >> "CfgMagazines" >> _munition;
	private _ammoType = getText (_config >> "ammo");

	private _ammoConfig = configFile >> "CfgAmmo" >> _ammoType;
	private _isGuided = getNumber (_ammoConfig >> "manualControl") == 1 || getNumber (_ammoConfig >> "weaponLockSystem") > 0;

	if (getNumber (_ammoConfig >> "hit") > 500) then {
		if (_isGuided) then {
			"Guided Bomb";
		} else {
			"Unguided Bomb";
		};
	} else {
		private _munitionType = getText (_ammoConfig >> "simulation");
		switch (_munitionType) do {
			case "shotMissile": {
				if (_isGuided) then {
					"Guided Rocket";
				} else {
					"Unguided Rocket";
				};
			};
			case "shotRocket": {
				"Unguided Rocket";
			};
			case "shotBullet": {
				"Gun";
			};
			default {
				"Unknown";
			};
		};
	};
};

// Iterate through each magazine and count the categorized types
{
	private _munitionType = [_x] call getMunitionType;
	if ((munitionCount getOrDefault [_munitionType, ""]) isEqualTo "") then {
		munitionCount set [_munitionType, 1];
	} else {
		munitionCount set [_munitionType, (munitionCount get _munitionType) + 1];
	};
} forEach _magazines;

// format the output string
private _output = "Aircraft Payload Information:\n\n";
_output = _output + format ["Weapons:\n%1\n\n", _weapons];

_output = _output + "Munitions:\n";
{
	_output = _output + format ["%1: %2\n", _x, munitionCount get _x];
} forEach (keys munitionCount);

hint _output;