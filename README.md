# alacazam

A simple command line tool to convert audio file to Apple Lossless.
It is mainly designed to transcode FLAC files into m4a file.

`avconvert` supports only a fixed set of preset, and `PresetAppleM4A` convert the source file to AAC, and so can't be used for lossless convertion.

`afconvert` mostly do the job but has 2 major drawback.
  * It does not preserve the source bit depth and so the later must be specified explicitly to avoid creating bigger files.
  * It completly ignore file metadata.
  
  All this issues also surface in the Apple Frameworks APIs. AVFoundation is unsable to extract metadata from FLAC files, and CoreAudio is unable to write mp4 file with metadata.
  This tools try to mix both APIs to workaround these limitations.
  
  Note: It uses the CoreAudio AudioFile API to read metadata, which supports only a subset of what is possible to store in an Audio File (and support only a single artwork).
  
