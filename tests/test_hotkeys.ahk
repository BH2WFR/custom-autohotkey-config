#Requires AutoHotkey v2.0
#Include ../src/hotkeys/layers.ahk
#Include ../src/hotkeys/registry.ahk
#Include ../src/hotkeys/dispatcher.ahk
#Include ../src/lib/keyboard.ahk
#Include ../src/lib/window_geometry.ahk
#Include ../src/lib/window.ahk
#Include ../src/actions/window.ahk
#Include ../src/lib/touchpad.ahk
#Include ../src/actions/touchpad.ahk
#Include ../src/hotkeys/native.ahk
#Include ../src/hotkeys/triggers.ahk
#Include ../src/hotkeys/keyboard_hook.ahk
#Include ../src/rules/hotkeys.ahk
#Include ../src/rules/windows.ahk
#Include ../src/actions/diagnosis.ahk
#Include ../src/utils/tooltip.ahk

try {
    HotkeyTests.Run()
    ExitApp(0)
} catch as err {
    FileAppend(err.Message Chr(10) err.Stack Chr(10), "**", "UTF-8")
    ExitApp(1)
}

class HotkeyTests {
    static Count := 0

    class FakeSender {
        __New() {
            this.Calls := 0
            this.Triggers := []
            this.Restores := 0
        }
        Release(triggers) {
            this.Calls++
            this.Triggers := triggers.Clone()
        }
        RestoreModifiers(modifiers) => this.Restores++
    }

    class Display {
        Show(text) => this.Text := text
    }

    class FakeActions {
        __Call(name, args) => 0
        PrimaryMode(*) => 0
        SecondaryMode(*) => 0
        Open(*) => 0
        Clear(*) => 0
        Send(*) => 0
        Zoom(*) => 0
        Horizontal(*) => 0
        CapsScroll(*) => 0
    }

    static Assert(value, message) {
        this.Count++
        if !value
            throw Error(message)
    }

    static Throws(callback, message) {
        try callback()
        catch as err {
            if err is UnsetError
                throw err
            return this.Assert(true, message)
        }
        this.Assert(false, message)
    }

    static Reset() {
        this.State := LayerState()
        this.Sender := this.FakeSender()
        this.Registry := HotkeyRegistry(ObjBindMethod(this, "Matches"))
        this.Dispatcher := HotkeyDispatcher(this.State, this.Registry, this.Sender)
        this.Events := []
    }

    static Matches(scope, hwnd) => scope == "anki" && hwnd == 7
    static Action(context) => this.Events.Push(context)

    static CleanAction(context) {
        this.Assert(this.State.Phase == "Spent", "回调前已经结束本次层")
        this.Assert(this.Sender.Calls == 1, "回调前已经释放按键")
        this.Events.Push(context)
    }

    static FailAction(context) {
        throw Error("测试动作异常")
    }

    static Context(modifiers := unset, hwnd := 0) {
        return HotkeyContext("2", IsSet(modifiers) ? modifiers : Map(), this.State.Triggers(), hwnd)
    }

    static Run() {
        this.Assert(KeyboardSender.ReadModifiers().Count == 8, "读取八个物理修饰键")
        this.Assert(KeyboardSender.ReadModifiers("").Count == 8, "读取八个逻辑修饰键时省略 GetKeyState 模式参数")
        this.LayersAndAliases()
        this.SparseBindings()
        this.MixedLayerModes()
        this.Passthrough()
        this.Repeated()
        this.ApplicationRules()
        this.FailureCleanup()
        this.Diagnostics()
        FileAppend("PASS: " this.Count " hotkey assertions" Chr(10), "*", "UTF-8")
    }

    static LayersAndAliases() {
        for modifiers in [Map(), Map("LShift", 1), Map("RAlt", 1), Map("RShift", 1, "LAlt", 1)] {
            this.Reset()
            expected := A_Index
            this.Registry.Once("2",
                Map(1, ObjBindMethod(this, "CleanAction")), Map(2, ObjBindMethod(this, "CleanAction")),
                Map(3, ObjBindMethod(this, "CleanAction")), Map(4, ObjBindMethod(this, "CleanAction")))
            this.State.AliasDown("F6")
            this.State.AliasDown("F6")
            this.State.AliasDown("CapsLock")
            this.Assert(this.State.Held.Count == 2, "别名自动重复不重复计数")
            context := this.Context(modifiers)
            this.Assert(context.Layer == expected, "Alt/Shift 层号计算")
            this.Assert(this.Dispatcher.Dispatch("2", context), "执行对应层")
            this.Assert(this.Events[1].Layer == expected, "保留释放前的层快照")
            this.Assert(this.Sender.Triggers.Length == 2, "释放所有本次触发键")
            this.Assert(!this.Dispatcher.Dispatch("2", context), "重复事件不再执行")
            for key in modifiers
                this.Assert(this.State.Captured.Has(key), "按住的修饰键等待物理松开")
            this.State.AliasUp("F6")
            this.Assert(this.State.Phase == "Spent", "只松开一个别名不重新激活")
            this.State.AliasDown("F1")
            this.Assert(this.State.Phase == "Spent", "已消费时按另一别名不能重开")
            this.State.AliasUp("CapsLock")
            this.State.AliasUp("F1")
            this.Assert(this.State.Phase == "Idle", "所有别名松开后回到 Idle")
            this.Assert(this.State.Captured.Has("2"), "先松开别名仍保留功能键收尾")
            this.State.KeyUp("2")
            for key in modifiers
                this.State.KeyUp(key)
            this.Assert(!this.State.Captured.Count, "KeyUp 清理捕获键")
            this.State.AliasDown("CapsLock")
            this.Assert(this.State.Active, "重新按下可以进入")
        }
        this.Assert(LayerState.LayerOf(Map("LControl", 1, "RWin", 1)) == 1, "Ctrl/Win 不影响层号")
        this.Assert(LayerState.LayerOf(Map("LShift", 1, "RShift", 1, "LAlt", 1, "RAlt", 1)) == 4, "双侧修饰键不重复计层")
    }

    static SparseBindings() {
        this.Reset()
        callback := ObjBindMethod(this, "Action")
        this.Registry.Layers("2", Map(1, callback), Map(3, callback))
        this.State.AliasDown("F6")
        context := this.Context(Map("LShift", 1))
        this.Assert(!this.Dispatcher.Dispatch("2", context), "未注册的第二层不触发")
        this.Assert(this.State.Active && !this.State.Captured.Count, "未匹配不消费会话或捕获原键")
        this.Assert(!this.Registry.Resolve("2", 4), "未注册第四层不降级")
        this.Assert(this.Registry.Resolve("2", 3), "第三层可以单独注册")
        this.Throws(ObjBindMethod(this.Registry, "Layers", "2", Map(1, callback)), "重复层报错")
        this.Throws(ObjBindMethod(this.Registry, "Layers", "3", Map(5, callback)), "非法层号报错")
        this.Throws(ObjBindMethod(this.Registry, "Layers", "4", Map(1, callback, 2, callback)), "每个 Map 必须只有一层")
    }

    static MixedLayerModes() {
        this.Reset()
        callback := ObjBindMethod(this, "Action")
        this.Registry.Once("7", Map(1, callback))
        this.Registry.Layers("7", Map(2, callback))
        this.State.AliasDown("F6")
        shifted := HotkeyContext("7", Map("LShift", 1), this.State.Triggers())
        this.Dispatcher.Dispatch("7", shifted)
        this.Assert(this.State.Active && this.Events[-1].Mode == "layers", "第二层保留会话")
        this.State.KeyUp("7")
        this.Dispatcher.Dispatch("7", shifted)
        this.Assert(this.Events.Length == 2 && this.State.Active, "第二层可连续执行")
        this.State.KeyUp("7")
        this.Dispatcher.Dispatch("7", HotkeyContext("7", Map(), this.State.Triggers()))
        this.Assert(this.State.Phase == "Spent" && this.Events[-1].Mode == "once", "同一按键第一层结束会话")
        this.Throws(ObjBindMethod(this.Registry, "Once", "7", Map(2, callback)), "跨模式重复层仍报错")
        this.Throws(ObjBindMethod(this.Registry, "Pass", "7", callback), "穿透不能混合分层绑定")
    }

    static Passthrough() {
        this.Reset()
        this.Registry.Pass("1", ObjBindMethod(this, "Action"))
        this.State.AliasDown("F6")
        modifiers := Map("LControl", 1, "RShift", 1, "LAlt", 1, "RWin", 1)
        context := HotkeyContext("1", modifiers, this.State.Triggers())
        this.Assert(this.Dispatcher.Dispatch("1", context), "穿透在任意层触发")
        this.Assert(this.State.Active && this.Sender.Calls == 0, "穿透保留层和修饰键")
        this.Assert(this.Events[1].Mode == "pass" && this.Events[1].Layer == 4, "穿透快照显示层但不按层分发")
        this.Assert(!this.Dispatcher.Dispatch("1", context), "按住信息键不反复执行")
        this.State.KeyUp("1")
        this.Assert(this.Dispatcher.Dispatch("1", context), "同一会话可以再次按穿透键")
        this.State.AliasUp("F6")
        this.State.KeyUp("1")
        this.Assert(this.State.Phase == "Idle" && !this.State.Captured.Count, "穿透松键收尾")
    }

    static ApplicationRules() {
        this.Reset()
        callback := ObjBindMethod(this, "Action")
        this.Registry.Pass("1", callback)
        this.Registry.App("anki").Once("1", Map(1, ObjBindMethod(this, "CleanAction")))
        this.State.AliasDown("F6")
        this.Assert(!this.Registry.Resolve("1", 2, 7), "命中应用后缺失层不回退全局穿透")
        this.Assert(this.Registry.Resolve("1", 4, 8).Mode == "pass", "其他应用使用全局穿透")
        this.Dispatcher.Dispatch("1", HotkeyContext("1", Map(), this.State.Triggers(), 7))
        this.Assert(this.Events[1].Mode == "once", "应用分流在穿透判定之前")
    }

    static FailureCleanup() {
        this.Reset()
        this.Registry.Layers("2", Map(1, ObjBindMethod(this, "FailAction")))
        this.State.AliasDown("F6")
        this.Throws(ObjBindMethod(this.Dispatcher, "Dispatch", "2", this.Context()), "动作异常传出")
        this.Assert(this.State.Active && this.Sender.Calls == 1 && this.Sender.Restores == 1, "重复动作异常也恢复修饰键并保留层")
        this.Assert(!A_IsCritical, "动作异常不遗留 Critical")
        this.State.KeyUp("2")
        this.State.AliasUp("F6")
        this.Assert(this.State.Phase == "Idle", "异常后的松键仍正常")
    }

    static Repeated() {
        this.Reset()
        this.Registry.Layers("WheelUp", Map(1, ObjBindMethod(this, "Action")), Map(2, ObjBindMethod(this, "Action")))
        this.State.AliasDown("F6")
        for modifiers in [Map(), Map("LShift", true), Map()] {
            this.Assert(this.Dispatcher.Dispatch("WheelUp", this.Context(modifiers)), "连续滚轮可按当前 Shift 状态选择动作")
            this.State.KeyUp("WheelUp")
        }
        this.Assert(this.State.Active && this.State.Used && this.Sender.Calls == 3 && this.Sender.Restores == 3, "默认分层动作每次释放并恢复修饰键，不消费 Caps 会话")
        this.Assert(this.Events[2].Layer == 2 && this.Events[3].Layer == 1, "同一会话中可切换横向和纵向")
        this.Assert(!this.Registry.Resolve("WheelUp", 3), "连续滚轮不占用未声明的 Alt 层")
        this.Assert(!this.State.AliasUp("F6"), "连续滚轮后的 Caps 松开不切换输入法")
        this.Assert(NativeHotkeys.IsPulse("WheelUp") && !NativeHotkeys.IsPulse("2"), "滚轮没有 KeyUp 事件")
        this.Reset()
        this.Registry.Layers("WheelUp", Map(1, ObjBindMethod(this, "Action")))
        this.State.AliasDown("F6")
        router := TriggerRouter(this.State, this.Sender, (*) => "layer")
        input := HotkeyInput(this.State, this.Registry, this.Dispatcher, router, Map("F6", true), ObjBindMethod(this, "Action"))
        input.KeyPulse("WheelUp")
        input.KeyPulse("WheelUp")
        this.Assert(this.Events.Length == 2 && !this.State.Captured.Has("WheelUp"), "输入适配器连续两次滚轮无需等待 KeyUp")
        this.Registry.Layers("WheelDown", Map(1, ObjBindMethod(this, "FailAction")))
        this.Throws(() => input.KeyPulse("WheelDown"), "滚轮动作异常传播")
        this.Assert(!this.State.Captured.Has("WheelDown") && this.State.Active, "滚轮异常也释放脉冲捕获")
        this.Reset()
        this.Registry.Pass("q", ObjBindMethod(this, "Action"))
        this.Registry.Layers("-", Map(1, ObjBindMethod(this, "Action")), Map(2, ObjBindMethod(this, "Action")))
        this.Registry.Once("2", Map(1, ObjBindMethod(this, "Action")))
        this.State.AliasDown("F6")
        for key in ["q", "-", "q", "-"] {
            this.Assert(this.Dispatcher.Dispatch(key, HotkeyContext(key, Map(), this.State.Triggers())), "保留层动作可交替重复执行")
            this.State.KeyUp(key)
        }
        this.Assert(this.State.Active && this.Sender.Calls == 2, "穿透及默认分层动作均不结束 Caps 会话")
        this.Dispatcher.Dispatch("2", this.Context())
        this.Assert(!this.State.Active && this.Sender.Calls == 3, "随后执行一次性动作仍正常释放并结束层")
        this.State.KeyUp("2")
        router := TriggerRouter(this.State, this.Sender, (*) => "layer")
        input := HotkeyInput(this.State, this.Registry, this.Dispatcher, router, Map("F6", true), ObjBindMethod(this, "Action"))
        this.Assert(input.CanHandle("2"), "一次性动作松开功能键后继续拦截原键")
        input.KeyDown("2")
        this.Assert(this.Events.Length == 5 && this.State.Captured.Has("2"), "重复一次性键只吸收，不执行且等待 KeyUp")
        input.KeyUp("2")
        this.State.AliasUp("F6")
        this.Assert(!input.CanHandle("2") && !this.State.Blocked.Count, "Caps 松开后恢复普通按键")
        this.Reset()
        this.Registry.Layers("c", Map(1, ObjBindMethod(this, "Action")))
        this.Registry.App("anki").Layers("c", Map(1, ObjBindMethod(this, "Action")))
        this.State.AliasDown("F6")
        loop 2 {
            this.Dispatcher.Dispatch("c", HotkeyContext("c", Map(), this.State.Triggers(), 7))
            this.State.KeyUp("c")
        }
        this.Assert(this.State.Active && this.Events.Length == 2, "应用专用默认分层动作同样可以重复")
    }

    static Diagnostics() {
        display := this.Display()
        diagnostics := HotkeyDiagnostics(display)
        registry := HotkeyRegistry()
        actions := this.FakeActions()
        HotkeyBindings.Register(registry, diagnostics, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions)
        this.Assert(registry.Resolve("e", 1).Mode == "once" && !registry.Resolve("e", 2), "目录菜单只注册全局第一层且一次性触发")
        this.Assert(registry.Resolve("s", 1).Mode == "once", "GUI 明确注册为一次性动作")
        this.Assert(registry.Resolve("w", 1).Mode == "once" && !registry.Resolve("w", 2), "窗口查看器仅注册第一层一次性动作")
        registry.Matcher := (scope, hwnd) => scope == WindowGroups.Anki && hwnd == 7
        this.Assert(registry.Resolve("w", 1, 7).Mode == "layers" && !registry.Resolve("w", 2, 7), "Anki W 样式优先，空白层不回退查看器")
        this.Assert(registry.Resolve("t", 1).Mode == "layers" && !registry.Resolve("t", 2), "窗口置顶可连续切换，第二层未绑定")
        this.Assert(registry.Resolve("t", 1, 7).Callback != registry.Resolve("t", 1).Callback
            && !registry.Resolve("t", 2, 7), "Anki T 保留样式动作且空白层不回退")
        this.Assert(registry.Resolve("7", 1).Mode == "once" && registry.Resolve("7", 2).Mode == "layers"
            && !registry.Resolve("7", 3) && !registry.Resolve("7", 4), "字符查看器第一层一次性，首字母大写第二层可连续触发")
        for key in ["x", "c", "v", "z", "Space"]
            this.Assert(registry.Resolve(key, 1).Mode == "layers", "剪贴板及特殊空格使用默认重复模式")
        for key in ["-", "="] {
            this.Assert(registry.Resolve(key, 1).Mode == "layers" && registry.Resolve(key, 2).Mode == "layers", "缩放和横滚使用默认重复模式")
            this.Assert(!registry.Resolve(key, 3), "连续键未声明的层不降级")
        }
        for key in ["q", "Tab", "``", "4", "6", "r", "a", "d", "x", "c", "v", "z", "Space", "b", ",", ";", "u", "i", "o", "j", "k", "l", "p", "Backspace", "\", "Enter"]
            this.Assert(registry.Bindings.Has(GetKeyName(key)), "基础热键已注册：" key)
        this.Assert(!registry.Resolve("z", 2) && !registry.Resolve("Tab", 4), "暂缓和空白层保持未注册")
        for key in ["q", "u", "i", "o", "j", "k", "l", "\"] {
            loop 4
                this.Assert(registry.Resolve(key, A_Index).Mode == "pass", "鼠标及系统按键保留所有修饰键")
        }
        for key in ["x", "c", "v", "Enter", "t"] {
            for layer in [3, 4]
                this.Assert(registry.Resolve(key, layer).Mode == "layers", "第 3/4 层已注册")
        }
        this.Assert(registry.Resolve(".", 1).Mode == "layers", "句点第一层绑定输入法动作")
        this.Assert(registry.Resolve(".", 2).Mode == "layers" && !registry.Resolve(".", 3), "句点有前两层，未声明层不降级")
        loop 4 {
            this.Assert(registry.Resolve("1", A_Index).Mode == "pass", "1 是无层穿透绑定")
            this.Assert(registry.Resolve("2", A_Index).Mode == "layers", "2 的四层均独立注册")
        }
        context := HotkeyContext("1", Map("RAlt", 1), ["F6"], 42)
        context.Title := "测试窗口"
        context.Process := "test.exe"
        diagnostics.ShowContext(context)
        this.Assert(InStr(display.Text, "测试窗口") && InStr(display.Text, "test.exe"), "提示包含前台窗口")
        this.Assert(InStr(display.Text, "RAlt") && InStr(display.Text, "Layer: 3"), "提示包含修饰键及层")
    }
}
