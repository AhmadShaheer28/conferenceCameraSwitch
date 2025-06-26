//
//  ConferenceCameraSwitchApp.swift
//  ConferenceCameraSwitch
//
//  Created by Ahmad Shaheer on 25/06/2025.
//

import SwiftUI

@main
struct ConferenceCameraSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let cameraManager = USBCameraManager()
    var selectedCamera: USBCameraManager.CameraDevice?
    var cameraMenuItems: [NSMenuItem] = []
    let virtualCameraComm = VirtualCameraCommunicator.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "video", accessibilityDescription: "Camera")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
        cameraManager.onCameraListChanged = { [weak self] in
            // No need to update menu here; menu is built on click
        }
        cameraManager.startMonitoring()
        if !virtualCameraComm.isVirtualCameraRunning() {
            _ = virtualCameraComm.startVirtualCamera()
        }
    }
    
    @objc func statusItemClicked(_ sender: Any?) {
        if let button = statusItem?.button {
            let menu = menuForPopup()
            statusItem?.menu = menu
            statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            statusItem?.menu = nil // Remove menu after showing
        }
    }
    
    func menuForPopup() -> NSMenu {
        print("Constructing menu") // Debug print
        let menu = NSMenu()
        
        // Camera selection section
        menu.addItem(NSMenuItem(title: "Select USB Camera", action: nil, keyEquivalent: ""))
        let cameras = cameraManager.listUSBCameras()
        cameraMenuItems = []
        if cameras.isEmpty {
            let item = NSMenuItem(title: "No USB Cameras Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for camera in cameras {
                let title = "\(camera.name) (VID: \(String(format: "%04X", camera.vid)), PID: \(String(format: "%04X", camera.pid)))"
                let item = NSMenuItem(title: title, action: #selector(selectCamera(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = camera
                if let selected = selectedCamera, selected.vid == camera.vid && selected.pid == camera.pid {
                    item.state = .on
                }
                cameraMenuItems.append(item)
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Virtual camera control section
        menu.addItem(NSMenuItem(title: "Virtual Camera Control", action: nil, keyEquivalent: ""))
        
        let statusItem = NSMenuItem(title: "Status: \(virtualCameraComm.isVirtualCameraRunning() ? "Running" : "Stopped")", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        if virtualCameraComm.isVirtualCameraRunning() {
            menu.addItem(NSMenuItem(title: "Stop Virtual Camera", action: #selector(stopVirtualCamera), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Restart Virtual Camera", action: #selector(restartVirtualCamera), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Start Virtual Camera", action: #selector(startVirtualCamera), keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Cameras", action: #selector(refreshCameras), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        print("Menu set on statusItem") // Debug print
        return menu
    }
    
    @objc func selectCamera(_ sender: NSMenuItem) {
        if let camera = sender.representedObject as? USBCameraManager.CameraDevice {
            selectedCamera = camera
            notifyVirtualCameraDriver(camera: camera)
        }
    }
    
    func notifyVirtualCameraDriver(camera: USBCameraManager.CameraDevice) {
        if virtualCameraComm.selectCamera(camera) {
            print("Successfully selected camera: \(camera.name) (VID: \(String(format: "%04X", camera.vid)), PID: \(String(format: "%04X", camera.pid)))")
        } else {
            print("Failed to select camera: \(camera.name)")
        }
    }
    
    @objc func startVirtualCamera() {
        if virtualCameraComm.startVirtualCamera() {
            print("Virtual camera started successfully")
        } else {
            print("Failed to start virtual camera")
        }
    }
    
    @objc func stopVirtualCamera() {
        if virtualCameraComm.stopVirtualCamera() {
            print("Virtual camera stopped successfully")
        } else {
            print("Failed to stop virtual camera")
        }
    }
    
    @objc func restartVirtualCamera() {
        if virtualCameraComm.restartVirtualCamera() {
            print("Virtual camera restarted successfully")
        } else {
            print("Failed to restart virtual camera")
        }
    }
    
    @objc func refreshCameras() {
        // No need to update menu here; menu is built on click
    }
    
    @objc func quit() {
        _ = virtualCameraComm.stopVirtualCamera()
        NSApplication.shared.terminate(nil)
    }
}
