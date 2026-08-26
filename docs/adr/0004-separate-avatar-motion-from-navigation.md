# Separate avatar motion from navigation

`AvatarMotionController` owns procedural full-avatar motion on a visual pivot, while `NavigableActor3D` owns physical movement and supplies only movement facts. This keeps Idle, Doing, Walking, Running, and Passive Body Motion presentational, prevents animation from moving collision or causing gameplay events, and lets later sprite or activity states replace a visual profile without changing navigation.

## Considered Options

- Putting bounce transforms on `NavigableActor3D` was rejected because it would mix visual state with navigation and could move collision, labels, shadows, or gameplay targets.
- Driving gait from measured velocity alone was rejected because Simulation Speed would turn Walking into Running and RVO slowdown would erase gameplay intent.
- Building separate first-pass clips for Walking and Running was rejected because one parameterized rigid-avatar cycle gives both named states independent profiles without duplicate motion logic.
