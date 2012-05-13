//
//  ZPPreferences.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZPPreferences : NSObject{
    NSInteger _metadataCacheLevel;
    NSInteger _attachmentsCacheLevel;
    NSInteger _mode;
    NSInteger _maxCacheSize;
}

@property (retain) NSString* OAuthKey;
@property (retain) NSString* userID;
@property (retain) NSString* username;
@property (retain) NSString* currentCacheSize;
@property (readonly) NSString* sambaShareName;
@property BOOL online;

@property BOOL useWebDAV;
@property BOOL useSamba;

+(ZPPreferences*) instance;
-(BOOL) cacheMetadataAllLibraries;
-(BOOL) cacheMetadataActiveLibrary;
-(BOOL) cacheMetadataActiveCollection;

-(BOOL) cacheAttachmentsAllLibraries;
-(BOOL) cacheAttachmentsActiveLibrary;
-(BOOL) cacheAttachmentsActiveCollection;
-(BOOL) cacheAttachmentsActiveItem;

-(BOOL) useCache;
-(BOOL) useDropbox;
-(NSString*) webDAVURL;

-(NSInteger) maxCacheSize;

-(void) resetUserCredentials;

-(void) reload;
-(void) checkAndProcessApplicationResetPreferences;

@end
