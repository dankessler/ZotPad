//
//  ZPMasterItemListViewController.h
//  ZotPad
//
//  Created by Mikko Rönkkö on 7/19/12.
//  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPItemListViewDataSource.h"
#import "ZPItemDetailViewController.h"

@interface ZPMasterItemListViewController : UITableViewController{
    ZPItemListViewDataSource* _dataSource;
    
}

@property (retain) ZPItemDetailViewController* detailViewController;

@end
