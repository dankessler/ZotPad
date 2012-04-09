//
//  ZPServerConnection.h
//  ZotPad
//
//  Handles communication with Zotero server. Used as a singleton.
//
//  Created by Rönkkö Mikko on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZPAuthenticationDialog.h"
#import "ZPServerResponseXMLParser.h"
#import "ZPZoteroItem.h"
#import "ZPZoteroCollection.h"
#import "ZPZoteroLibrary.h"
#import "ZPZoteroAttachment.h"
#import "ZPFileChannel.h"

@interface ZPServerConnection : NSObject{
        
    NSInteger _activeRequestCount;
    NSArray* _fileChannels;
}

// This class is used as a singleton
+ (ZPServerConnection*) instance;

// Check if the connection is already authenticated
- (BOOL) authenticated;

- (BOOL) hasInternetConnection;

// Methods to get data from the server
-(NSArray*) retrieveLibrariesFromServer;
-(NSArray*) retrieveCollectionsForLibraryFromServer:(NSNumber*)libraryID;

-(NSArray*) retrieveItemsFromLibrary:(NSNumber*)libraryID itemKeys:(NSArray*)keys;

-(NSArray*) retrieveKeysInContainer:(NSNumber*)libraryID collectionKey:(NSString*)key;
-(NSArray*) retrieveKeysInContainer:(NSNumber*)libraryID collectionKey:(NSString*)collectionKey searchString:(NSString*)searchString orderField:(NSString*)orderField sortDescending:(BOOL)sortDescending;
    
-(NSString*) retrieveTimestampForContainer:(NSNumber*)libraryID collectionKey:(NSString*)key;
-(NSArray*) retrieveAllItemKeysFromLibrary:(NSNumber*)libraryID;

//This retrieves single item details and notes and attachments associated with that item
-(ZPZoteroItem*) retrieveSingleItemDetailsFromServer:(ZPZoteroItem*)item;

// Asynchronous downloading of files
-(void) startDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) finishedDownloadingAttachment:(ZPZoteroAttachment*)attachment toFileAtPath:(NSString*) tempFile usingFileChannel:(ZPFileChannel*)fileChannel;
-(void) cancelDownloadingAttachment:(ZPZoteroAttachment*)attachment;
-(void) useProgressView:(UIProgressView*) progressView forAttachment:(ZPZoteroAttachment*)attachment;

-(BOOL) canUploadVersionForAttachment:(ZPZoteroAttachment*)attachment;

-(void) downloadAttachmentFromZoteroServer:(ZPZoteroAttachment*)attachment toTempFile:(NSString*)filePath withUIProgressView:(UIProgressView*) progressView;


@end
