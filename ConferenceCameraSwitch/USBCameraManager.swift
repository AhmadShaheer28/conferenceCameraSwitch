import Foundation
import IOKit
import IOKit.usb

class USBCameraManager {
    struct CameraDevice {
        let name: String
        let vid: Int
        let pid: Int
    }
    
    // Callback to notify when camera list changes
    var onCameraListChanged: (() -> Void)?
    private var addedIter: io_iterator_t = 0
    private var removedIter: io_iterator_t = 0
    
    init() {
        // Initialization code
    }
    
    func listUSBCameras() -> [CameraDevice] {
        var cameras: [CameraDevice] = []
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        var iterator: io_iterator_t = 0

        let kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator)
        if kr != KERN_SUCCESS {
            return cameras
        }
        defer { IOObjectRelease(iterator) }

        var usbDevice = IOIteratorNext(iterator)
        while usbDevice != 0 {
            var vid: Int = 0
            var pid: Int = 0
            var name: String = "Unknown"

            // Get VID
            if let cfVid = IORegistryEntryCreateCFProperty(usbDevice, kUSBVendorID as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int {
                vid = cfVid
            }
            // Get PID
            if let cfPid = IORegistryEntryCreateCFProperty(usbDevice, kUSBProductID as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int {
                pid = cfPid
            }
            // Get Product Name
            if let cfName = IORegistryEntryCreateCFProperty(usbDevice, kUSBProductString as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
                name = cfName
            }

            // Check for UVC interface
            var interfaceIterator: io_iterator_t = 0
            if IORegistryEntryCreateIterator(usbDevice, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &interfaceIterator) == KERN_SUCCESS {
                var interface = IOIteratorNext(interfaceIterator)
                while interface != 0 {
                    if let cfClass = IORegistryEntryCreateCFProperty(interface, kUSBInterfaceClass as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int {
                        if cfClass == 0x0e { // 0x0e = Video class
                            cameras.append(CameraDevice(name: name, vid: vid, pid: pid))
                            break
                        }
                    }
                    IOObjectRelease(interface)
                    interface = IOIteratorNext(interfaceIterator)
                }
                IOObjectRelease(interfaceIterator)
            }
            IOObjectRelease(usbDevice)
            usbDevice = IOIteratorNext(iterator)
        }
        return cameras
    }
    
    func startMonitoring() {
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        let notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort)?.takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        
        // Device added
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchingDict,
            { (refcon, iterator) in
                let manager = Unmanaged<USBCameraManager>.fromOpaque(refcon!).takeUnretainedValue()
                while IOIteratorNext(iterator) != 0 {}
                manager.onCameraListChanged?()
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &addedIter
        )
        // Prime the notification
        while IOIteratorNext(addedIter) != 0 {}
        
        // Device removed
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchingDict,
            { (refcon, iterator) in
                let manager = Unmanaged<USBCameraManager>.fromOpaque(refcon!).takeUnretainedValue()
                while IOIteratorNext(iterator) != 0 {}
                manager.onCameraListChanged?()
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &removedIter
        )
        // Prime the notification
        while IOIteratorNext(removedIter) != 0 {}
    }
    
    func stopMonitoring() {
        if addedIter != 0 {
            IOObjectRelease(addedIter)
            addedIter = 0
        }
        if removedIter != 0 {
            IOObjectRelease(removedIter)
            removedIter = 0
        }
    }
} 
