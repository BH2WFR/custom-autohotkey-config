; Pass 保留修饰键，Layers 每层使用一个独立 Map。
class HotkeyBindings {
    static Register(registry, diagnostics, ime, openScreenKeyboard, anki, touchpad, wheel, sender, clipboard, text, mouse, pointer, windows, keys, paths, tools) {
        registry.Pass("q", ObjBindMethod(keys, "Send", "{Esc}", "Esc"))
        registry.Pass("\", ObjBindMethod(keys, "Send", "{vkE2sc056}", "ISO 反斜杠"))
        registry.Pass("u", ObjBindMethod(mouse, "Click", "LButton"))
        registry.Pass("o", ObjBindMethod(mouse, "Click", "RButton"))
        for key, direction in Map("i", [0, -1], "j", [-1, 0], "k", [0, 1], "l", [1, 0])
            registry.Pass(key, ObjBindMethod(pointer, "Move", direction[1], direction[2]))
        registry.Layers("``", Map(1, ObjBindMethod(keys, "Release")))
        registry.Once("e", Map(1, ObjBindMethod(paths, "Show")))
        registry.Once("w", Map(1, tools["windowInspector"]))
        registry.Once("y", Map(1, tools["textProcessor"]), Map(2, tools["unicodeInspector"]))
        registry.Layers("4", Map(1, ObjBindMethod(text, "Wrap")))
        registry.Once("5", Map(1, tools["solidMask"]), Map(2, tools["hollowMask"]))
        registry.Layers("6", Map(1, ObjBindMethod(text, "Case", false)), Map(2, ObjBindMethod(text, "Case", true)))
        registry.Layers("7", Map(1, ObjBindMethod(text, "TitleCase")))
        registry.Layers("Tab", Map(1, ObjBindMethod(text, "Indent", false)), Map(2, ObjBindMethod(text, "Indent", true)),
            Map(3, ObjBindMethod(text, "Insert", "`t")))
        registry.Layers("r", Map(1, ObjBindMethod(windows, "Center", false)), Map(2, ObjBindMethod(windows, "Center", true)))
        registry.Layers("a", Map(1, ObjBindMethod(keys, "ToggleLock", "CapsLock")), Map(2, ObjBindMethod(keys, "ToggleLock", "NumLock")))
        registry.Layers("d", Map(1, ObjBindMethod(windows, "ShowDesktop")), Map(2, ObjBindMethod(windows, "MinimizeOthers")))
        for key, cut in Map("x", true, "c", false)
            registry.Layers(key, Map(1, ObjBindMethod(clipboard, "Copy", cut, false, false)),
                Map(2, ObjBindMethod(clipboard, "Copy", cut, true, false)),
                Map(3, ObjBindMethod(clipboard, "Copy", cut, false, true)),
                Map(4, ObjBindMethod(clipboard, "Copy", cut, true, true)))
        registry.Layers("v", Map(1, ObjBindMethod(clipboard, "Paste", false, false)),
            Map(2, ObjBindMethod(clipboard, "Paste", true, false)),
            Map(3, ObjBindMethod(clipboard, "Paste", false, true)), Map(4, ObjBindMethod(clipboard, "Paste", true, true)))
        registry.Layers("z", Map(1, ObjBindMethod(clipboard, "Type", false)), Map(3, ObjBindMethod(clipboard, "Type", true)))
        registry.Layers("Space", Map(1, ObjBindMethod(sender, "Text", Chr(0xA0))), Map(2, ObjBindMethod(sender, "Text", Chr(0x3000))))
        registry.Layers("b", Map(1, ObjBindMethod(windows, "TogglePassThrough")), Map(2, ObjBindMethod(windows, "CycleOpacity")))
        registry.Layers(",", Map(1, ObjBindMethod(text, "LineEnding", ",", false)), Map(2, ObjBindMethod(text, "LineEnding", "\", true)))
        registry.Layers(";", Map(1, ObjBindMethod(text, "LineEnding", ";", false)), Map(2, ObjBindMethod(text, "LineEnding", ":", false)))
        registry.Layers("p", Map(1, ObjBindMethod(keys, "Send", "{Pause}", "Pause")), Map(2, ObjBindMethod(keys, "ToggleLock", "ScrollLock")))
        registry.Layers("Backspace", Map(1, ObjBindMethod(text, "DeleteFirstCharacter")), Map(2, ObjBindMethod(text, "DeleteLine")))
        registry.Layers("Enter", Map(1, ObjBindMethod(text, "NewLine", false)), Map(2, ObjBindMethod(text, "NewLine", true)),
            Map(3, ObjBindMethod(text, "Return", false)), Map(4, ObjBindMethod(text, "Return", true)))
        registry.Layers("t", Map(1, ObjBindMethod(windows, "ToggleTopmost")),
            Map(3, ObjBindMethod(text, "Accessor", false)), Map(4, ObjBindMethod(text, "Accessor", true)))
        registry.Pass("1", ObjBindMethod(diagnostics, "ShowContext"))
        registry.Layers("2",
            Map(1, ObjBindMethod(diagnostics, "ShowLayer")),
            Map(2, ObjBindMethod(diagnostics, "ShowLayer")),
            Map(3, ObjBindMethod(diagnostics, "ShowLayer")),
            Map(4, ObjBindMethod(diagnostics, "ShowLayer")))
        registry.Layers("-", Map(1, ObjBindMethod(touchpad, "Zoom", TouchpadActions.ZoomOut)), Map(2, ObjBindMethod(wheel, "Horizontal", true)))
        registry.Layers("=", Map(1, ObjBindMethod(touchpad, "Zoom", TouchpadActions.ZoomIn)), Map(2, ObjBindMethod(wheel, "Horizontal", false)))
        registry.Once("s", Map(1, openScreenKeyboard))
        registry.Layers(".", Map(1, ObjBindMethod(ime, "PrimaryMode")), Map(2, ObjBindMethod(ime, "SecondaryMode")))
        for key, up in Map("WheelUp", true, "WheelDown", false)
            registry.Layers(key, Map(1, ObjBindMethod(wheel, "CapsScroll", up)), Map(2, ObjBindMethod(wheel, "CapsScroll", up)))

        scope := registry.App(WindowGroups.Anki)
        scope.Layers("q", Map(1, ObjBindMethod(anki, "Clear")))
        for key, styles in Map("w", ["sz_large"], "e", ["bg_yl", "st_inv"], "r", ["bg_lm", "bg_cy"],
            "t", ["bg_cy"], "a", ["cl_gy", "cl_gn"], "s", ["cl_or", "cl_bl"],
            "d", ["fg_or", "fg_gy"], "f", ["fg_rd", "fg_bl"], "g", ["fg_gn", "fg_bl"]) {
            for layer, style in styles
                scope.Layers(key, Map(layer, ObjBindMethod(anki, "Send", style)))
        }
    }
}
