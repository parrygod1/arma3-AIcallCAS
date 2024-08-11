createSmoke = {
	params ["_position", "_color"];

	_smokeShellType = "SmokeShell_Infinite";

	switch (_color) do {
		case "red": {
			_smokeShellType = "SmokeShellRed_Infinite";
		};
		case "green": {
			_smokeShellType = "SmokeShellGreen_Infinite";
		};
		case "blue": {
			_smokeShellType = "SmokeShellBlue_Infinite";
		};
		case "yellow": {
			_smokeShellType = "SmokeShellYellow_Infinite";
		};
		case "purple": {
			_smokeShellType = "SmokeShellPurple_Infinite";
		};
		case "white": {
			_smokeShellType = "SmokeShellWhite_Infinite";
		};
		default {
			_smokeShellType = "SmokeShellGreen_Infinite";
		};
	};

	_smokeSource = _smokeShellType createVehicle _position;

	_smokeSource;
};

getMidPoint = {
	params ["_pos1", "_pos2"];

	_midPoint = [
		        ((_pos1 select 0) + (_pos2 select 0)) / 2, // X 
		        ((_pos1 select 1) + (_pos2 select 1)) / 2, // Y 
		        ((_pos1 select 2) + (_pos2 select 2)) / 2  // Z 
	];

	_midPoint
};