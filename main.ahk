#Requires AutoHotkey v2.0
#SingleInstance Force

; 显式引用模块，由 App 组装。
#Include src/lib/json.ahk
#Include src/lib/config.ahk
#Include src/lib/python.ahk
#Include src/lib/keyboard.ahk
#Include src/lib/typing.ahk
#Include src/lib/clipboard.ahk
#Include src/lib/text.ahk
#Include src/lib/editing.ahk
#Include src/lib/window.ahk
#Include src/lib/ime.ahk
#Include src/lib/mouse.ahk
#Include src/lib/touchpad.ahk
#Include src/lib/window_geometry.ahk
#Include src/lib/window_automation.ahk
#Include src/utils/tooltip.ahk
#Include src/utils/console.ahk
#Include src/utils/filesystem.ahk
#Include src/core/settings.ahk
#Include src/core/startup.ahk
#Include src/rules/ime.ahk
#Include src/core/autorun.ahk
#Include src/core/session.ahk
#Include src/hotkeys/native.ahk
#Include src/hotkeys/layers.ahk
#Include src/hotkeys/registry.ahk
#Include src/hotkeys/dispatcher.ahk
#Include src/hotkeys/triggers.ahk
#Include src/hotkeys/keyboard_hook.ahk
#Include src/actions/diagnosis.ahk
#Include src/actions/screen_keyboard.ahk
#Include src/actions/settings.ahk
#Include src/actions/application.ahk
#Include src/actions/mouse.ahk
#Include src/actions/pointer.ahk
#Include src/actions/wheel.ahk
#Include src/actions/touchpad.ahk
#Include src/actions/middle_drag.ahk
#Include src/actions/xbuttons.ahk
#Include src/actions/window.ahk
#Include src/actions/clipboard.ahk
#Include src/actions/text.ahk
#Include src/actions/ime.ahk
#Include src/actions/joystick.ahk
#Include src/apps/anki.ahk
#Include src/apps/xbuttons.ahk
#Include src/apps/caj_viewer.ahk
#Include src/apps/power_iso.ahk
#Include src/rules/windows.ahk
#Include src/rules/editing.ahk
#Include src/rules/caps_policy.ahk
#Include src/rules/hotkeys.ahk
#Include src/rules/mouse.ahk
#Include src/rules/wheel.ahk
#Include src/rules/middle_drag.ahk
#Include src/rules/tray.ahk
#Include src/ui/tray.ahk
#Include src/core/app.ahk

Startup.RequireAdmin()
App.Start()
