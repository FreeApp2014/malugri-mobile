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
    @objc func notificationHandler(notification:  Notification){
        self.labelFN.text! = (notification.object as! URL).lastPathComponent;
        handleFile(path: (notification.object as! URL).path);
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler), name: NSNotification.Name(rawValue: "FileOpen"), object: nil);
    }
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.playerController.backend.play();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1.0;
            self.pauseBTN.setTitle("Pause", for: UIControl.State.normal);
            return .success;
        }
        
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.playerController.backend.pause();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0;
            //if lastRenderTime returned overblown sample number fix the brain retardation before pushing 
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0;
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
    
    // MARK: - Document handler
    
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

    var playerController = MalugriPlayer(using: MGEZAudioBackend());
    
    // MARK: Main function to start playback
    
    func handleFile(path: String) {
        do {
            try playerController.loadFile(file: path)
        } catch MGError.brstmReadError(let code, description) {
            MalugriUtil.popupAlert(parent: self, title: "Error opening file" , message: "brstm_read: " + description + " (code " + String(code) + ")");
        } catch MGError.ifstreamError(let code) {
            MalugriUtil.popupAlert(parent: self, title: "Error opening file", message: "ifstream::open returned error code " + String(code))
        } catch {
            MalugriUtil.popupAlert(parent: self, title: "Internal error", message: "An unexpected error has occurred.")
        }
        //Put stuff to the information screen
        DispatchQueue.main.async {
            let info = self.playerController.fileInformation;
            self.lblFileType.text! = info.fileType;
            self.lblCodec.text! = info.codecString;
            self.lblSampleRate.text! = String(info.sampleRate) + " Hz";
            self.lblLoop.text! = (info.looping ? "Yes" : "No");
            self.lblTotalSamples.text! = String(info.totalSamples);
            self.lblDuration.text! = String(info.duration) + " seconds";
            self.lblLoopPoint.text! = String(info.loopPoint);
            self.lblBlockSize.text! = String(info.blockSize) + " samples";
            self.lblTotalBlocks.text! = String(info.totalBlocks);
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
        self.playerController.backend.stop();
        self.playerController.closeFile();
    }
    @IBAction func pauseBtn(_ sender: UIButton) {
        if (sender.currentTitle! == "Pause") {
            self.playerController.backend.pause();
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0;
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0;
            sender.setTitle("Resume", for: UIControl.State.normal);
        } else {
            self.playerController.backend.play();
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

