//
//  main.swift
//  alacazam
//
//  Created by Jean-Daniel Dupas on 17/02/2020.
//  Copyright © 2020 xooloo. All rights reserved.
//

import OSLog
import Foundation

import ArgumentParser

func doWork(sources: [String], dest: String, options: FileProcessor.Options) {
  guard let file = sources.first else {
    // Asset writer is aync and we can't tell when it is done cleaning up temporary files.
    // It spawns its cleanup code on a background thread, so wait a little before exiting.
    print("Processing done. Cleaning up…")
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
      CFRunLoopStop(CFRunLoopGetMain())
    }
    return
  }
  print("Start processing \"\(file)\"")

  let url = URL(fileURLWithPath: file)
  do {
    let processor = try FileProcessor(url: url, dest: URL(fileURLWithPath: dest), options: options)
    try processor.run {
      _ = processor // lifetime
      DispatchQueue.main.async {
        autoreleasepool {
          doWork(sources: Array(sources.dropFirst()), dest: dest, options: options)
        }
      }
    }
  } catch {
    print("[error] failed to read file: \(error.localizedDescription)")

    DispatchQueue.main.async {
      autoreleasepool { doWork(sources: Array(sources.dropFirst()), dest: dest, options: options) }
    }
  }
}

// MARK: - main
struct Alacazam: ParsableCommand {

  static var configuration = CommandConfiguration(
    commandName: "alacazam",
    abstract: "Convert audio files to alac."
  )

  @Argument(help: "input files")
  var files: [String] = []

  @Flag(name: [.short, .long], help: "compress files in AAC")
  var compress: Bool = false

  @Option(name: [.short, .long, .customLong("bps")], help: "bit per sample. Defaults to input file bps.")
  var bitPerSample: Int = -1

  @Option(name: [.short, .customLong("output")], help: "Output directory.")
  var outputDir: String = "."

  mutating func validate() throws {
    guard files.count >= 1 else {
      throw ValidationError("Please specify at least 1 input file.")
    }
  }

  mutating func run() throws {
    autoreleasepool {
      let options = FileProcessor.Options(compress: compress, bitPerSample: bitPerSample)
      doWork(sources: files, dest: outputDir, options: options)
    }

    CFRunLoopRun()
  }
}

Alacazam.main()
