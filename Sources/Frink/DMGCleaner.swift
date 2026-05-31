import Foundation
import AppKit

public struct DMGCleaner {
    public static func checkAndPromptClean() {
        // Ensure we are running from a path containing "/Applications/"
        let bundleURL = Bundle.main.bundleURL
        let path = bundleURL.path
        
        guard path.contains("/Applications/") else {
            return
        }
        
        let appName = bundleURL.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        
        guard let volumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return
        }
        
        for volumeURL in volumes {
            guard let resourceValues = try? volumeURL.resourceValues(forKeys: Set(keys)),
                  let volumeName = resourceValues.volumeName,
                  volumeName.lowercased() == appName.lowercased() else {
                continue
            }
            
            // Confirm the volume contains the app at its root
            let appInVolumeURL = volumeURL.appendingPathComponent(bundleURL.lastPathComponent)
            if fileManager.fileExists(atPath: appInVolumeURL.path) {
                // The installer volume is still mounted. Let's find the source DMG file path using hdiutil
                if let dmgPath = getDMGImagePath(forMountPoint: volumeURL.path) {
                    let dmgURL = URL(fileURLWithPath: dmgPath)
                    
                    // Dispatch to main thread to present alert sheet/modal
                    DispatchQueue.main.async {
                        promptUserToClean(volumeURL: volumeURL, dmgURL: dmgURL)
                    }
                }
                break
            }
        }
    }
    
    private static func getDMGImagePath(forMountPoint mountPoint: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["info", "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let images = plist["images"] as? [[String: Any]] {
                
                for image in images {
                    if let entities = image["system-entities"] as? [[String: Any]],
                       let imagePath = image["image-path"] as? String {
                        for entity in entities {
                            if let entityMount = entity["mount-point"] as? String,
                               entityMount == mountPoint {
                                return imagePath
                            }
                        }
                    }
                }
            }
        } catch {
            print("Failed to get DMG path: \(error)")
        }
        return nil
    }
    
    private static func promptUserToClean(volumeURL: URL, dmgURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Eject Installer & Clean Up?"
        alert.informativeText = "Frink has been successfully installed and is running from your Applications folder. Would you like to eject the installer disk image and move the DMG file to the Trash?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Eject and Trash DMG")
        alert.addButton(withTitle: "Keep DMG")
        
        // Present modal dialog
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            self.performClean(volumeURL: volumeURL, dmgURL: dmgURL)
        }
    }
    
    private static func performClean(volumeURL: URL, dmgURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["eject", volumeURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Move the source DMG file to the Trash
            try FileManager.default.trashItem(at: dmgURL, resultingItemURL: nil)
        } catch {
            print("Failed to eject or trash DMG: \(error)")
        }
    }
}
