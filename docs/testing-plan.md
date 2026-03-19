# Windows Testing Plan

## Scope
Validate Windows 10 and Windows 11 support for profile creation, isolated launch, switching, credential storage, tray behavior, shortcuts, and installer flows.

## Functional Tests
1. Install with `powershell -ExecutionPolicy Bypass -File .\install-windows.ps1`.
2. Set the IDE path with `multigravity config set-app "C:\Path\To\Antigravity.exe"`.
3. Create two profiles with different metadata:
   - `multigravity profile new work --theme=Dark --font-size=14 --extensions=ms-python.python`
   - `multigravity profile new client-a --theme=Light --font-size=16`
4. Store credentials for one profile with `multigravity credential set work`.
5. Launch both profiles and confirm separate settings, extension folders, and concurrent processes.
6. Run `multigravity switch work` and verify the existing window is activated instead of launching a duplicate.
7. Start `multigravity tray`, launch or activate profiles from the tray, and verify menu refresh.
8. Create a shortcut with `multigravity shortcut create work Ctrl+Alt+1` and confirm the shortcut launches the correct profile.

## Reliability Tests
1. Delete a running profile and verify the command removes stale instance records cleanly after the IDE exits.
2. Configure an invalid IDE path and confirm the CLI emits a clear error and writes to `%LOCALAPPDATA%\Multigravity\logs\multigravity.log`.
3. Remove `Antigravity.exe`, run `multigravity doctor`, and verify diagnostics remain readable.

## Resource Checks
1. Launch three profiles, record CPU and memory in Task Manager, and compare against a baseline direct IDE launch.
2. Confirm idle tray usage remains negligible and no polling loop exceeds the 5-second timer refresh interval.
