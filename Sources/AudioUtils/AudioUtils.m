//
//  AudioUtils.m
//  alacazam
//
//  Created by Jean-Daniel Dupas on 18/02/2020.
//  Copyright © 2020 xooloo. All rights reserved.
//

#import "AudioUtils.h"

@implementation NSData (CoreAudio)

- (instancetype)initWithAudioChannelLayout:(const AudioChannelLayout *)layout {
  size_t length = sizeof(*layout) - sizeof(AudioChannelDescription);
  length += layout->mNumberChannelDescriptions * sizeof(AudioChannelDescription);
  return [self initWithBytes:layout length:length];
}

@end

NSData *encodeTrackNumber(uint32_t num, uint32_t count) {
  uint8_t buffer[8] = {};
  OSWriteBigInt32(buffer, 0, num);
  OSWriteBigInt16(buffer, 4, count);
  return [[NSData alloc] initWithBytes:buffer length:8];
}
