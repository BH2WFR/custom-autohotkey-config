; 热键诊断信息的格式化与显示。
class HotkeyDiagnostics {
    __New(tooltip) {
        this.Tooltip := tooltip
    }

    ShowContext(context) {
        newline := Chr(10)
        text := "Caps+" context.Key " | passthrough"
            . newline "Window: " context.Title
            . newline "Process: " context.Process " | HWND: " Format("0x{:X}", context.Hwnd)
            . newline "Triggers: " this.Join(context.Triggers)
            . newline "Modifiers (layer): " this.ModifierNames(context.Modifiers)
            . newline "Modifiers (logical): " this.ModifierNames(context.LogicalModifiers)
            . newline "Layer: " context.Layer " (snapshot; passthrough ignores layer)"
        this.Tooltip.Show(text)
    }

    ShowLayer(context) {
        this.Tooltip.Show("Caps+2 | Layer " context.Layer
            . Chr(10) "Modifiers: " this.ModifierNames(context.Modifiers)
            . Chr(10) "Triggers: " this.Join(context.Triggers))
    }

    ModifierNames(modifiers) {
        names := []
        for key, down in modifiers {
            if down
                names.Push(key)
        }
        return this.Join(names)
    }

    Join(items) {
        text := ""
        for item in items
            text .= (text == "" ? "" : " + ") item
        return text == "" ? "(none)" : text
    }
}
