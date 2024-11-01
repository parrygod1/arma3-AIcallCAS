This is an unfinished concept that makes the AI call in CAS from player pilots via tasking. Works automatically on any editor placed or spawned AI infantry group. The player has to be already a pilot in a vehicle. There are variable settings in init.sqf.

Features:
- Task handling
- Task description with a 9-Line containing target description, location, desired payload
- Payload is determined by threat type and distance
- Custom logic to determine whether CAS is required. This is done by calculating a squads total force and survival chance against known targets
- Waypoints for IP, target and egress visible only when task is selected
- There are calculations done for the waypoints placement in order to prevent firing on friendlies
