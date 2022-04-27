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
    // MARK: - Initial setup
    var playerController = MalugriPlayer(using: MGEZAudioBackend());
    
    @objc func notificationHandler(notification:  Notification){
        self.labelFN.text! = (notification.object as! URL).lastPathComponent;
        MalugriUtil.popupAlert(parent: self,
                               title: "opening file" ,
                               message: (notification.object as! URL).path);
        handleFile(path: (notification.object as! URL).path);
    }
    
    @objc func exitNotification(notification: Notification){
        self.playerController.backend.stop();
        self.playerController.closeFile();
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler), name: NSNotification.Name(rawValue: "FileOpen"), object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(self.exitNotification), name: NSNotification.Name(rawValue: "ExitPlayer"), object: nil);
    }
    // MARK: - MPNowPlayingInfoCenter
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.playerController.backend.play();
            DispatchQueue.global().async {
                while (self.playerController.backend.state) {
                    DispatchQueue.main.async {
                        self.ElapsedTimeLabel.text = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate).hmsString;
                        self.timeSlider.value = Float(self.playerController.backend.currentSampleNumber) / Float(self.playerController.fileInformation.totalSamples);
                    }
                    Thread.sleep(forTimeInterval: 0.05);
                }
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1.0;
            self.pauseBTN.setTitle("Pause", for: UIControl.State.normal);
            return .success;
        }
        
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.playerController.backend.pause();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0;
            //if lastRenderTime returned overblown sample number fix the brain retardation before pushing 
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate);
            self.pauseBTN.setTitle("Resume", for: UIControl.State.normal);
            return .success;
        }
        
        // Add handler for seeking
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event -> MPRemoteCommandHandlerStatus in
            let event = event as! MPChangePlaybackPositionCommandEvent
            let newTime: UInt = UInt(event.positionTime * Double(self.playerController.fileInformation.sampleRate))
            self.playerController.backend.currentSampleNumber = newTime;
            return .success
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
    
    // MARK: - Document handler
    
    @IBAction func buttonclick(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["space.freeappsw.malugri-mobile.brstm",
                                                                            "space.freeappsw.malugri-mobile.bfstm",
                                                                            "space.freeappsw.malugri-mobile.bwav",
                                                                            "space.freeappsw.malugri-mobile.bcstm"],
                                                            in: .open);
        documentPicker.delegate = self
        self.present(documentPicker, animated: true);
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.labelFN.text! = urls[0].lastPathComponent;
        _ = urls[0].startAccessingSecurityScopedResource()
        handleFile(path: urls[0].path);
    }
    @IBOutlet weak var labelFN: UILabel!

    
    // MARK: Main function to start playback
    
    func handleFile(path: String) {
        do {
            try playerController.loadFile(file: path)
        } catch MGError.brstmReadError(let code, description) {
            MalugriUtil.popupAlert(parent: self,
                                   title: "Error opening file" ,
                                   message: "brstm_read: " + description + " (code " + String(code) + ")");
            return;
        } catch MGError.ifstreamError(let code) {
            MalugriUtil.popupAlert(parent: self,
                                   title: "Error opening file",
                                   message: "ifstream::open returned error code " + String(code))
            return;
        } catch {
            MalugriUtil.popupAlert(parent: self,
                                   title: "Internal error",
                                   message: "An unexpected error has occurred.")
            return;
        }
        //Put stuff to the information screen
        DispatchQueue.main.async {
            let info = self.playerController.fileInformation;
            self.lblFileType.text! = info.fileType + " · " + String(info.sampleRate) + " Hz";
            self.lblCodec.text! = info.codecString;
            self.lblLoop.text! = (info.looping ? "Yes" : "No");
            self.lblTotalSamples.text! = String(info.totalBlocks) + " blocks by " + String(info.blockSize) + " = " + String(info.totalSamples);
            self.lblDuration.text! = String(info.duration) + " seconds";
            self.lblLoopPoint.text! = String(info.loopPoint);
            self.TotalTimeLabel.text! = info.duration.hmsString;
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
        playerController.backend.play();
        self.playerController.backend.needsLoop = self.playerController.fileInformation.looping;
        self.loopToggle.isOn = self.playerController.fileInformation.looping;
        
        
        //Prevent action buttons from being pressed
        self.pauseBTN.isEnabled = true;
        self.stopBTN.isEnabled = true;
        self.loadFileBTN.isEnabled = false;
        
        DispatchQueue.global().async {
            while (self.playerController.backend.state) {
                DispatchQueue.main.async {
                    self.ElapsedTimeLabel.text = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate).hmsString;
                    self.timeSlider.value = Float(self.playerController.backend.currentSampleNumber) / Float(self.playerController.fileInformation.totalSamples);
                }
                Thread.sleep(forTimeInterval: 0.05);
            }
            DispatchQueue.main.async {
                if (!self.playerController.backend.needsLoop && self.pauseBTN.currentTitle! == "Pause"){
                    self.stopButton(self.stopBTN);
                }
            }
        }
    }
    
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var ElapsedTimeLabel: UILabel!
    @IBOutlet weak var TotalTimeLabel: UILabel!
    
    
    @IBAction func seek(_ sender: Any) {
        self.playerController.backend.currentSampleNumber = UInt(self.timeSlider.value * Float(self.playerController.fileInformation.totalSamples));
        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate);
    }
    
    // Field labels
    
    @IBOutlet weak var lblFileType: UILabel!
    @IBOutlet weak var lblCodec: UILabel!
    @IBOutlet weak var lblLoop: UILabel!
    @IBOutlet weak var lblLoopPoint: UILabel!
    @IBOutlet weak var lblDuration: UILabel!
    @IBOutlet weak var lblTotalSamples: UILabel!
    @IBOutlet weak var pauseBTN: UIButton!
    @IBOutlet weak var stopBTN: UIBarButtonItem!
    @IBOutlet weak var loadFileBTN: UIBarButtonItem!
    @IBOutlet weak var loopToggle: UISwitch!
    
    
    @IBAction func loopToggle(_ sender: UISwitch) {
        self.playerController.backend.needsLoop = sender.isOn;
    }
    
    @IBAction func stopButton(_ sender: UIBarButtonItem) {
        self.playerController.backend.stop();
        self.playerController.closeFile();
        self.pauseBTN.isEnabled = false;
        self.pauseBTN.setTitle("Pause", for: UIControl.State.normal);
        self.loadFileBTN.isEnabled = true;
        sender.isEnabled = false;
    }
    
    @IBAction func pauseBtn(_ sender: UIButton) {
        if (sender.currentTitle! == "Pause") {
            sender.setTitle("Resume", for: UIControl.State.normal);
            self.playerController.backend.pause();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0;
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate);
        } else {
            self.playerController.backend.play();
            DispatchQueue.global().async {
                while (self.playerController.backend.state) {
                    DispatchQueue.main.async {
                        self.ElapsedTimeLabel.text = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate).hmsString;
                        self.timeSlider.value = Float(self.playerController.backend.currentSampleNumber) / Float(self.playerController.fileInformation.totalSamples);
                        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = Int(self.playerController.backend.currentSampleNumber / self.playerController.fileInformation.sampleRate);
                    }
                    Thread.sleep(forTimeInterval: 0.05);
                }
                DispatchQueue.main.async {
                    if (!self.playerController.backend.needsLoop && self.pauseBTN.currentTitle! == "Pause"){
                        self.stopButton(self.stopBTN);
                    }
                }
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1.0;
            sender.setTitle("Pause", for: UIControl.State.normal);
        }
    }
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

