import Foundation
import AVFoundation

class VirtualCameraCommunicator {
    static let shared = VirtualCameraCommunicator()
    
    private let socketPath = NSTemporaryDirectory() + "virtual_camera_control"
    private let statusPath = NSTemporaryDirectory() + "virtual_camera_status"
    private let configPath = NSTemporaryDirectory() + "virtual_camera_config"
    
    private init() {}
    
    // MARK: - Camera Selection
    
    func selectCamera(_ camera: USBCameraManager.CameraDevice) -> Bool {
        let config = CameraConfig(
            vid: camera.vid,
            pid: camera.pid,
            name: camera.name,
            timestamp: Date()
        )
        
        return writeConfig(config)
    }
    
    func deselectCamera() -> Bool {
        let config = CameraConfig(
            vid: 0,
            pid: 0,
            name: "None",
            timestamp: Date()
        )
        
        return writeConfig(config)
    }
    
    // MARK: - Status Monitoring
    
    func getVirtualCameraStatus() -> VirtualCameraStatus? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statusPath)),
              let status = try? JSONDecoder().decode(VirtualCameraStatus.self, from: data) else {
            return nil
        }
        return status
    }
    
    func isVirtualCameraRunning() -> Bool {
        return getVirtualCameraStatus()?.isRunning ?? false
    }
    
    // MARK: - Control Commands
    
    func startVirtualCamera() -> Bool {
        return sendCommand(.start)
    }
    
    func stopVirtualCamera() -> Bool {
        return sendCommand(.stop)
    }
    
    func restartVirtualCamera() -> Bool {
        return sendCommand(.restart)
    }
    
    // MARK: - Private Methods
    
    private func writeConfig(_ config: CameraConfig) -> Bool {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: URL(fileURLWithPath: configPath))
            return true
        } catch {
            print("Failed to write camera config: \(error)")
            return false
        }
    }
    
    private func sendCommand(_ command: VirtualCameraCommand) -> Bool {
        do {
            let commandData = try JSONEncoder().encode(command)
            try commandData.write(to: URL(fileURLWithPath: socketPath))
            return true
        } catch {
            print("Failed to send command: \(error)")
            return false
        }
    }
}

// MARK: - Data Models

struct CameraConfig: Codable {
    let vid: Int
    let pid: Int
    let name: String
    let timestamp: Date
}

struct VirtualCameraStatus: Codable {
    let isRunning: Bool
    let currentCamera: CameraConfig?
    let errorMessage: String?
    let timestamp: Date
}

enum VirtualCameraCommand: String, Codable {
    case start = "start"
    case stop = "stop"
    case restart = "restart"
    case status = "status"
} 