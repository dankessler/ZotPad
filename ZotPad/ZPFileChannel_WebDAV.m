
//
//  ZPFileChannel_WebDAV.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 18.3.2012.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import "ZPFileChannel_WebDAV.h"
#import "ZPPreferences.h"
#import "KeychainItemWrapper.h"
#import "ZPServerConnection.h"
#import "ASIHTTPRequest.h"
#import "ZPLogger.h"

//Unzipping and base64 decoding
#import "ZipArchive.h"
#import "QSStrings.h"

// This is needed bacause WebDAV requests contain actually two request. 

@interface ZPFileChannel_WebDAV_ProgressDelegate : NSObject <ASIHTTPRequestDelegate>{
    long long length;
    long long received;
}
-(id) initWithUIProgressView:(UIProgressView*)view;

@property (retain) UIProgressView* progressView;

@end

@implementation ZPFileChannel_WebDAV_ProgressDelegate

@synthesize progressView;

-(id) initWithUIProgressView:(UIProgressView*)view{
    self = [super init];
    progressView = view;
    length = 0;
    received = 0;
    return self;
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes{
    received += bytes;

    //Only update the progress view when the file has started downloading.
    
    if([request responseStatusCode] == 200){
        float progress = (float)received/length;
        [self.progressView setProgress:progress];
    }
}
- (void)request:(ASIHTTPRequest *)request incrementDownloadSizeBy:(long long)newLength{
    length += newLength;
}

@end

@implementation ZPFileChannel_WebDAV

- (id) init{
    self= [super init];
    progressDelegates = [[NSMutableDictionary alloc] init];
    return self;
}

-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    //Only My Library may be stored on WebDAV
    NSLog(@"Checking WebDAV");
    if([[ZPPreferences instance] useWebDAV]){
        
        NSLog(@"WebDAV is enabled. The library ID for item with key %@ is %@",
              attachment.key,
              attachment.libraryID);
        
        if([attachment.libraryID intValue]==1){
        
            NSLog(@"The item is from My Library, proceeding with WebDAV download");
            
            //Setup the request 
            NSString* WebDAVRoot = [[ZPPreferences instance] webDAVURL];
            NSString* key =  attachment.key;
            NSString* urlString = [WebDAVRoot stringByAppendingFormat:@"/%@.zip",key];
            NSURL *url = [NSURL URLWithString:urlString]; 
            
            NSLog(@"Downloading from WebDAV %@",urlString);
            
            ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url]; 
            
            [self linkAttachment:attachment withRequest:request];
            
            //Easier to just always use accurate progress. There should not be a significant performance penalty
            request.showAccurateProgress=TRUE;
            
            NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
            [request setDownloadDestinationPath:tempFile];

            //For some reason authentication using digest fails if persistent connections are in use
            [request setShouldAttemptPersistentConnection:NO];
            [request setShouldPresentAuthenticationDialog:YES];
            [request setUseKeychainPersistence:YES];
            [request setRequestMethod:@"GET"];
            [request setDelegate:self];
            [request setShowAccurateProgress:TRUE];
            [request startAsynchronous];
            
        }
    }
    // If WebDAV is not in use, just notify that we are done
    else [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
    
}
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        [request cancel];
        [self cleanupAfterFinishingAttachment:attachment];
    }
}
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment{
    
    ASIHTTPRequest* request = [self requestWithAttachment:attachment];
    
    if(request != NULL){
        ZPFileChannel_WebDAV_ProgressDelegate* progressDelegate;
        @synchronized(progressDelegates){
            progressDelegate = [progressDelegates objectForKey:[NSNumber numberWithInt: attachment]];
            
            if(progressDelegate == NULL){
                progressDelegate  = [[ZPFileChannel_WebDAV_ProgressDelegate alloc] initWithUIProgressView:progressView];
                [progressDelegates setObject:progressDelegate forKey:[NSNumber numberWithInt: attachment]];
            }
            else{
                progressDelegate.progressView = progressView;
            }
        }
        [request setDownloadProgressDelegate:progressDelegate];
    }
}

- (void)requestFinished:(ASIHTTPRequest *)request{
    ZPZoteroAttachment* attachment = [self attachmentWithRequest:request];
    
    NSString* tempFile; 

    if([attachment.linkMode intValue] == LINK_MODE_IMPORTED_FILE ){

    //Unzip the attachment
        ZipArchive* zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:[request downloadDestinationPath]];
        
        tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZP%@%i",attachment.key,[[NSDate date] timeIntervalSince1970]*1000000]];
        
        [zipArchive UnzipFileTo:tempFile overWrite:YES];
        [zipArchive UnzipCloseFile];
        
        //Use the first unzipped file
        tempFile = [tempFile stringByAppendingPathComponent:[[[NSFileManager defaultManager]contentsOfDirectoryAtPath:tempFile error:NULL] objectAtIndex:0]];
        
    }
    else {
        tempFile = [request downloadDestinationPath];
    }

    [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:tempFile usingFileChannel:self];
    
    [self cleanupAfterFinishingAttachment:attachment];
}

- (void)requestFailed:(ASIHTTPRequest *)request{
    NSError *error = [request error];
    NSLog(@"File download from Zotero server failed: %@",[error description]);

    ZPZoteroAttachment* attachment = [self attachmentWithRequest:request];
    
    //If there was an authentication issue, reauthenticat
    if(error.code == 3){
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Authentication failed"
                                                          message:@"Authenticating with WebDAV server failed."
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Disable WebDAV",nil];
        
        [message show];
    }
    else{
        [[ZPServerConnection instance] finishedDownloadingAttachment:attachment toFileAtPath:NULL usingFileChannel:self];
        [self cleanupAfterFinishingAttachment:attachment];
    } 
}

-(void) cleanupAfterFinishingAttachment:(ZPZoteroAttachment *)attachment{
    @synchronized(progressDelegates){
        [progressDelegates removeObjectForKey:[NSNumber numberWithInt: attachment]];
    }

}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //Disable webdav
    if(buttonIndex == 1){
        [[ZPPreferences instance] setUseWebDAV:FALSE];
    }
}

@end
