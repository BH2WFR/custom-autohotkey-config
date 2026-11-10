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
        }
        Release(triggers) {
            this.Calls++
            this.Triggers := triggers.Clone()
        }
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
        this.Passthrough()
        this.Continuous()
        this.ApplicationRules()
        this.FailureCleanup()
        this.Diagnostics()
        FileAppend("PASS: " this.Count " hotkey assertions" Chr(10), "*", "UTF-8")
    }

    static LayersAndAliases() {
        for modifiers in [Map(), Map("LShift", 1), Map("RAlt", 1), Map("RShift", 1, "LAlt", 1)] {
            this.Reset()
            expected := A_Index
            this.Registry.Layers("2",
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
        this.Registry.App("anki").Layers("1", Map(1, ObjBindMethod(this, "CleanAction")))
        this.State.AliasDown("F6")
        this.Assert(!this.Registry.Resolve("1", 2, 7), "命中应用后缺失层不回退全局穿透")
        this.Assert(this.Registry.Resolve("1", 4, 8).Mode == "pass", "其他应用使用全局穿透")
        this.Dispatcher.Dispatch("1", HotkeyContext("1", Map(), this.State.Triggers(), 7))
        this.Assert(this.Events[1].Mode == "layers", "应用分流在穿透判定之前")
    }

    static FailureCleanup() {
        this.Reset()
        this.Registry.Layers("2", Map(1, ObjBindMethod(this, "FailAction")))
        this.State.AliasDown("F6")
        this.Throws(ObjBindMethod(this.Dispatcher, "Dispatch", "2", this.Context()), "动作异常传出")
        this.Assert(this.State.Phase == "Spent" && this.Sender.Calls == 1, "动作异常后仍已清理")
        this.Assert(!A_IsCritical, "动作异常不遗留 Critical")
        this.State.KeyUp("2")
        this.State.AliasUp("F6")
        this.Assert(this.State.Phase == "Idle", "异常后的松键仍正常")
    }

    static Continuous() {
        this.Reset()
        this.Registry.Continuous("WheelUp", Map(1, ObjBindMethod(this, "Action")), Map(2, ObjBindMethod(this, "Action")))
        this.State.AliasDown("F6")
        for modifiers in [Map(), Map("LShift", true), Map()] {
            this.Assert(this.Dispatcher.Dispatch("WheelUp", this.Context(modifiers)), "连续滚轮可按当前 Shift 状态选择动作")
            this.State.KeyUp("WheelUp")
        }
        this.Assert(this.State.Active && this.State.Used && this.Sender.Calls == 0, "连续滚轮标记已使用但不消费 Caps 会话")
        this.Assert(this.Events[2].Layer == 2 && this.Events[3].Layer == 1, "同一会话中可切换横向和纵向")
        this.Assert(!this.Registry.Resolve("WheelUp", 3), "连续滚轮不占用未声明的 Alt 层")
        this.Assert(!this.State.AliasUp("F6"), "连续滚轮后的 Caps 松开不切换输入法")
        this.Assert(NativeHotkeys.IsPulse("WheelUp") && !NativeHotkeys.IsPulse("2"), "滚轮没有 KeyUp 事件")
        this.Reset()
        this.Registry.Continuous("WheelUp", Map(1, ObjBindMethod(this, "Action")))
        this.State.AliasDown("F6")
        router := TriggerRouter(this.State, this.Sender, (*) => "layer")
        input := HotkeyInput(this.State, this.Registry, this.Dispatcher, router, Map("F6", true), ObjBindMethod(this, "Action"))
        input.KeyPulse("WheelUp")
        input.KeyPulse("WheelUp")
        this.Assert(this.Events.Length == 2 && !this.State.Captured.Has("WheelUp"), "输入适配器连续两次滚轮无需等待 KeyUp")
        this.Registry.Continuous("WheelDown", Map(1, ObjBindMethod(this, "FailAction")))
        this.Throws(() => input.KeyPulse("WheelDown"), "滚轮动作异常传播")
        this.Assert(!this.State.Captured.Has("WheelDown") && this.State.Active, "滚轮异常也释放脉冲捕获")
    }

    static Diagnostics() {
        display := this.Display()
        diagnostics := HotkeyDiagnostics(display)
        registry := HotkeyRegistry()
        actions := this.FakeActions()
        HotkeyBindings.Register(registry, diagnostics, actions, actions, actions, actions, actions, actions, actions, actions, actions, actions)
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
