//
//  main.m
//  timecodereader
//
//  Created by Keyvan Fatehi on 12/31/20.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include "libTC.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: timecodereader <filepath>\n");
            return 0;
        }

        NSString *filePath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
        if (! [[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            fprintf(stderr, "file not found\n");
            return 1;
        }
//        fprintf(stderr, "target: %s\n", argv[1]);
        AVAsset *_asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];
        [_asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [_asset statusOfValueForKey:@"tracks" error:&error];

            switch (tracksStatus) {
                case AVKeyValueStatusUnknown: {
                    fprintf(stderr, "AVKeyValueStatusUknown\n");
                    exit(1);
                    break;
                }
                case AVKeyValueStatusLoading: {
                    fprintf(stderr, "AVKeyValueStatusLoading\n");
                    exit(1);
                    break;
                }
                case AVKeyValueStatusLoaded: {
//                    fprintf(stderr, "AVKeyValueStatusLoaded\n");
                    break;
                }
                case AVKeyValueStatusFailed: {
                    fprintf(stderr, "AVKeyValueStatusFailed\n");
                    exit(1);
                    break;
                }
                case AVKeyValueStatusCancelled: {
                    fprintf(stderr, "AVKeyValueStatusCancelled\n");
                    exit(1);
                    break;
                }
            }
            
            // Now tracks is available
//            NSLog(@" total tracks %@", _asset.tracks);
            int32_t timeStampFrame = 0;
            float frameRate = 0;
//            NSLog(@"tracks loaded");
            for (AVAssetTrack * track in [_asset tracks]) {
//                NSLog(@"tracks");

                if ([[track mediaType] isEqualToString:AVMediaTypeTimecode]) {
//                    NSLog(@"timecode track");
                    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:_asset error:nil];
                    AVAssetReaderTrackOutput *assetReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:nil];
                    if ([assetReader canAddOutput:assetReaderOutput]) {
                        [assetReader addOutput:assetReaderOutput];
                        if ([assetReader startReading] == YES) {
                            int count = 0;
                            //  Special thanks to Martin Delille
                            //  https://stackoverflow.com/questions/12083325/how-to-get-the-start-timecode-smpte-of-a-quicktime-movie-in-objective-c-in-64
                            while ( [assetReader status]==AVAssetReaderStatusReading ) {
                                CMSampleBufferRef sampleBuffer = [assetReaderOutput copyNextSampleBuffer];
                                if (sampleBuffer == NULL) {
                                    if ([assetReader status] == AVAssetReaderStatusFailed)
                                        break;
                                    else
                                        continue;
                                }
                                count++;
            
                                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                                size_t length = CMBlockBufferGetDataLength(blockBuffer);
            
                                if (length>0) {
                                    unsigned char *buffer = malloc(length);
                                    memset(buffer, 0, length);
                                    CMBlockBufferCopyDataBytes(blockBuffer, 0, length, buffer);
                                     for (int i=0; i<length; i++) {
                                        timeStampFrame = (timeStampFrame << 8) + buffer[i];
                                    }
            
                                    free(buffer);
                                }
            
                                CFRelease(sampleBuffer);
                            }
            
                            if (count == 0) {
//                                NSLog(@"No sample in the timecode track: %@", [assetReader error]);
                            }
            
//                            NSLog(@"Processed %d sample", count);
            
                        }
            
                    }
            
                    if ([assetReader status] != AVAssetReaderStatusCompleted)
                        [assetReader cancelReading];
                }
                
                if ([[track mediaType] isEqualToString:AVMediaTypeVideo]) {
                    CMTime frameDuration = track.minFrameDuration;
                    frameRate = frameDuration.timescale/(float)frameDuration.value;
                }

            } // end looping through tracks "(*track went out of scope)"

            // Special Thanks to Adrien Gesta-Fline
            // https://github.com/agfline/tcCoca
            struct timecode tc;
            uint8_t isDrop = 0;
            enum TC_FORMAT tc_fmt = tc_fps2format(frameRate, isDrop);
            tc_set_by_frames( &tc, timeStampFrame, tc_fmt );
            printf("%s\n", tc.string);
            exit(EXIT_SUCCESS);
        }];
        dispatch_main();
    }
}
