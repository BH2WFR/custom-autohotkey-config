; 系统输入出口；清理不改变 CapsLock 锁定状态，也不释放鼠标按钮。
class KeyboardSender {
    static ModifierKeys := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"]

    static ReadModifiers(mode := "P") {
        result := Map()
        for key in this.ModifierKeys
            result[key] := mode == "" ? GetKeyState(key) : GetKeyState(key, mode)
        return result
    }

    Release(triggers) {
        keys := ""
        if GetKeyState("LAlt") || GetKeyState("RAlt") || GetKeyState("LWin") || GetKeyState("RWin")
            keys .= "{vkE8}"
        ; 已经抬起的键无需重复发送，避免 SendEvent 在每个冗余事件上等待。
        for key in KeyboardSender.ModifierKeys {
            if GetKeyState(key)
                keys .= "{" key " up}"
        }
        for key in triggers {
            if GetKeyState(key)
                keys .= "{" key " up}"
        }
        if keys != ""
            this.Send(keys)
    }

    ; Blind 防止发送后恢复已经强制松开的物理修饰键。
    Send(keys, *) => this._Send("{Blind}" keys)

    RestoreModifiers(modifiers) {
        keys := ""
        for key, down in modifiers {
            if down && GetKeyState(key, "P") && !GetKeyState(key)
                keys .= "{" key " down}"
        }
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
