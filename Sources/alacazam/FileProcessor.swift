//
//  File.swift
//  
//
//  Created by Jean-Daniel Dupas on 18/02/2020.
//

import Foundation
import AVFoundation

import AudioUtils

class FileProcessor {

  struct Options {
    let compress: Bool
    let bitPerSample: Int
  }

  let source: AVAudioFile
  let writer: AVAssetWriter

  init(url: URL, dest: URL, options: Options) throws {
    let aid = try AudioFile(url: url) // CoreAudio required to extract some properties (metadata, source bit depth, …)
    defer { aid.close() }

    source = try AVAudioFile(forReading: url)

    var destfile = dest.appendingPathComponent(url.lastPathComponent)
    destfile.deletePathExtension()
    destfile.appendPathExtension("m4a")
    writer = try AVAssetWriter(url: destfile, fileType: .m4a)

    writer.metadata = try aid.metadata()
    writer.shouldOptimizeForNetworkUse = true

    let format = source.fileFormat
    let output: [String:Any]
    if (options.compress) {
      output = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: format.sampleRate,
        AVNumberOfChannelsKey: format.channelCount,
        AVEncoderBitRateKey: 256000,
        AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_VariableConstrained,
      ]
      print("\tAAC \(output[AVSampleRateKey]!)Hz \(output[AVEncoderBitRateKey]!) bit/s - \(output[AVNumberOfChannelsKey]!) channels")
    } else {
      output = [
        AVFormatIDKey: kAudioFormatAppleLossless,
        AVSampleRateKey: format.sampleRate,
        AVNumberOfChannelsKey: format.channelCount,
        AVEncoderBitDepthHintKey: options.bitPerSample > 0 ? min(options.bitPerSample, format.bitDepth) : format.bitDepth
      ]
      print("\tlossless \(output[AVSampleRateKey]!)Hz \(output[AVEncoderBitDepthHintKey]!) bit - \(output[AVNumberOfChannelsKey]!) channels")
    }
    // '*** -[AVAssetWriterInput initWithMediaType:outputSettings:sourceFormatHint:] Channel layout is not valid for Format ID 'alac'.  Use kAudioFormatProperty_AvailableEncodeChannelLayoutTags (<AudioToolbox/AudioFormat.h>) to enumerate available channel layout tags for a given format.'
//    if let layout = format.channelLayout {
//      output[AVChannelLayoutKey] = NSData(audioChannelLayout: layout.layout)
//    }

    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: output)
    input.expectsMediaDataInRealTime = false

    writer.add(input)
  }

  func run(completionHandler handler: @escaping () -> Void) throws {
    let input = writer.inputs.first!

    writer.startWriting()
    writer.startSession(atSourceTime: CMTime.zero)
    let buffer = AVAudioPCMBuffer.init(pcmFormat: source.processingFormat, frameCapacity: 1024 * 16)!

    input.requestMediaDataWhenReady(on: .main) { [weak self] in
      guard let self = self else { return }
      autoreleasepool {
        let input = self.writer.inputs.first!
        while (input.isReadyForMoreMediaData) {
          buffer.frameLength = 0
          try? self.source.read(into: buffer)
          if (buffer.frameLength > 0) {
            let sampleBuffer = try! buffer.sampleBuffer()
            input.append(sampleBuffer)
          } else {
            input.markAsFinished()
            self.writer.finishWriting {
              if (self.writer.status != .completed) {
                print("[warning] writer status: \(self.writer.status) / \(self.writer.error?.localizedDescription ?? "<no error>")")
              }
              handler()
            }
            break
          }
        }
      }
    }
  }
}

private extension AVAudioPCMBuffer {
  func sampleBuffer(timeStamp: CMTime = CMTime.zero) throws -> CMSampleBuffer {
    let sampleBuffer = try CMSampleBuffer(dataBuffer: nil,
                                          dataReady: false,
                                          formatDescription: format.formatDescription,
                                          numSamples: CMItemCount(frameLength),
                                          presentationTimeStamp: timeStamp,
                                          packetDescriptions: []) { _ in return noErr }
    try sampleBuffer.setDataBuffer(fromAudioBufferList: audioBufferList)
    return sampleBuffer
  }
}

