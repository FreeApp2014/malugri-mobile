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

func callback (inRefCon: UnsafeMutableRawPointer, ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inBufferFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    for i in 0...((format.channelCount > 2 ? 2 : format.channelCount) - 1) {
        let buffer: AudioBuffer = ioData![Int(i)].mBuffers;
        let bufferblock = getBufferBlock(gHEAD1_blocks_samples() * UInt(loopCount));
        let size: UInt32 = min(buffer.mDataByteSize, UInt32(gBlockSize()))
        buffer.mData!.copyMemory(from: bufferblock![Int(i)]!, byteCount: Int(size))
        loopCount += 1;
    }
    return noErr;
}

var loopCount = 0;
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


    func initialize(format: AVAudioFormat) -> Void {
        do {
            let inputNode = self.audioEngine.inputNode
            self.audioEngine.connect(inputNode, to: audioEngine.mainMixerNode, format: format);
            var desc = AudioStreamBasicDescription();
            desc.mSampleRate = Float64(format.sampleRate);
            desc.mFormatID = kAudioFormatLinearPCM;
            desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            desc.mFramesPerPacket = 1;
            desc.mChannelsPerFrame = format.channelCount > 2 ? 2 : format.channelCount;
            desc.mBitsPerChannel = 16;
            desc.mBytesPerPacket = 4;
            desc.mBytesPerFrame = 4;

            let status: OSStatus = AudioUnitSetProperty(inputNode.audioUnit!,
                    kAudioUnitProperty_StreamFormat,
                    kAudioUnitScope_Input,
                    0,
                    &desc,
                    UInt32(MemoryLayout.size(ofValue: desc)));

            var callbackStruct = AURenderCallbackStruct();
            callbackStruct.inputProc = callback;
            callbackStruct.inputProcRefCon = nil;

            let state = AudioUnitSetProperty(inputNode.audioUnit!,
                    kAudioUnitProperty_SetRenderCallback,
                    kAudioUnitScope_Input,//Global
                    0,
                    &callbackStruct,
                    UInt32(MemoryLayout.size(ofValue: callbackStruct)));

            self.audioEngine.prepare();
        } catch {
            popupAlert(parent: UIApplication.shared.windows[0].rootViewController!, title: "Error", message: "Failed to start audio engine")
        }
    }
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

//    func playBuffer(buffer: AVAudioPCMBuffer) -> Void {
//        print(self.toggle)
//        wasUsed = true;
//        playerThread.async{
//            self.needsToPlay = true;
//            if (decodeMode == 1) {
//                self.loopCount += 1;
//                if (self.loopCount > gHEAD1_total_blocks()){
//                    self.loopCount = 1;
//                    self.releasedSampleNumber = self.audioPlayerNode.lastRenderTime!.sampleTime - Int64(gHEAD1_loop_start());
//                    MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = gHEAD1_loop_start() / gHEAD1_sample_rate()
//                }
//                if (self.toggle) {loopBuffer = self.getNextChunk()}
//            }
//            self.audioPlayerNode.play();
//            if (self.getCurrentSampleNumber() < 0) {
//                self.releasedSampleNumber =  self.getCurrentSampleNumber();
//            }
//            self.pausedSampleNumber = 0;
//            self.audioPlayerNode.scheduleBuffer(buffer,  completionHandler: {
//                if (decodeMode == 0) {self.releasedSampleNumber = self.audioPlayerNode.lastRenderTime!.sampleTime - Int64(gHEAD1_loop_start());}
//                self.needsToPlay = false;
//                if (self.needsLoop || decodeMode == 1){
//                    if (decodeMode == 0) {self.loopCount += 1;}
//                    self.playBuffer(buffer: loopBuffer);
//                    MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = gHEAD1_loop_start() / gHEAD1_sample_rate()
//                } else {
//                    closeBrstm();
//                }
//            });
//            if (!self.toggle) {loopBuffer = self.getNextChunk()}
//            if (self.toggle) {self.toggle = false} else {self.toggle = true}
//            while (self.needsToPlay){
//                if (self.audioPlayerNode.isPlaying) {
//                    self.e = self.getCurrentSampleNumber();
//                    self.i =  Double(self.e) / Double(gHEAD1_sample_rate());
//                }
//                Thread.sleep(forTimeInterval: 0.001);
//            };
//        };
//    }
//    func state() -> Bool {
//        return self.audioPlayerNode.isPlaying;
//    }
//    func varPlay() -> Bool {
//        return self.needsToPlay;
//    }
//    func resume() -> Void {
//        self.playerThread.resume();
//        do { try self.audioEngine.start();} catch {print("err")}
//        self.audioPlayerNode.play(at: nil);
//        self.releasedSampleNumber = self.audioPlayerNode.lastRenderTime!.sampleTime;
//        print(pausedSampleNumber);
//        print(releasedSampleNumber);
//    }
//
//    func pause() -> Void {
//        self.pausedSampleNumber = self.getCurrentSampleNumber()
//        self.audioPlayerNode.pause();
//        self.audioEngine.pause();
//        self.playerThread.suspend();
//    }
//    func stopBtn() -> Void {
//        needsLoop = false;
//        wasUsed = false;
//        stop();
//    }
//    func stop() -> Void {
//        self.releasedSampleNumber = self.audioPlayerNode.lastRenderTime!.sampleTime;
//        self.needsToPlay = false;
//        self.audioPlayerNode.stop();
//        self.audioPlayerNode.reset();
//        self.audioEngine.reset();
//        self.initialize(format: format);
//    }
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
