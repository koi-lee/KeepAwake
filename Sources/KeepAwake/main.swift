//
//  main.swift
//  KeepAwake
//
//  入口点：使用 @main 启动
//

import Cocoa

@main
struct KeepAwakeMain {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
