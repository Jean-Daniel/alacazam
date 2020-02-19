//
//  main.swift
//  alacazam
//
//  Created by Jean-Daniel Dupas on 17/02/2020.
//  Copyright © 2020 xooloo. All rights reserved.
//

import OSLog
import Foundation

import SPMUtility

func doWork(sources: [String], dest: String) {
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
    let processor = try FileProcessor(url: url, dest: URL(fileURLWithPath: dest))
    try processor.run {
      _ = processor // lifetime
      DispatchQueue.main.async {
        autoreleasepool {
          doWork(sources: Array(sources.dropFirst()), dest: dest)
        }
      }
    }
  } catch {
    print("[error] failed to read file: \(error.localizedDescription)")

    DispatchQueue.main.async {
      autoreleasepool { doWork(sources: Array(sources.dropFirst()), dest: dest) }
    }
  }
}

// MARK: - main
do {
  let parser = ArgumentParser(commandName: "alacazam",
                              usage: "alacazam",
                              overview: "convert audio files to alac")

  let output = parser.add(option: "--output",
                          shortName: "-o",
                          kind: String.self,
                          usage: "Output directory",
                          completion: .filename)

  let files = parser.add(positional: "sources",
                         kind: [String].self,
                         optional: false,
                         strategy: .upToNextOption,
                         usage: "Source files",
                         completion: ShellCompletion.filename)

  let argsv = Array(CommandLine.arguments.dropFirst())
  let parguments = try parser.parse(argsv)

  let dest = parguments.get(output) ?? "."

  if let sources = parguments.get(files) {
    autoreleasepool {
      doWork(sources: sources, dest: dest)
    }
  }

  CFRunLoopRun()
} catch ArgumentParserError.expectedValue(let value) {
  print("Missing value for argument \(value).")
} catch ArgumentParserError.expectedArguments(_, let stringArray) {
  print("Missing arguments: \(stringArray.joined()).")
} catch {
  print(error.localizedDescription)
}

