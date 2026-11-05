import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var currentInput: String = "načítam..."
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Monitor Input")
            button.action = #selector(toggleMenu)
            button.target = self
        }
        
        updateCurrentInput()
        
        // Turn off monitor when Mac sleeps or shuts down
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.powerOff(nil)
        }
        workspace.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            self?.powerOff(nil)
        }
        
        // Turn on monitor when Mac wakes up
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.powerOn(nil)
        }
    }
    
    func updateCurrentInput() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddcctl")
        task.arguments = ["list"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse current input - look for "dp2=0x10 current" pattern
            if let currentRange = output.range(of: " current") {
                let before = output[..<currentRange.lowerBound]
                if let commaRange = before.lastIndex(of: ",") {
                    let inputPart = before[commaRange...].trimmingCharacters(in: .whitespaces)
                    if let equals = inputPart.firstIndex(of: "=") {
                        let inputName = String(inputPart[..<equals]).trimmingCharacters(in: .whitespaces)
                        currentInput = inputName
                    }
                }
            }
        } catch {
            currentInput = "?"
        }
    }
    
    @objc func toggleMenu() {
        updateCurrentInput()
        
        let menu = NSMenu()
        
        // Current input header
        let currentItem = NSMenuItem(
            title: "Aktuálny: \(currentInput)",
            action: nil,
            keyEquivalent: ""
        )
        currentItem.isEnabled = false
        menu.addItem(currentItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Input options
        let inputs: [(String, String)] = [
            ("DisplayPort 2", "dp2"),
            ("HDMI 1", "hdmi1")
        ]
        
        for (name, value) in inputs {
            let item = NSMenuItem(
                title: name,
                action: #selector(switchInput(_:)),
                keyEquivalent: ""
            )
            item.representedObject = value
            item.target = self
            if value == currentInput {
                item.state = .on
            }
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Power control
        let powerOffItem = NSMenuItem(
            title: "Vypnúť monitor",
            action: #selector(powerOff(_:)),
            keyEquivalent: ""
        )
        powerOffItem.target = self
        menu.addItem(powerOffItem)
        
        let powerOnItem = NSMenuItem(
            title: "Zapnúť monitor",
            action: #selector(powerOn(_:)),
            keyEquivalent: ""
        )
        powerOnItem.target = self
        menu.addItem(powerOnItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Volume control
        let volumeItem = NSMenuItem(
            title: "Hlasitosť reproduktorov",
            action: nil,
            keyEquivalent: ""
        )
        volumeItem.isEnabled = false
        menu.addItem(volumeItem)
        
        let volumeSlider = NSMenuItem(
            title: "",
            action: #selector(volumeChanged(_:)),
            keyEquivalent: ""
        )
        volumeSlider.view = createVolumeSlider()
        volumeSlider.target = self
        menu.addItem(volumeSlider)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Ukončiť",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    func createVolumeSlider() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        
        let slider = NSSlider(frame: NSRect(x: 10, y: 2, width: 180, height: 16))
        slider.minValue = 0
        slider.maxValue = 100
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(volumeChanged(_:))
        
        container.addSubview(slider)
        return container
    }
    
    @objc func switchInput(_ sender: NSMenuItem) {
        guard let input = sender.representedObject as? String else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddcctl")
        task.arguments = ["input", input]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Update after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateCurrentInput()
            }
        } catch {
            print("Failed to switch: \(error)")
        }
    }
    
    @objc func volumeChanged(_ sender: NSSlider) {
        let volume = Int(sender.intValue)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddcctl")
        task.arguments = ["vcp", "0x62", "\(volume)"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to set volume: \(error)")
        }
    }
    
    @objc func powerOff(_ sender: NSMenuItem? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddcctl")
        task.arguments = ["vcp", "0xD6", "0x02"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to power off: \(error)")
        }
    }
    
    @objc func powerOn(_ sender: NSMenuItem? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ddcctl")
        task.arguments = ["vcp", "0xD6", "0x01"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to power on: \(error)")
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
