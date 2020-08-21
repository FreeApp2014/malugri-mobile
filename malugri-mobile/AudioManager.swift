//
//  AudioManager.swift
//  malugri-mobile
//
//  Created by admin on 07/08/2020.
//  Copyright © 2020 FreeAppSW. All rights reserved.
//
import Foundation
import UIKit
import AVFoundation
import MediaPlayer


var needLoop = true;
var loopBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer();

class AudioManager: NSObject, MGAudioBackend {
    
    let audioPlayerNode = AVAudioPlayerNode()
    
    lazy var audioEngine: AVAudioEngine = {
        let engine = AVAudioEngine()
        
        // Must happen only once.
        engine.attach(self.audioPlayerNode)
        
        return engine
    }()
    var needsToPlay: Bool = true;
    var wasUsed: Bool = false;
    
    // MARK: - Initialization
    var output: EZOutput? = nil;
    fileprivate let dataSource = DataSource();
    
    func initialize (format: AVAudioFormat){
        self.output = EZOutput(dataSource: dataSource, inputFormat: AudioStreamBasicDescription(mSampleRate: Float64(format.sampleRate), mFormatID: kAudioFormatLinearPCM, mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: format.channelCount, mBitsPerChannel: 16, mReserved: 0));
    }
    
    var loopCount = 0;
    var needsLoop = true;
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
        output!.stopPlayback();
    }
}

// MARK: - Data source

@objc fileprivate class DataSource: NSObject, EZOutputDataSource {
    
    public var counter: UInt = 0;
    
    func output(_ output: EZOutput!, shouldFill audioBufferList: UnsafeMutablePointer<AudioBufferList>!, withNumberOfFrames frames: UInt32, timestamp: UnsafePointer<AudioTimeStamp>!) -> OSStatus {
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

protocol MGAudioBackend {
    var currentSampleNumber: UInt { get set };
    func initialize (format: AVAudioFormat) -> Void;
    func resume() -> Void;
    func pause() -> Void;
    func stop() -> Void; 
    var state: Bool { get }; // true when playing, false when not;
    var needsLoop: Bool { get set}; // Sets automatically to true or false depending on file loop flag and can be explicitly changed
    func play() -> Void; //Assuming the api can get the samples from gPCM_buffer or using the getbuffer / getBufferBlock function
}
