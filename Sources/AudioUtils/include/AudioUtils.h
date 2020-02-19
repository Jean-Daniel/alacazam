//
//  AudioUtils.h
//  alacazam
//
//  Created by Jean-Daniel Dupas on 18/02/2020.
//  Copyright © 2020 xooloo. All rights reserved.
//

#ifndef AudioUtils_h
#define AudioUtils_h

#import <Foundation/Foundation.h>

#import <CoreAudioTypes/CoreAudioTypes.h>

@interface NSData (CoreAudio)
- (instancetype)initWithAudioChannelLayout:(const AudioChannelLayout *)layout;
@end

NSData *encodeTrackNumber(uint32_t num, uint32_t count);

#endif /* AudioUtils_h */
