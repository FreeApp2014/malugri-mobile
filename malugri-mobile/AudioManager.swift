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

class AudioManager:NSObject {
    
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
        self.output = EZOutput(dataSource: dataSource, inputFormat: AudioStreamBasicDescription(mSampleRate: Float64(format.sampleRate), mFormatID: kAudioFormatLinearPCM, mFormatFlags: kLinearPCMFormatFlagIsSignedInteger, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: format.channelCount, mBitsPerChannel: 16, mReserved: 0));
    }
    
    var loopCount = 0;
    var needsLoop = true;
    var i: Double = 0;
    let playerThread = DispatchQueue.global(qos: .userInteractive);
    var e: Int64 = 0;
    var pausedSampleNumber: Int64 = 0;
    var releasedSampleNumber: Int64 = 0;
    var tsToReturn = false;
    
    func getCurrentSampleNumber() -> Int64{
        return self.audioPlayerNode.lastRenderTime!.sampleTime - releasedSampleNumber + pausedSampleNumber;
    }
    
    static func resolveAudioFormat(_ formatCode: UInt) -> String {
        switch (formatCode) {
        case 1: return "BRSTM";
        case 2: return "BCSTM";
        case 3: return "BFSTM";
        case 4: return "BWAV";
        case 5: return "ORSTM";
        default: return "Unknown format";
        }
    }
    static func resolveAudioCodec(_ codecCode: UInt) -> String {
        switch (codecCode){
        case 0: return "8bit PCM";
        case 1: return "16bit PCM";
        case 2: return "DSP-ADPCM";
        default: return "Unknown codec";
        }
    }
    func playBuffer(buffer: AVAudioPCMBuffer) -> Void {
        wasUsed = true;
        output!.startPlayback();
    }
    // Functions don't mean anything, just to not cause compilation error
    func state() -> Bool {
        return self.audioPlayerNode.isPlaying;
    }
    func varPlay() -> Bool {
        return self.needsToPlay;
    }
    func resume() -> Void {
 
    }
    
    func pause() -> Void {

    }
    func stopBtn() -> Void {

    }
    func stop() -> Void {
        
    }
    // Old functions to make audio buffers
    func genPB(){
        loopBuffer = createAudioBuffer(gPCM_samples(), offset: Int(gHEAD1_loop_start()), needToInitFormat: false);
    }
    func getNextChunk() -> AVAudioPCMBuffer {
        let bufferblock = getBufferBlock(gHEAD1_blocks_samples() * UInt(loopCount));
        let bs: Int;
        if (gHEAD1_blocks_samples() * UInt(loopCount) / gHEAD1_blocks_samples() < gHEAD1_total_blocks()) {bs = Int(gHEAD1_blocks_samples());}
        else {bs = Int(gHEAD1_final_block_samples());}
        return createBlockBuffer(bufferblock!, needToInitFormat: false, bs: bs);
    }
}

// MARK: - Data source

@objc fileprivate class DataSource: NSObject, EZOutputDataSource {
    
    private var counter: UInt = 0;
    
    func output(_ output: EZOutput!, shouldFill audioBufferList: UnsafeMutablePointer<AudioBufferList>!, withNumberOfFrames frames: UInt32, timestamp: UnsafePointer<AudioTimeStamp>!) -> OSStatus {
        print(frames, timestamp.pointee.mSampleTime);
        let samples = getbuffer(counter, frames);
        let audioBuffer: UnsafeMutablePointer<Int16> = audioBufferList[0].mBuffers.mData!.assumingMemoryBound(to: Int16.self);
        for i in 1...frames {
            if (i % 2 == 0) {
                audioBuffer[Int(i)] = samples![1]![Int(i)]
            } else {
                audioBuffer[Int(i)] = samples![0]![Int(i)]
            }
        }
        counter += UInt(frames);
        return noErr;
    }
    
}
/*
 - (OSStatus)        output:(EZOutput *)output
 shouldFillAudioBufferList:(AudioBufferList *)audioBufferList
 withNumberOfFrames:(UInt32)frames
 timestamp:(const AudioTimeStamp *)timestamp
 */

