//
//  ZPZoteroAttachment.m
//  ZotPad
//
//  Created by Rönkkö Mikko on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//


// TODO: Implement linked files or at least some kind of info that they are not supported

#import "ZPZoteroAttachment.h"

NSInteger const LINK_MODE_IMPORTED_FILE = 0;
NSInteger const LINK_MODE_IMPORTED_URL = 1;
NSInteger const LINK_MODE_LINKED_FILE = 2;
NSInteger const LINK_MODE_LINKED_URL = 3;

@implementation ZPZoteroAttachment


@synthesize mimeType;
@synthesize lastViewed;
@synthesize linkMode;
@synthesize attachmentSize;
@synthesize existsOnZoteroServer;

+(id) dataObjectWithDictionary:(NSDictionary *)fields{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:fields ];
    [dict setObject:@"attachment" forKey:@"itemType"];
    ZPZoteroAttachment* attachment = (ZPZoteroAttachment*) [super dataObjectWithDictionary:dict];
    
    //Set some default values
    if(attachment.existsOnZoteroServer == nil){
        attachment.existsOnZoteroServer = [NSNumber numberWithBool:NO];   
    }
    
    return attachment;
}


// An alias for setParentCollectionKey
- (void) setParentKey:(NSString*)key{
    [self setParentItemKey:key];    
}

- (void) setParentItemKey:(NSString*)key{
    _parentItemKey = key; 
}
- (NSString*) parentItemKey{
    if(_parentItemKey == NULL){
        return _key;
    }
    else{
        return _parentItemKey;
    }
}

+(ZPZoteroAttachment*) dataObjectForAttachedFile:(NSString*) filename{

    //Strip the file ending
    filename = [[filename lastPathComponent] stringByDeletingPathExtension];
    
    //Get the key from the filename
    NSString* key =[[filename componentsSeparatedByString: @"_"] lastObject];
    
    return (ZPZoteroAttachment*) [self dataObjectWithKey:key];
    
}

- (NSString*) fileSystemPath{
    
    NSRange lastPeriod = [[super title] rangeOfString:@"." options:NSBackwardsSearch];
    
    NSString* path;
    if(lastPeriod.location == NSNotFound) path = [[super title] stringByAppendingFormat:@"_",_key];
    else path = [[super title] stringByReplacingCharactersInRange:lastPeriod
                                                                    withString:[NSString stringWithFormat:@"_%@.",_key]];
    return  [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:path];

}

- (NSArray*) creators{
    return [NSArray array];
}
- (NSDictionary*) fields{
    return [NSDictionary dictionary];
}

-(NSString*) itemType{
    return @"attachment";
}

- (NSArray*) attachments{
    
    return [NSArray arrayWithObject:self];
}

- (void) setAttachments:(NSArray *)attachments{
}

//If an attachment is updated, delete the old attachment file
- (void) setServerTimestamp:(NSString*)timestamp{
    [super setServerTimestamp:timestamp];
    if(![_serverTimestamp isEqual:_cacheTimestamp] && [self fileExists]){
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath: [self fileSystemPath] error:&error];   
    }
    
}

-(BOOL) fileExists{
    //The title must not be null
    if(self.title == nil){
        [NSException raise:@"Title of an item cannot be null" format:@""];
    }
    NSString* fsPath = [self fileSystemPath];
    if(fsPath == NULL)
        return false;
    else
        return ([[NSFileManager defaultManager] fileExistsAtPath:fsPath]);
}
@end

