import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // agent app, no Dock icon
let controller = AppController()
app.delegate = controller
app.run()
