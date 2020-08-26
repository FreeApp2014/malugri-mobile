//
//  AudioBackend.swift
//  malugri-mobile
//
//  Created by admin on 26/08/2020.
//  Copyright © 2020 FreeAppSW. All rights reserved.
//

import Foundation
import AVFoundation

// MARK: - Default EZAudio backend
class MGEZAudioBackend: NSObject, MGAudioBackend {

    var needsToPlay: Bool = true;
    var wasUsed: Bool = false;
    
    // MARK: - Initialization
    var output: EZOutput? = nil;
    fileprivate let dataSource = DataSource();
    
    func initialize (format: MGFileInformation){
        self.output = EZOutput(dataSource: dataSource, inputFormat: AudioStreamBasicDescription(mSampleRate: Float64(format.sampleRate),
                                                                                                mFormatID: kAudioFormatLinearPCM,
                                                                                                mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                                                                mBytesPerPacket: 4,
                                                                                                mFramesPerPacket: 1,
                                                                                                mBytesPerFrame: 4,
                                                                                                mChannelsPerFrame: UInt32(format.channelCount),
                                                                                                mBitsPerChannel: 16,
                                                                                                mReserved: 0));
        var b: UInt32 = 4096; //Frame per slice value for the audio unit
        
        // Set frames per slice to 4096 to allow playback with locked screen
        
        EZAudioUtilities.checkResult(AudioUnitSetProperty(output!.outputAudioUnit,
                                                          kAudioUnitProperty_MaximumFramesPerSlice,
                                                          kAudioUnitScope_Global,
                                                          0,
                                                          &b,
                                                          UInt32(MemoryLayout.size(ofValue: b))),
                                     operation: "Failed to set maximum frames per slice on mixer node".cString(using: .utf8));
    }
    
    var loopCount = 0;
    var needsLoop: Bool {
        get {
            return needLoop;
        }
        set (a) {
            needLoop = a;
        }
    }
    var i: Double = 0;
    
    // MARK: - Getter functions
    
    var currentSampleNumber: UInt {
        get {
            return dataSource.counter;
        }
        set (a) {
            dataSource.counter = a;
        }
    }
    
    func play() -> Void {
        wasUsed = true;
        output!.startPlayback();
    }
    
    // MARK: - UI buttons
    var state: Bool {
        get {
            return output!.isPlaying;
        }
    }
    func varPlay() -> Bool {
        return self.needsToPlay;
    }
    func resume() -> Void {
        output!.startPlayback();
    }
    
    func pause() -> Void {
        output!.stopPlayback();
    }
    func stop() -> Void {
        if (self.state) {output!.stopPlayback();}
        closeBrstm();
        dataSource.counter = 0;
    }
}

// MARK: - Data source

@objc fileprivate class DataSource: NSObject, EZOutputDataSource {
    
    public var counter: UInt = 0;
    
    func output(_ output: EZOutput!,
                shouldFill audioBufferList: UnsafeMutablePointer<AudioBufferList>!,
                withNumberOfFrames frames: UInt32,
                timestamp: UnsafePointer<AudioTimeStamp>!) -> OSStatus {
        if (counter > gHEAD1_total_samples()) {
            if (needLoop) {
                counter = gHEAD1_loop_start();
            } else {
                output.stopPlayback();
            }
        }
        let samples = getbuffer(counter, frames);
        let audioBuffer: UnsafeMutablePointer<Int16> = audioBufferList[0].mBuffers.mData!.assumingMemoryBound(to: Int16.self);
        var i = 0, j = 0;
        while (i < frames*2){
            audioBuffer[Int(i)] = samples![0]![j];
            audioBuffer[Int(i)+1] = samples![0]![j]
            i+=2;
            j+=1;
        }
        counter += UInt(frames);
        return noErr;
    }
    
}
