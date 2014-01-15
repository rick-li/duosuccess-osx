//
//  DsMusicPlayer.m
//  duosuccess
//
//  Created by Rick Li on 12/12/13.
//  Copyright (c) 2013 Rick Li. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "DsMusicPlayer.h"

@interface DsMusicPlayer ()


@property long elapsed;
@property long remains;

@end

@implementation DsMusicPlayer

@synthesize mySequence;
@synthesize player;
@synthesize processingGraph     = _processingGraph;
@synthesize samplerUnit         = _samplerUnit;
@synthesize ioUnit              = _ioUnit;
@synthesize delegate;
@synthesize elapsed;
@synthesize remains;

@synthesize isPlaying;

+ (id)sharedInstance {
    static DsMusicPlayer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        sharedInstance = [[self alloc] init];
        [sharedInstance initialize];
    });
    
    [sharedInstance setupAudioSession];
    [sharedInstance createAUGraph];
//    [sharedInstance postInitGragh];
    
    return sharedInstance;
}

int oneHour;

NSTimer *oneHourTimer;

- (void) initialize{
    oneHour = 60 * 60;
    
//        oneHour = 10 ;
    isPlaying = false;
}

- (void) playMedia:(NSString *)midPath{
    isPlaying = true;
    elapsed = 0;
    remains = oneHour+452;
    [self stopMedia];
    NewMusicSequence(&mySequence);
    NSURL * midiFileURL = [NSURL fileURLWithPath:midPath];
    MusicSequenceFileLoad(mySequence, (__bridge CFURLRef)midiFileURL, 0, kMusicSequenceLoadSMF_ChannelsToTracks);
    
    MusicSequenceSetAUGraph(mySequence, _processingGraph);
    
    [self setLoop:mySequence];
    [self doStartMidi];

//    enum {
//        kMidiMessage_ControlChange                 = 0xB,
//        kMidiMessage_ProgramChange                 = 0xC,
//        kMidiMessage_BankMSBControl         = 0,
//        kMidiMessage_BankLSBControl                = 32,
//        kMidiMessage_NoteOn                         = 0x9
//    };
//    
//    UInt8 midiChannelInUse = 0;
//    // we're going to play an octave of MIDI notes: one a second
//    for (int i = 0; i < 13; i++) {
//        UInt32 noteNum = i + 60;
//        UInt32 onVelocity = 127;
//        UInt32 noteOnCommand =         kMidiMessage_NoteOn << 4 | midiChannelInUse;
//        
//        NSLog (@"Playing Note: Status: 0x%u, Note: %u ", noteOnCommand, noteNum);
//        
//        MusicDeviceMIDIEvent(_samplerUnit, noteOnCommand, noteNum, onVelocity, 0);
//        
//        // sleep for a second
//        usleep (1 * 1000 * 1000);
//        
//        MusicDeviceMIDIEvent(_samplerUnit, noteOnCommand, noteNum, 0, 0);
//    }

    
}

// Set up the audio session for this app.
- (BOOL) setupAudioSession
{
//    NSLog(@"--- setupAudioSession ---");
//    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//    [audioSession setDelegate: self];
//    
//    //Assign the Playback category to the audio session.
//    NSError *audioSessionError = nil;
//    [audioSession setCategory: AVAudioSessionCategoryPlayback error: &audioSessionError];
//    if (audioSessionError != nil) {NSLog (@"Error setting audio session category."); return NO;}
//    
//    
//    // Activate the audio session
//    [audioSession setActive: YES error: &audioSessionError];
//    if (audioSessionError != nil) {NSLog (@"Error activating the audio session."); return NO;}

    return YES;
}



- (void)doStartMidi{
    NSLog(@"do start midi");
    
    NewMusicPlayer(&player);
    MusicPlayerSetSequence(player, mySequence);
    MusicPlayerPreroll(player);
    MusicPlayerStart(player);
 
}

- (void)setLoop:(MusicSequence)sequence {
    UInt32 tracks;
    
    if (MusicSequenceGetTrackCount(sequence, &tracks) != noErr)
        NSLog(@"track size is %d", (int)tracks);
    
    for (UInt32 i = 0; i < tracks; i++) {
        MusicTrack track = NULL;
        MusicTimeStamp trackLen = 0;
        
        UInt32 trackLenLen = sizeof(trackLen);
        MusicSequenceGetIndTrack(sequence, i, &track);
        
        MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &trackLen, &trackLenLen);
        
        if(trackLen >= oneHour){
            MusicTrackLoopInfo loopInfo = { trackLen, 1 };
            MusicTrackSetProperty(track, kSequenceTrackProperty_LoopInfo, &loopInfo, sizeof(loopInfo));

        }else{
            MusicTrackLoopInfo loopInfo = { trackLen, 10 };
            MusicTrackSetProperty(track, kSequenceTrackProperty_LoopInfo, &loopInfo, sizeof(loopInfo));

        }

        NSLog(@"track length is %f", trackLen);
    }
}

- (void) stopMedia{
    NSLog(@"Stopping music");
    isPlaying = false;
    if(player == nil ){
        return;
    }
    Boolean isPlayerPlaying = FALSE;
    MusicPlayerIsPlaying(player, &isPlayerPlaying);
    if(!isPlayerPlaying){
        NSLog(@"not playing music, no need to stop.");
        return;
    }
    
    OSStatus result = noErr;
    
    result = MusicPlayerStop(player);
    
    UInt32 trackCount;
    MusicSequenceGetTrackCount(mySequence, &trackCount);
    
    MusicTrack track;
    for(int i=0;i<trackCount;i++)
    {
        MusicSequenceGetIndTrack (mySequence,0,&track);
        result = MusicSequenceDisposeTrack(mySequence, track);
        
    }
    
    result = DisposeMusicPlayer(player);
    result = DisposeMusicSequence(mySequence);

    

}



-(OSStatus) loadFromDLSOrSoundFont: (NSURL *)bankURL withPatch: (int)presetNumber {
    
    OSStatus result = noErr;
    
    // fill out a bank preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge CFURLRef) bankURL;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetNumber;
    
    
    
    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(self.samplerUnit,
                                  kAUSamplerProperty_LoadPresetFromBank,
                                  kAudioUnitScope_Global,
                                  0,
                                  &bpdata,
                                  sizeof(bpdata));
    
    
    
    // check for errors
    NSCAssert (result == noErr,
               @"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
               (int) result,
               (const char *)&result);
    
    return result;
}


- (BOOL) createAUGraph {
    OSStatus result = noErr;
    AUNode samplerNode, ioNode;
    result = NewAUGraph (&_processingGraph);
    AudioComponentDescription cd = {};
    cd.componentManufacturer     = kAudioUnitManufacturer_Apple;
    cd.componentType = kAudioUnitType_MusicDevice;
    cd.componentSubType = kAudioUnitSubType_DLSSynth;
    result = AUGraphAddNode (_processingGraph, &cd, &samplerNode);
    cd.componentType = kAudioUnitType_Output;  // Output
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;  // Output to speakers
    
    // Add the Output unit node to the graph
    result = AUGraphAddNode (_processingGraph, &cd, &ioNode);
    result = AUGraphOpen (_processingGraph);
    result = AUGraphConnectNodeInput (_processingGraph, samplerNode, 0, ioNode, 0);
    result = AUGraphNodeInfo (_processingGraph, samplerNode, 0, &_samplerUnit);
    result = AUGraphNodeInfo (_processingGraph, ioNode, 0, &_ioUnit);
    
    UInt32 maximumFramesPerSlice = 4096;
    
    AudioUnitSetProperty (
                          _samplerUnit,
                          kAudioUnitProperty_MaximumFramesPerSlice,
                          kAudioUnitScope_Global,
                          0,                        // global scope always uses element 0
                          &maximumFramesPerSlice,
                          sizeof (maximumFramesPerSlice)
                          );
    
    if (_processingGraph) {
        
        //NSLog(@"initialize audio process graph");
        // Initialize the audio processing graph.
        result = AUGraphInitialize (_processingGraph);
        AUGraphStart(_processingGraph);
        //      CAShow (processingGraph);
    }
}


@end
