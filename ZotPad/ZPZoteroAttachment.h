//
//  ZPZoteroAttachment.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZPZoteroItem.h"
#import <QuickLook/QuickLook.h>


extern NSInteger const LINK_MODE_IMPORTED_FILE;
extern NSInteger const LINK_MODE_IMPORTED_URL;
extern NSInteger const LINK_MODE_LINKED_FILE;
extern NSInteger const LINK_MODE_LINKED_URL;

extern NSInteger const VERSION_SOURCE_DROPBOX;
extern NSInteger const VERSION_SOURCE_ZOTERO;
extern NSInteger const VERSION_SOURCE_WEBDAV;

@interface ZPZoteroAttachment : ZPZoteroDataObject <QLPreviewItem>{
    NSInteger _linkMode;
}

@property (retain) NSString* contentType;
@property (assign) NSInteger linkMode;
@property (assign) BOOL existsOnZoteroServer;
@property (assign) NSInteger attachmentSize;
@property (retain) NSString* lastViewed;
@property (retain) NSString* url;
@property (retain) NSString* filename;
@property (retain) NSString* charset;
@property (retain) NSString* itemKey;

// Needed for versioning

// This is the version identifier from Zotero server. We need this as well as versionIdentifier_server because the actual file can also come from Dropbox
@property (retain) NSString* md5;

@property (assign) NSInteger versionSource;
@property (retain) NSString* versionIdentifier_server;
@property (retain) NSString* versionIdentifier_local;

+(ZPZoteroAttachment*) attachmentWithKey:(NSString*) key;
+(ZPZoteroAttachment*) attachmentWithDictionary:(NSDictionary*) fields;

- (NSString*) fileSystemPath;
- (NSString*) fileSystemPath_modified;
- (NSString*) fileSystemPath_original;
- (BOOL) fileExists;
-(BOOL) fileExists_original;
-(BOOL) fileExists_modified;

-(NSString*) filenameZoteroBase64Encoded;

// The reason is required to enforce logging

-(void) purge:(NSString*) reason;
-(void) purge_original:(NSString*) reason;
-(void) purge_modified:(NSString*) reason;


-(void) moveFileFromPathAsNewOriginalFile:(NSString*) path;
-(void) moveFileFromPathAsNewModifiedFile:(NSString*) path;
-(void) moveModifiedFileAsOriginalFile;

// returns an object based on file system path
+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename;

// Helper functions
+(NSString*) md5ForFileAtPath:(NSString*)path;
+(NSString*) zoteroBase64Encode:(NSString*)filename;
+(NSString*) zoteroBase64Decode:(NSString*)filename;
-(void) logFileRevisions;

@end
