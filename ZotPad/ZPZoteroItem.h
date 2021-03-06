//
//  ZPZoteroItem.h
//  ZotPad
//
//  Created by Rönkkö Mikko on 11/23/11.
//  Copyright (c) 2011 Mikko Rönkkö. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "ZPZoteroDataObject.h"

@interface ZPZoteroItem : ZPZoteroDataObject{
    
    __strong NSArray* _creators;
    __strong NSArray* _attachments;
    __strong NSArray* _notes;
    __strong NSDictionary* _fields;

    BOOL _isStandaloneAttachment;
    BOOL _isStandaloneNote;
    
    NSArray* _collections;
}

@property (retain) NSString* dateAdded;
@property (retain) NSString* fullCitation;
@property (readonly) NSString* creatorSummary;
@property (readonly) NSString* publicationDetails;
@property (readonly) NSInteger year;
@property (readonly) NSString* itemType;
@property (assign) NSInteger numTags;
@property (retain) NSArray* notes;
@property (retain) NSArray* attachments;
@property (retain) NSArray* creators;
@property (retain) NSDictionary* fields;
@property (retain) NSString* itemKey;





+(void) dropCache;
+(ZPZoteroItem*) itemWithKey:(NSString*) key;
+(ZPZoteroItem*) itemWithDictionary:(NSDictionary*) fields;

-(NSArray*) collections;

- (NSString*) shortCitation;

@end
