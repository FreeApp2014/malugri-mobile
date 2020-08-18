//
//  ViewController.swift
//  malugri-mobile
//
//  Created by admin on 06/08/2020.
//  Copyright © 2020 FreeAppSW. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import Foundation
import MediaPlayer

var format: AVAudioFormat = AVAudioFormat();
var decodeMode = 0;

class ViewController: UIViewController, UIDocumentPickerDelegate {

    @objc func notificationHandler(notification:  Notification){
        self.labelFN.text! = (notification.object as! URL).lastPathComponent;
        handleFile(path: (notification.object as! URL).path);
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler), name: NSNotification.Name(rawValue: "FileOpen"), object: nil);
        // Do any additional setup after loading the view, typically from a nib.
    }
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.am.resume();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1.0;
            self.pauseBTN.setTitle("Pause", for: UIControl.State.normal);
            return .success;
        }
        
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.am.pause();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0;
            print(Int(ceil(Double(self.am.pausedSampleNumber) / Double(gHEAD1_sample_rate()))));
            //if lastRenderTime returned overblown sample number fix the brain retardation before pushing 
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = Int(floor(Double(self.am.pausedSampleNumber > self.apple ? self.am.pausedSampleNumber - self.apple : self.am.pausedSampleNumber ) / Double(gHEAD1_sample_rate())));
            self.pauseBTN.setTitle("Resume", for: UIControl.State.normal);
            return .success;
        }
    }
    
    func publishDataToMPNP(){
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = self.labelFN.text!;
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0;
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = floor(Double(gHEAD1_total_samples()) / Double(gHEAD1_sample_rate()))
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0;
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    @IBAction func buttonclick(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["space.freeappsw.malugri-mobile.brstm", "space.freeappsw.malugri-mobile.bfstm"], in: .import);
        documentPicker.delegate = self
        self.present(documentPicker, animated: true);
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.labelFN.text! = urls[0].lastPathComponent;
        handleFile(path: urls[0].path);
    }
    @IBOutlet weak var labelFN: UILabel!
    func readFile(path: String, convert: Bool = false) -> Bool {
        var filesize: UInt64 = 0;
        initStruct();
        do {
            let fileat = try FileManager.default.attributesOfItem(atPath: path);
            filesize = fileat[.size] as? UInt64 ?? UInt64(0);
//            if (filesize >= 5000000 && self.choiceGB.indexOfSelectedItem == 0) {
//                decodeMode = 1;
//            } else if (self.choiceGB.indexOfSelectedItem == 1){
//                decodeMode = 0;
//            } else if (self.choiceGB.indexOfSelectedItem == 2) {
//                decodeMode = 1;
//            }
            decodeMode = 0;
        } catch let error as NSError {
            print("FileAttribute error: \(error)");
            return false;
        }
        if (convert) {decodeMode = 0;}
        switch(decodeMode){
        case 0: let file = FileHandle.init(forReadingAtPath: path)!.availableData;
        let resultRead = file.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) -> Bool in
            let stat = readABrstm(u8Ptr, 1, true);
            if (stat > 127){
                popupAlert(parent: self, title:"Error reading file", message: "brstm_read returned error " + String(stat));
                return false;
            }
            return true;
        }
        if (!resultRead) {return false};
        break;
        case 1: let pointer: UnsafePointer<Int8>? = NSString(string: path).utf8String;
        let stati = createIFSTREAMObject(strdup(pointer)!);
        if (stati != 1){
            popupAlert(parent: self, title:"Error reading file", message: "ifstream::open returned error " + String(stati));
            return false;
        }
        let stat = readFstreamBrstm();
        if (stat > 127){
            popupAlert(parent: self, title:"Error reading file", message: "brstm_read returned error " + String(stat));
            return false;
        }
        break;
        default: break;
        }
        return true;
    }
    var apple: Int64 = 0;
    let am = AudioManager();
    func handleFile(path: String) {
        if (readFile(path: path)){
            if(am.wasUsed){
                am.stopBtn();
                print("a");
                self.am.i = 0;
                Thread.sleep(forTimeInterval: 0.05);
            }
            //Put stuff to the information screen
            DispatchQueue.main.async {
                self.lblFileType.text! = AudioManager.resolveAudioFormat(UInt(gFileType()));
                self.lblCodec.text! = AudioManager.resolveAudioCodec(UInt(gFileCodec()));
                self.lblSampleRate.text! = String(gHEAD1_sample_rate()) + " Hz";
                self.lblLoop.text! = (gHEAD1_loop() == 1 ? "Yes" : "No");
                self.lblTotalSamples.text! = String(gHEAD1_total_samples());
                self.lblDuration.text! = String(floor(Double(gHEAD1_total_samples()) / Double(gHEAD1_sample_rate()))) + " seconds";
                self.lblLoopPoint.text! = String(gHEAD1_loop_start());
                self.lblBlockSize.text! = String(gHEAD1_blocks_samples()) + " samples";
                self.lblTotalBlocks.text! = String(gHEAD1_total_blocks());
            }
        
            //Configure iOS media api crap
            setupRemoteTransportControls();
            publishDataToMPNP();
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(AVAudioSession.Category.playback,
                                        mode: AVAudioSession.Mode.spokenAudio,
                                        options: [])
                try session.setActive(true)
            } catch let error as NSError {
                print("Failed to set the audio session category and mode: \(error.localizedDescription)")
                
            }
            //Actual playback
            switch (decodeMode){
            case 0:
                let buffer = createAudioBuffer(gPCM_samples(), offset: 0, needToInitFormat: true);
                am.initialize(format: format);
                apple = self.am.pausedSampleNumber; // Thanks apple for making AVAudioNode so fucking retarded
                self.am.playBuffer(buffer: buffer);
                am.genPB();
                break;
            case 1:
                let blockbuffer = getBufferBlock(0);
                let buffer = createBlockBuffer(blockbuffer!, needToInitFormat: true, bs: Int(gHEAD1_blocks_samples()));
                am.initialize(format: format);
                self.am.playBuffer(buffer: buffer);
                break
            default:
                print("if this is printed then idk what happened to this world")
            }
        }
    }
    
    // Field labels
    
    @IBOutlet weak var lblFileType: UILabel!
    @IBOutlet weak var lblCodec: UILabel!
    @IBOutlet weak var lblSampleRate: UILabel!
    @IBOutlet weak var lblLoop: UILabel!
    @IBOutlet weak var lblLoopPoint: UILabel!
    @IBOutlet weak var lblDuration: UILabel!
    @IBOutlet weak var lblBlockSize: UILabel!
    @IBOutlet weak var lblTotalBlocks: UILabel!
    @IBOutlet weak var lblTotalSamples: UILabel!
    @IBOutlet weak var pauseBTN: UIButton!
    
    @IBAction func stopButton(_ sender: Any) {
        self.am.stopBtn()
    }
    @IBAction func pauseBtn(_ sender: UIButton) {
        if (sender.currentTitle! == "Pause") {
            self.am.pause()
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0;
            print(Int(ceil(Double(self.am.pausedSampleNumber) / Double(gHEAD1_sample_rate()))));
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = Int(floor(Double(self.am.pausedSampleNumber > self.apple ? self.am.pausedSampleNumber - self.apple : self.am.pausedSampleNumber ) / Double(gHEAD1_sample_rate())));
            sender.setTitle("Resume", for: UIControl.State.normal);
        } else {
            self.am.resume()
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1.0;
            sender.setTitle("Pause", for: UIControl.State.normal);
        }
    }
    @IBOutlet weak var tempLbl: UILabel!
}

func popupAlert(parent: UIViewController, title: String, message: String){
    let asToPresent: UIAlertController = UIAlertController.init(title: title, message: message, preferredStyle: UIAlertController.Style.alert);
    asToPresent.addAction(UIAlertAction.init(title: "Dismiss", style: UIAlertAction.Style.cancel, handler: nil));
    parent.present(asToPresent, animated: true, completion: nil);
}
func createAudioBuffer(_ PCMSamples: UnsafeMutablePointer<UnsafeMutablePointer<Int16>?>, offset: Int, needToInitFormat: Bool, format16: Bool = false) -> AVAudioPCMBuffer {
    let channelCount = (gHEAD3_num_channels() > 2 ? 2 : gHEAD3_num_channels());
    if (!format16){
        if (needToInitFormat) {format = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: Double(gHEAD1_sample_rate()), channels: UInt32(channelCount), interleaved: false)!;}
    } else {
        if (needToInitFormat) {format = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: Double(gHEAD1_sample_rate()), channels: UInt32(channelCount), interleaved: false)!;}
    }
    let buffer = AVAudioPCMBuffer.init(pcmFormat: format, frameCapacity: UInt32((Int(gHEAD1_total_samples()) - offset)));
    buffer!.frameLength = AVAudioFrameCount(UInt32(Int(gHEAD1_total_samples()) - offset));
    var i: Int = 0;
    i = 0;
    var j: Int = 0;
    if (!format16){
        while (UInt32(j) < channelCount){
            while (UInt(i) < UInt((Int(gHEAD1_total_samples()) - offset))) {
                buffer?.floatChannelData![j][i] =  Float32(Float32(PCMSamples[j]![i+offset]) / Float32(32768));
                i += 1;
            }
            i = 0;
            j += 1;
        };} else {
        while (UInt32(j) < channelCount){
            while (UInt(i) < UInt((Int(gHEAD1_total_samples()) - offset))) {
                buffer?.int16ChannelData![j][i] =  PCMSamples[j]![i+offset];
                i += 1;
            }
            i = 0;
            j += 1;
        }
    }
    i = 0;
    return buffer!;
}

func createBlockBuffer(_ blockbuffer: UnsafeMutablePointer<UnsafeMutablePointer<Int16>?>, needToInitFormat: Bool, bs: Int) -> AVAudioPCMBuffer {
    let channelCount = (gHEAD3_num_channels() > 2 ? 2 : gHEAD3_num_channels());
    if (needToInitFormat) {format = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: Double(gHEAD1_sample_rate()), channels: UInt32(channelCount), interleaved: false)!;}
    let buffer = AVAudioPCMBuffer.init(pcmFormat: format, frameCapacity: UInt32(bs));
    buffer!.frameLength = AVAudioFrameCount(UInt32(bs));
    let samples16 = blockbuffer;
    var i: Int = 0;
    i = 0;
    var j: Int = 0;
    while (UInt32(j) < channelCount){
        while (UInt(i) < bs) {
            buffer?.floatChannelData![j][i] =  Float32(Float32(samples16[j]![i]) / Float32(32768));
            i += 1;
        }
        i = 0;
        j += 1;
    };
    i = 0;
    return buffer!;
}
