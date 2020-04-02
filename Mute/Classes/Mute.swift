//
//  Mute.swift
//  Mute
//
//  Created by Akram Hussein on 08/09/2017.
//

import Foundation
import AudioToolbox

@objcMembers
public class Mute: NSObject {

    public typealias MuteNotificationCompletion = ((_ mute: Bool) -> Void)

    // MARK: Properties

    /// Shared instance
    public static let shared = Mute()

    /// Sound ID for mute sound
    private let soundUrl = Mute.muteSoundUrl
    
    /// Notification handler to be triggered when mute status changes
    /// Triggered every second if alwaysNotify=true, otherwise only when it switches state
    public var notify: MuteNotificationCompletion?

    /// Currently playing? used when returning from the background (if went to background and foreground really quickly)
    public private(set) var isPlaying = false

    /// Current mute state
    public private(set) var isMute = false
    
    /// Silent sound (0.5 sec)
    private var soundId: SystemSoundID = 0

    /// Time difference between start and finish of mute sound
    private var interval: TimeInterval = 0

    // MARK: Resources

    /// Library bundle
    private static var bundle: Bundle {
        guard let path = Bundle(for: Mute.self).path(forResource: "Mute", ofType: "bundle"),
            let bundle = Bundle(path: path) else {
            fatalError("Mute.bundle not found")
        }

        return bundle
    }

    /// Mute sound url path
    private static var muteSoundUrl: URL {
        guard let muteSoundUrl = Mute.bundle.url(forResource: "mute", withExtension: "aiff") else {
            fatalError("mute.aiff not found")
        }
        return muteSoundUrl
    }

    // MARK: Init

    /// private init
    private override init() {
        super.init()

        self.soundId = 1

        if AudioServicesCreateSystemSoundID(self.soundUrl as CFURL, &self.soundId) == kAudioServicesNoError {
            var yes: UInt32 = 1
            AudioServicesSetProperty(kAudioServicesPropertyIsUISound,
                                     UInt32(MemoryLayout.size(ofValue: self.soundId)),
                                     &self.soundId,
                                     UInt32(MemoryLayout.size(ofValue: yes)),
                                     &yes)

        } else {
            print("Failed to setup sound player")
            self.soundId = 0
        }

    }

    deinit {
        if self.soundId != 0 {
            AudioServicesRemoveSystemSoundCompletion(self.soundId)
            AudioServicesDisposeSystemSoundID(self.soundId)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    public func detectIsMute(_ notify: @escaping MuteNotificationCompletion) {
        self.notify = notify
        self.playSound()
    }
    
    /// If not paused, playes mute sound
    private func playSound() {
        guard !isPlaying else { return }
        
        self.interval = Date.timeIntervalSinceReferenceDate
        self.isPlaying = true
        AudioServicesPlaySystemSoundWithCompletion(self.soundId) { [weak self] in
            self?.soundFinishedPlaying()
        }
    }

    /// Called when AudioService finished playing sound
    private func soundFinishedPlaying() {
        self.isPlaying = false

        let elapsed = Date.timeIntervalSinceReferenceDate - self.interval
        let isMute = elapsed < 0.1
        
        self.isMute = isMute
        DispatchQueue.main.async {
            self.notify?(isMute)
        }
    }
}
