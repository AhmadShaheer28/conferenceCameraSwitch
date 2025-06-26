import Foundation
import AVFoundation

class VirtualCameraDriver {
    static let shared = VirtualCameraDriver()
    
    private let configPath = NSTemporaryDirectory() + "virtual_camera_config"
    private let statusPath = NSTemporaryDirectory() + "virtual_camera_status"
    private let socketPath = NSTemporaryDirectory() + "virtual_camera_control"
    
    private var isRunning = false
    private var currentCamera: CameraConfig?
    private var configWatcher: DispatchSourceFileSystemObject?
    private var facetimeSession: AVCaptureSession?
    
    private init() {
        setupConfigWatcher()
        updateStatus()
    }
    
    // MARK: - Public Methods
    
    func start() {
        isRunning = true
        // Attempt to block FaceTime camera
        blockFaceTimeCamera()
        // Attempt to use USB camera as source
        if let usbCamera = findUSBCamera() {
            setVirtualCameraSource(usbCamera)
        } else {
            setVirtualCameraSource(nil) // fallback
        }
        updateStatus()
        print("Virtual camera driver started")
    }
    
    func stop() {
        isRunning = false
        releaseFaceTimeCamera()
        updateStatus()
        print("Virtual camera driver stopped")
    }
    
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.start()
        }
    }
    
    // MARK: - Camera Blocking Logic
    // This is a best-effort attempt to block the built-in FaceTime camera by opening it exclusively.
    // This is not guaranteed to work on all systems or with all apps.
    private func blockFaceTimeCamera() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        guard let facetimeDevice = discovery.devices.first(where: { $0.localizedName.lowercased().contains("facetime") }) else {
            print("No FaceTime camera found to block.")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: facetimeDevice)
            let session = AVCaptureSession()
            if session.canAddInput(input) {
                session.addInput(input)
                session.startRunning()
                facetimeSession = session
                print("FaceTime camera opened exclusively.")
            }
        } catch {
            print("Failed to open FaceTime camera: \(error)")
        }
    }
    
    private func releaseFaceTimeCamera() {
        facetimeSession?.stopRunning()
        facetimeSession = nil
        print("FaceTime camera released.")
    }
    
    // MARK: - Virtual Camera Source Logic
    private func findUSBCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first
    }
    
    private func setVirtualCameraSource(_ device: AVCaptureDevice?) {
        // TODO: Implement actual virtual camera source switching logic
        if let device = device {
            print("Using USB camera as virtual camera source: \(device.localizedName)")
        } else {
            print("No USB camera found. Using fallback source.")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupConfigWatcher() {
        let fileDescriptor = open(configPath, O_EVTONLY)
        if fileDescriptor >= 0 {
            configWatcher = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: DispatchQueue.global()
            )
            
            configWatcher?.setEventHandler { [weak self] in
                self?.handleConfigChange()
            }
            
            configWatcher?.resume()
        }
    }
    
    private func handleConfigChange() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let config = try? JSONDecoder().decode(CameraConfig.self, from: data) else {
            return
        }
        
        currentCamera = config
        updateStatus()
        
        if config.vid != 0 && config.pid != 0 {
            print("Switching to camera: \(config.name) (VID: \(String(format: "%04X", config.vid)), PID: \(String(format: "%04X", config.pid)))")
            // TODO: Implement actual camera switching logic here
        } else {
            print("Deselecting camera")
            // TODO: Implement fallback to default camera
        }
    }
    
    private func updateStatus() {
        let status = VirtualCameraStatus(
            isRunning: isRunning,
            currentCamera: currentCamera,
            errorMessage: nil,
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(status)
            try data.write(to: URL(fileURLWithPath: statusPath))
        } catch {
            print("Failed to update status: \(error)")
        }
    }
    
    deinit {
        configWatcher?.cancel()
    }
} 