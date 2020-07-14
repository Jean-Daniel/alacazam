//
//  AudioFile.swift
//  alacazam
//
//  Created by Jean-Daniel Dupas on 18/02/2020.
//  Copyright © 2020 xooloo. All rights reserved.
//

import CoreAudio
import AVFoundation

import OSLog

private func parseTrkn(_ str: String) -> (UInt32, UInt32)? {
  let parts = str.split(separator: "/")
  if parts.count == 1 {
    guard let track = UInt32(parts[0]) else { return  nil }
    return (track, 0)
  }
  if parts.count == 2 {
    guard let track = UInt32(parts[0]), let total = UInt32(parts[1]) else { return  nil }
    return (track, total)
  }
  return nil
}

private extension AVMetadataIdentifier {
  static func from(key: String) -> AVMetadataIdentifier? {
    switch (key) {
      // iTunes entries
    case kAFInfoDictionary_Album: return .iTunesMetadataAlbum
    case kAFInfoDictionary_Artist: return .iTunesMetadataArtist
    case kAFInfoDictionary_Comments: return .iTunesMetadataUserComment
    case kAFInfoDictionary_Composer: return .iTunesMetadataComposer
    case kAFInfoDictionary_Copyright: return .iTunesMetadataCopyright
    case kAFInfoDictionary_Genre: return .iTunesMetadataUserGenre
    case kAFInfoDictionary_Lyricist: return .iTunesMetadataLyrics
    case kAFInfoDictionary_RecordedDate: return .iTunesMetadataReleaseDate
    case kAFInfoDictionary_Title: return .iTunesMetadataSongName
    case kAFInfoDictionary_TrackNumber: return .iTunesMetadataTrackNumber
    case kAFInfoDictionary_Year: return .iTunesMetadataReleaseDate
      // id3 entries
    case kAFInfoDictionary_ISRC: return .id3MetadataInternationalStandardRecordingCode // International Standard Recording Code

      // explicitly ignored entries
    case kAFInfoDictionary_SourceEncoder,
         kAFInfoDictionary_ChannelLayout,
         kAFInfoDictionary_EncodingApplication,
         kAFInfoDictionary_ApproximateDurationInSeconds:
      // kAFInfoDictionary_KeySignature,
      // kAFInfoDictionary_NominalBitRate,
      // kAFInfoDictionary_SourceBitDepth,
      // kAFInfoDictionary_SubTitle,
      // kAFInfoDictionary_Tempo,
      // kAFInfoDictionary_TimeSignature:
      return nil
      // unsupported entries
    default:
      print("skipping unsupported metadata: \(key)")
      return nil
    }
  }

  func format(_ value: Any) -> (NSObjectProtocol & NSCopying)? {
    switch (self) {
    case .iTunesMetadataTrackNumber:
      if let str = value as? String, let track = parseTrkn(str) {
        return encodeTrackNumber(num: track.0, count: track.1) as NSData
      }
      return nil
    default:
      return value as? (NSObjectProtocol & NSCopying)
    }
  }
}

private func encodeTrackNumber(num: UInt32, count: UInt32) -> Data {
  var buffer: Data = Data(count: 8)
  buffer.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) -> Void in
    pointer.storeBytes(of: num.bigEndian, as: UInt32.self)
    pointer.storeBytes(of: UInt16(count.bigEndian), toByteOffset: 4, as: UInt16.self)
  }
  return buffer
}

typealias AudioFile = AudioFileID

extension AudioFile {

  init(url: URL) throws {
    var af: AudioFileID? = nil
    let status = AudioFileOpenURL(url as CFURL, .readPermission, 0, &af)
    guard status == noErr, let audiofile = af else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil) }
    self = audiofile
  }

  func close() { AudioFileClose(self) }

  func bitDepth() throws -> Int {
    var value: Int32 = 0
    var size: UInt32 = UInt32(MemoryLayout.size(ofValue: value))
    let status = AudioFileGetProperty(self, kAudioFilePropertySourceBitDepth, &size, &value)
    guard status == noErr else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
    }
    return Int(value)
  }

  private func info() throws -> [String:Any] {
    var ref: Unmanaged<CFDictionary>? = nil
    var size: UInt32 = UInt32(MemoryLayout.size(ofValue: ref))
    let status = AudioFileGetProperty(self, kAudioFilePropertyInfoDictionary, &size, &ref)
    guard status == noErr, let info = ref?.takeRetainedValue() as NSDictionary? else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
    }
    return info as! [String:Any]
  }


  private func artworks() throws -> [NSData] {
    var ref: Unmanaged<CFData>? = nil
    var size: UInt32 = UInt32(MemoryLayout.size(ofValue: ref))
    // FIXME: AudioFile API supports only a single artwork
    let status = AudioFileGetProperty(self, kAudioFilePropertyAlbumArtwork, &size, &ref)
    guard status == noErr else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
    }
    guard let info = ref?.takeRetainedValue() as NSData? else {
      return []
    }
    return [info]
  }

  func metadata() throws -> [AVMetadataItem] {
    var items = [AVMetadataItem]()

    try info().forEach { key, value in
      guard let value = value as? (NSObjectProtocol & NSCopying),
        let identifier = AVMetadataIdentifier.from(key: key) else { return }

      if let value = identifier.format(value) {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        items.append(item)
      }
    }

    try? artworks().forEach {
      let item = AVMutableMetadataItem()
      item.identifier = .iTunesMetadataCoverArt
      item.value = $0
      items.append(item)
    }

    return items
  }
}

extension AudioFormatFlags {
  var bitDepth: Int {
    switch (self) {
    case kAppleLosslessFormatFlag_16BitSourceData:
      return 16
    case kAppleLosslessFormatFlag_20BitSourceData:
      return 20
    case kAppleLosslessFormatFlag_24BitSourceData:
      return 24
    case kAppleLosslessFormatFlag_32BitSourceData:
      return 32
    default:
      return 0
    }
  }
}

extension AVAudioFormat {

  var bitDepth: Int {
    let asbd = streamDescription
    if (asbd.pointee.mBitsPerChannel > 0) {
      return Int(asbd.pointee.mBitsPerChannel)
    }
    switch (asbd.pointee.mFormatID) {
    case kAudioFormatFLAC,
         kAudioFormatAppleLossless:
      return asbd.pointee.mFormatFlags.bitDepth
    default:
      return 0
    }
  }
}
