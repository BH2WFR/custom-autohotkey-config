; 系统输入出口；清理不改变 CapsLock 锁定状态，也不释放鼠标按钮。
class KeyboardSender {
    static ModifierKeys := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"]
    static MenuModifiers := Map("LAlt", true, "RAlt", true, "LWin", true, "RWin", true)
    static MenuMask := "{vkE8}"

    static ReadModifiers(mode := "P") {
        result := Map()
        for key in this.ModifierKeys
            result[key] := mode == "" ? GetKeyState(key) : GetKeyState(key, mode)
        return result
    }

    ReleaseModifiers() {
        keys := ""
        if GetKeyState("LAlt") || GetKeyState("RAlt") || GetKeyState("LWin") || GetKeyState("RWin")
            keys .= KeyboardSender.MenuMask
        ; 已经抬起的键无需重复发送，避免 SendEvent 在每个冗余事件上等待。
        for key in KeyboardSender.ModifierKeys {
            if GetKeyState(key)
                keys .= "{" key " up}"
        }
        if keys != ""
            this.Send(keys)
    }

    ; Blind 防止发送后恢复已经强制松开的物理修饰键。
    Send(keys, *) => this._Send("{Blind}" keys)

    ; 原生 Layer 接收实体键和 SendInput。动作临时松开按键后，实体键仍由钩子报告。
    static LayerModifiers() {
        result := Map()
        for key in this.ModifierKeys
            result[key] := GetKeyState(key, "P") || GetKeyState(key)
        return result
    }

    ; 注入键没有物理状态，仅在动作执行期间监听真实的抬起；I1 忽略本脚本的 I0 收尾事件。
    static WatchInjectedReleases(modifiers) {
        watch := false
        for key, down in modifiers {
            if !down || GetKeyState(key, "P")
                continue
            if !watch {
                watch := InputHook("V I1 L0")
                watch.Held := Map()
                watch.OnKeyUp := (hook, vk, sc) => hook.Held[vk] := false
            }
            watch.Held[GetKeyVK(key)] := true
            watch.KeyOpt("{" key "}", "N")
        }
        if watch
            watch.Start()
        return watch
    }

    RestoreModifiers(modifiers, watch := false) {
        keys := ""
        maskMenu := false
        for key, down in modifiers {
            if down && (GetKeyState(key, "P") || (watch && watch.Held.Get(GetKeyVK(key), false))) && !GetKeyState(key) {
                keys .= "{" key " down}"
                maskMenu := maskMenu || KeyboardSender.MenuModifiers.Has(key)
            }
        }
        ; 恢复按下后重新屏蔽，避免之后的物理抬起被当成单独 Alt/Win。
        if maskMenu
            keys .= KeyboardSender.MenuMask
        if keys != ""
            this.Send(keys)
    }

    Text(value, *) => this.Send("{Text}" value)

    ToggleLock(key, *) {
        state := !GetKeyState(key, "T")
        switch key {
            case "CapsLock": SetCapsLockState(state)
            case "NumLock": SetNumLockState(state)
            case "ScrollLock": SetScrollLockState(state)
        }
    }

    ; 普通快捷键临时调整修饰键，由 AHK 恢复仍被物理按住的修饰键。
    SendChord(keys) => this._Send(keys)

    _Send(keys) {
        previousLevel := A_SendLevel
        previousDelay := A_KeyDelay
        previousDuration := A_KeyDuration
        try {
            SendLevel(0)
            ; 0 让系统及时处理释放事件，避免回调读到尚未更新的逻辑状态。
            SetKeyDelay(0, -1)
            SendEvent(keys)
        } finally {
            SetKeyDelay(previousDelay, previousDuration)
            SendLevel(previousLevel)
        }
    }
}
