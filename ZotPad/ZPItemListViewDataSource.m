//
//  ZPItemListViewDataSource.m
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//


#import "ZPItemListViewDataSource.h"
#import "DTCoreText.h"
#import "OHAttributedLabel.h"
#import "ZPAttachmentIconImageFactory.h"
#import "ZPPreviewController.h"
#import "ZPServerConnectionManager.h"
#import "ZPCacheController.h"

#define SIZE_OF_TABLEVIEW_UPDATE_BATCH 25
#define SIZE_OF_DATABASE_UPDATE_BATCH 50

@implementation ZPItemListViewDataSource

@synthesize collectionKey = _collectionKey;
@synthesize libraryID =  _libraryID;
@synthesize searchString = _searchString;
@synthesize orderField = _orderField;
@synthesize sortDescending = _sortDescending;
@synthesize itemKeysShown = _itemKeysShown;
@synthesize targetTableView = _tableView;
@synthesize owner;

static ZPItemListViewDataSource* _instance;

+ (ZPItemListViewDataSource*) instance{
    if(_instance == NULL){
        _instance = [[ZPItemListViewDataSource alloc] init];
    }
    return _instance;
}


-(id)init{
    self= [super init];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyItemsAvailable:)
                                                 name:ZPNOTIFICATION_ITEMS_AVAILABLE
                                               object:nil];
    
    //Set default sort values
    _orderField = @"dateModified";
    _sortDescending = FALSE;
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/*
 Called from data layer to notify that there is data for this view and it can be shown
 */

- (void)clearTable{
    
    _invalidated = TRUE;
    
    @synchronized(_tableView){
        
        BOOL needsReload = [self tableView:_tableView numberOfRowsInSection:0]>1;
        
        _itemKeysNotInCache = [NSMutableArray array];
        _itemKeysShown = [NSArray array];
                
        //TODO: Investigate why a relaodsection call a bit below causes a crash. Then uncomment these both.
        //[_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        if(needsReload){
            [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
            //DDLogVerbose(@"Reloaded data (1). Number of rows now %i",[self tableView:_tableView  numberOfRowsInSection:0]);
        }
    }
}

- (void) configureCachedKeys:(NSArray*)array{
    
    @synchronized(_tableView){
        
        _itemKeysShown = array;
        [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
        //DDLogVerbose(@"Reloaded data (2). Number of rows now %i",[self tableView:_tableView  numberOfRowsInSection:0]);
        
    }
}


- (void) configureServerKeys:(NSArray*)uncachedItems{
    
    //Only update the uncached keys if we are still showing the same item key list
    _itemKeysNotInCache = [NSMutableArray arrayWithArray:uncachedItems];
    [_itemKeysNotInCache removeObjectsInArray:_itemKeysShown];
    _invalidated = FALSE;
    [self _performTableUpdates:FALSE];
    //DDLogVerbose(@"Configured uncached keys");
    
    
}


#pragma mark - Receiving data and updating the table view

-(void) _performTableUpdates:(BOOL)animated{
    
    //DDLogVerbose(@"Start table updates");
    //Only one thread at a time
    @synchronized(self){
        //Get a pointer to an array to know if another thread has changed this in the background
        NSArray* thisItemKeys = _itemKeysShown;
        
        //Copy the array to be safe from accessing it using multiple threads
        NSMutableArray* newItemKeysShown = [NSMutableArray arrayWithArray:_itemKeysShown];
        
        NSArray* newKeys = [ZPDatabase getItemKeysForLibrary:self.libraryID collectionKey:self.collectionKey
                                                                     searchString:[self.searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]orderField:self.orderField sortDescending:self.sortDescending];
        
        
        //If there is a new set of items loaded, return without performing any updates. 
        if(thisItemKeys != _itemKeysShown || _invalidated) return;
        
        //DDLogVerbose(@"Beging updating the table rows: Known keys befor update %i. Unknown keys %i. New keys %i",[_itemKeysShown count],[_itemKeysNotInCache count],[newKeys count]);
        
        @synchronized(_itemKeysNotInCache){
            [_itemKeysNotInCache removeObjectsInArray:newKeys];
        }
        
        NSInteger index=0;
        NSMutableArray* reloadIndices = [NSMutableArray array];
        NSMutableArray* insertIndices = [NSMutableArray array];
        
        for(NSString* newKey in newKeys){
            //If there is a new set of items loaded, return without performing any updates. 
            if(thisItemKeys != _itemKeysShown || _invalidated ) return;
            
            //First index contains a placeholder cell
            
            if([newItemKeysShown count] == index){
                // //DDLogVerbose(@"Adding item %@ at %i",newKey,index);
                [newItemKeysShown addObject:newKey];
                if(index==0) [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                else [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            }
            else if([newItemKeysShown objectAtIndex:index] == [NSNull null]){
                // //DDLogVerbose(@"Replacing NULL with %@ at %i",newKey,index);
                [newItemKeysShown replaceObjectAtIndex:index withObject:newKey];
                [reloadIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            }
            
            //There is something in the way, so we need to either insert or move
            else if(![newKey isEqualToString:[newItemKeysShown objectAtIndex:index]]){
                
                //We found that a shown key does not match the data on server
                
                NSInteger oldIndex = [newItemKeysShown indexOfObject:newKey];
                
                //If the new data cannot be found in the view, insert it
                if(oldIndex==NSNotFound){
                    //   //DDLogVerbose(@"Inserting %@ at %i",newKey,index);
                    [newItemKeysShown insertObject:newKey atIndex:index];
                    [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                }
                //Else move it
                else{
                    // //DDLogVerbose(@"Moving %@ from %i to %i",newKey,oldIndex,index);
                    
                    //Instead of performing a move operation, we are just replacing the old location with null. This because of thread safety.
                    
                    [newItemKeysShown replaceObjectAtIndex:oldIndex withObject:[NSNull null]];
                    [newItemKeysShown insertObject:newKey atIndex:index];
                    [insertIndices addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                    [reloadIndices addObject:[NSIndexPath indexPathForRow:oldIndex inSection:0]];
                }
            }
            index++;
        }
        
        //Add empty rows to the end if there are still unknown rows
        @synchronized(_itemKeysNotInCache){
            while([newItemKeysShown count]<([_itemKeysNotInCache count] + [newKeys count])){
                //            //DDLogVerbose(@"Padding with null %i (Unknown keys: %i, Known keys: %i)",[newItemKeysShown count],[_itemKeysNotInCache count],[newKeys count]);
                if([newItemKeysShown count]==0)
                    [reloadIndices addObject:[NSIndexPath indexPathForRow:0 inSection:0]];
                else{
                    [insertIndices addObject:[NSIndexPath indexPathForRow:[newItemKeysShown count] inSection:0]];
                }
                [newItemKeysShown addObject:[NSNull null]];
            }
        }
        
        @synchronized(_tableView){
            
            if(thisItemKeys != _itemKeysShown || _invalidated) return;
            
            _itemKeysShown = newItemKeysShown;
            
            NSNumber* tableLength = [NSNumber numberWithInt:[_itemKeysNotInCache count] + [newKeys count]];
            //DDLogVerbose(@"Items found from DB %i, items that are still uncached %i",[newKeys count],[_itemKeysNotInCache count]);
            if(animated){
                SEL selector = @selector(_performRowInsertions:reloads:tableLength:);
                NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:selector];
                NSInvocation* invocation  = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setTarget:self];
                [invocation setSelector:selector];
                
                //Set arguments
                [invocation setArgument:&insertIndices atIndex:2];
                [invocation setArgument:&reloadIndices atIndex:3];
                [invocation setArgument:&tableLength atIndex:4];
                
                
                [invocation performSelectorOnMainThread:@selector(invoke) withObject:NULL waitUntilDone:YES];
            }
            else{
                if([tableLength intValue]>[_itemKeysShown count]){
                    _itemKeysShown = [_itemKeysShown subarrayWithRange:NSMakeRange(0,[tableLength intValue])];
                }
                [_tableView performSelectorOnMainThread:@selector(reloadData) withObject:NULL waitUntilDone:YES];
            }
            //DDLogVerbose(@"End updating the table rows");
            /*
            if([_itemKeysNotInCache count] == 0){
                [_activityIndicator stopAnimating];   
            }
            */
            
        }
    }
}


-(void) _performRowInsertions:(NSArray*)insertIndexPaths reloads:(NSArray*)reloadIndexPaths tableLength:(NSInteger)tableLength{
    //DDLogVerbose(@"Modifying the table. Inserts %i Reloads %i, Max length %@, Item key array length %i",[insertIndexPaths count],[reloadIndexPaths count],tableLength,[_itemKeysShown count]);
    //    [_tableView beginUpdates];
    //DDLogVerbose(@"Insert index paths %@",insertIndexPaths);
    if([insertIndexPaths count]>0){
        [_tableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:_animations];   
    }
    //DDLogVerbose(@"Reload index paths %@",reloadIndexPaths);
    if([reloadIndexPaths count]>0){
        [_tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:_animations];   
    }
    
    if(tableLength<[_itemKeysShown count]){
        NSMutableArray* deleteIndexPaths = [NSMutableArray array];
        
        NSInteger max = [_itemKeysShown count];
        for(NSInteger i=tableLength;i<max;i++){
            [deleteIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
        
        _itemKeysShown = [_itemKeysShown subarrayWithRange:NSMakeRange(0,tableLength)];
        //DDLogVerbose(@"Delete index paths %@",deleteIndexPaths);
        //DDLogVerbose(@"Deletes %i",[deleteIndexPaths count]);
        
        [_tableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:_animations];
    }
    
    //    [_tableView endUpdates];
}

-(void) _updateRowForItem:(ZPZoteroItem*)item{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[_itemKeysShown indexOfObject:item.key] inSection:0];
    //Do not reload cell if it is selected
    if(! [[_tableView indexPathForSelectedRow] isEqual:indexPath]) [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:_animations];
}


-(void) notifyItemsAvailable:(NSNotification*)notification{
    
    NSArray* items = notification.object;
    //DDLogVerbose(@"Received item %@",item.fullCitation);
    
    @synchronized(self){
        
        BOOL found = FALSE;
        BOOL update = FALSE;
        @synchronized(_itemKeysNotInCache){
            
            for(ZPZoteroItem* item in items){
                DDLogVerbose(@"Checking if item should be displayed %@, %@",item.key,item.title);
                if([_itemKeysNotInCache containsObject:item.key]){
                    [_itemKeysNotInCache removeObject:item.key];
                    found=TRUE;
                }
                //DDLogVerbose(@"Item keys not in cache deacreased to %i after removing key %@",[_itemKeysNotInCache count],item.key);
                
                //Update the view if we have received sufficient number of new items
                update = update || ([_itemKeysNotInCache count] % SIZE_OF_DATABASE_UPDATE_BATCH ==0 ||
                          [_itemKeysShown count] == 0 ||
                          [_itemKeysShown lastObject]!=[NSNull null]);
                
            }
        }
        
        
        if(found){
            
            if(update){  
                _animations = UITableViewRowAnimationAutomatic;
                [self _performTableUpdates:TRUE];
            }
        }
        /*
        else if([_itemKeysShown containsObject:item.key]){
            //Update the row only if the full citation for this item has changed 
            @synchronized(_tableView){
                [self performSelectorOnMainThread:@selector(_updateRowForItem:) withObject:item waitUntilDone:YES];
            }
        }
        */
    }    
}
/*
 - (void) _refreshCellAtIndexPaths:(NSArray*)indexPaths{
 [_tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
 
 }
 */
#pragma mark - Table view data source and delegate methods


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    _tableView = aTableView;
    // Return the number of rows in the section. Initially there is no library selected, so we will just return an empty view
    NSInteger count=1;
    if(_itemKeysShown!=nil){
        count= MAX(1,[_itemKeysShown count]);
    }
    //DDLogVerbose(@"Item table has now %i rows",count);
    return count;
}


- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    _tableView = aTableView;

    //DDLogVerbose(@"Getting cell for row %i",indexPath.row);
    
    
    //If the data has become invalid, return a cell 
    
    UITableViewCell* cell;
    
    if(indexPath.row>=[_itemKeysShown count]){
        NSString* identifier;
        if(_libraryID==0){
            identifier = @"ChooseLibraryCell";   
        }
        else if(_invalidated){
            identifier = @"BlankCell";
        }
        else{
            identifier=@"NoItemsCell";
        }
        //DDLogVerbose(@"Cell identifier is %@",identifier);
        
        cell = [aTableView dequeueReusableCellWithIdentifier:identifier];
        if(cell == nil) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        
    }
    else{
        NSObject* keyObj = [_itemKeysShown objectAtIndex: indexPath.row];
        
        
        
        NSString* key;
        if(keyObj==[NSNull null] || keyObj==NULL){
            key=@"";
        }    
        else{
            key= (NSString*) keyObj;
        }    
            
        ZPZoteroItem* item=NULL;
        if(![key isEqualToString:@""]) item = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:key];
        
        if(item==NULL){
            cell = [aTableView dequeueReusableCellWithIdentifier:@"LoadingCell"]; 
            //DDLogVerbose(@"Cell identifier is LoadingCell");
            
            //Row number
            UILabel* rowNumber = (UILabel *) [cell viewWithTag:5];
            if(rowNumber != NULL) rowNumber.text=[NSString stringWithFormat:@"%i",indexPath.row+1];
        }
        else{
            
            cell = [aTableView dequeueReusableCellWithIdentifier:@"ZoteroItemCell"];
            //DDLogVerbose(@"Cell identifier is ZoteroItemCell");
            //DDLogVerbose(@"Item with key %@ has full citation %@",item.key,item.fullCitation);
            
            UILabel *titleLabel = (UILabel *)[cell viewWithTag:1];
            titleLabel.text = item.title;
            
            UILabel *authorsLabel = (UILabel *)[cell viewWithTag:2];
            
            //Show different things depending on what data we have
            if(item.creatorSummary!=NULL){
                if(item.year != 0){
                    authorsLabel.text = [NSString stringWithFormat:@"%@ (%i)",item.creatorSummary,item.year];
                }
                else{
                    authorsLabel.text = [NSString stringWithFormat:@"%@",item.creatorSummary];
                }
            }    
            else if(item.year!= 0){
                authorsLabel.text = [NSString stringWithFormat:@"No author (%i)",item.year];
            }
            
            //Publication as a formatted label
            
            OHAttributedLabel* publishedInLabel = (OHAttributedLabel*)[cell viewWithTag:3];
            
            
            
            if(publishedInLabel != NULL){
                
                publishedInLabel.automaticallyAddLinksForType = 0;
                
                NSString* publishedIn = item.publicationDetails;
                
                if(publishedIn == NULL){
                    publishedIn=@"";   
                }
                
                NSAttributedString* text = [[NSAttributedString alloc] initWithHTMLData:[publishedIn dataUsingEncoding:NSUTF8StringEncoding]  documentAttributes:NULL];
                
                //Font size of TTStyledTextLabel cannot be set in interface builder, so must be done here
                [publishedInLabel setFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]]];
                [publishedInLabel setAttributedText:text];
            }
            
            //Attachment icon
            
            UIImageView* articleThumbnail = (UIImageView *) [cell viewWithTag:4];
            
            //Remove subviews. These can be used when rendering.
            for(UIView* view in articleThumbnail.subviews) [view removeFromSuperview];
            
            //Check if the item has attachments and render a thumbnail from the first attachment PDF
            
            if(articleThumbnail!= NULL){
                if([item.attachments count] > 0){
                    
                    [articleThumbnail setHidden:FALSE];
                    
                    ZPZoteroAttachment* attachment = [item.attachments objectAtIndex:0];
                    
                    
                    //DDLogVerbose(@"ImageView for row %i is %i",indexPath.row,articleThumbnail);
                    
                    [ZPAttachmentIconImageFactory renderFileTypeIconForAttachment:attachment intoImageView:articleThumbnail];
                    // Enable or disable depending whether file is available or not
                    
                    if(attachment.fileExists || (attachment.linkMode == LINK_MODE_LINKED_URL && [ZPServerConnectionManager hasInternetConnection])){
                        articleThumbnail.alpha = 1;
                        articleThumbnail.userInteractionEnabled = TRUE;
                        
                        //If there is no gesture recognizer, create and add one
                        if(articleThumbnail.gestureRecognizers.count ==0){
                            [articleThumbnail addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(attachmentThumbnailPressed:)]];
                        }
                    }
                    else{
                        articleThumbnail.alpha = .3;
                        articleThumbnail.userInteractionEnabled = FALSE;
                    }
                }
                else{
                    articleThumbnail.hidden=TRUE;
                }
            }
            
            //Row number
            UILabel* rowNumber = (UILabel *) [cell viewWithTag:5];
            if(rowNumber != NULL) rowNumber.text=[NSString stringWithFormat:@"%i",indexPath.row+1];
        }
    }    
    if(cell == NULL || ! [cell isKindOfClass:[UITableViewCell class]]){
        [NSException raise:@"Invalid cell" format:@""];
    }

    return cell;
}

-(IBAction) attachmentThumbnailPressed:(id)sender{
    
    //Get the table cell.
    UITapGestureRecognizer* gr = (UITapGestureRecognizer*)  sender;
    UIView* imageView = [gr view];
    UITableViewCell* cell = (UITableViewCell* )[[imageView superview] superview];
    
    //Get the row of this cell
    NSInteger row = [_tableView indexPathForCell:cell].row;
    
    ZPZoteroItem* item = (ZPZoteroItem*) [ZPZoteroItem itemWithKey:[_itemKeysShown objectAtIndex:row]];
    
    ZPZoteroAttachment* attachment = [item.attachments objectAtIndex:0];
    
    if(attachment.linkMode == LINK_MODE_LINKED_URL && [ZPServerConnectionManager hasInternetConnection]){
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:attachment.url]];
    }
    else{
        _attachmentInQuicklook = attachment;
        [ZPPreviewController displayQuicklookWithAttachment:attachment source:self];
    }
}
-(UIView*) sourceViewForQuickLook{
    
    //If we have had a low memory condition, it is possible that views are not loaded
    
    if(! [owner isViewLoaded]){
        [owner loadView];
        [owner viewDidLoad];
    }
    
    // Because the user interface orientation may have changed, we need to layout subviews
    // TODO: Is it necessary to call layoutSubviews and viewWillAppear
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        UISplitViewController* root =  (UISplitViewController*) [UIApplication sharedApplication].delegate.window.rootViewController;
        [root viewWillAppear:NO];
        [root.view layoutSubviews];
        
        UIViewController* navigationController = (UIViewController*)[root.viewControllers lastObject];
        [navigationController viewWillAppear:NO];
        [navigationController.view layoutSubviews];
    }
    else {
        UINavigationController* root =  (UINavigationController*) [UIApplication sharedApplication].delegate.window.rootViewController;
        [root viewWillAppear:NO];
        [root.view layoutSubviews];
    }
    
    @synchronized(self){
        NSInteger index = [_itemKeysShown indexOfObject:_attachmentInQuicklook.parentKey];
        UITableViewCell* cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        UIView* ret = [cell viewWithTag:4];
        return ret;
    }
}
@end
