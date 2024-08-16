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

setupArrowDrawing = {
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