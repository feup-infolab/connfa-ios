//
//  DCSpeakersDetailViewController.m
//  DrupalCon
//
//  Created by Volodymyr Hyrka on 8/27/14.
//  Copyright (c) 2014 Lemberg Solution. All rights reserved.
//

#import "DCSpeakersDetailViewController.h"
#import "NSDate+DC.h"

#import "DCSpeaker+DC.h"
#import "DCEvent+DC.h"
#import "DCTimeRange+DC.h"
#import "DCTrack+DC.h"
#import "DCLevel+DC.h"

#import "DCDescriptionTextCell.h"
#import "DCSpeakerHeaderCell.h"
#import "DCSpeakerEventCell.h"
#import "UIWebView+DC.h"
#import "UIConstants.h"
#import "UIImageView+WebCache.h"

@interface DCSpeakersDetailViewController ()<UIWebViewDelegate>

@property (nonatomic, strong) NSArray * events;
@property (nonatomic, weak) IBOutlet UITableView * speakerDetailTbl;
@property (nonatomic, strong) CloseCallback closeCallback;
@property (nonatomic, strong) NSIndexPath *lastIndexPath;
@property (nonatomic, strong) NSMutableDictionary *cellsHeight;
@end

@implementation DCSpeakersDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigatorBarStyle = EBaseViewControllerNatigatorBarStyleTransparrent;
    _events = [_speaker.events allObjects];
    self.cellsHeight = [NSMutableDictionary dictionary];

}

- (void)viewWillAppear:(BOOL)animated
{
    if (self.navigationController)
    {
        self.navigatorBarStyle = EBaseViewControllerNatigatorBarStyleNormal;
        [super viewWillAppear:animated];
        self.title = @"Speaker Profile";
    }
    else
    {
        //TODO: refactor!
        UIView * navigatorsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        [navigatorsContainer setBackgroundColor:NAV_BAR_COLOR];
        [self.view addSubview:navigatorsContainer];
        
        UIButton* backButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [backButton addTarget:self action:@selector(onBack) forControlEvents:UIControlEventTouchUpInside];
        [backButton setFrame:CGRectMake(0, 0, 60, 64)];
        [backButton setExclusiveTouch:YES];
        [backButton setImage:[UIImage imageNamed:@"back_arrow"] forState:UIControlStateNormal];
        [backButton setTitle:@"Back" forState:UIControlStateNormal];
        [backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [backButton setTintColor:[UIColor whiteColor]];
        [navigatorsContainer addSubview:backButton];
        
        UILabel * titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 64)];
        [titleLbl setTextAlignment:NSTextAlignmentCenter];
        [titleLbl setTextColor:[UIColor whiteColor]];
        [titleLbl setText:@"Speaker Profile"];
        [titleLbl setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:21]];
        [navigatorsContainer addSubview:titleLbl];
        
        [_speakerDetailTbl setFrame:CGRectMake(0, 44, 320, self.view.bounds.size.height-44)];
    }
}

-(void)onBack
{
    
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.closeCallback) {
        self.closeCallback();
    }
}
- (void)didCloseWithCallback:(CloseCallback)callback
{
    self.closeCallback = callback;
}

#pragma mark - UITableView Delegate/DataSourse methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _events.count + 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0)
        return [DCSpeakerHeaderCell cellHeight];
    
    else if ([self isLastRow:indexPath.row])
        return [self heightForDescriptionTextCell];
    
    else
        return [DCSpeakerEventCell cellHeight];
}

- (float)heightForDescriptionTextCell
{
    float descriptionCellHeight = [DCDescriptionTextCell cellHeightForText:_speaker.characteristic];;
    if (self.lastIndexPath && [self.cellsHeight objectForKey:self.lastIndexPath]) {
        descriptionCellHeight = [[self.cellsHeight objectForKey:self.lastIndexPath] floatValue];
    }
    return descriptionCellHeight;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdEvent = @"cellId_SpeakersEvent";
    static NSString *cellIdHeader = @"cellId_SpeakersHeader";
    static NSString *cellIdBottom = @"cellId_SpeakersBottom";
    
    UITableViewCell *cell;
    
    if (indexPath.row == 0)
    {
        DCSpeakerHeaderCell *_cell = (DCSpeakerHeaderCell*)[tableView dequeueReusableCellWithIdentifier:cellIdHeader];
        [self fillSpeakerHeaderCell:_cell];
//        [_cell.pictureImg sd_setImageWithURL:[NSURL URLWithString:_speaker.avatarPath]
//                            placeholderImage:[UIImage imageNamed:@"avatar_placeholder"]
//                                   completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
//                                       dispatch_async(dispatch_get_main_queue(), ^{
//                                           [_cell setNeedsDisplay];
//                                       });
//                                       
//        }];
//
//        
//        [_cell.nameLbl setText:_speaker.name];
//        [_cell.organizationLbl setText:_speaker.organizationName];
//        [_cell.jobTitleLbl setText:_speaker.jobTitle];
        cell = _cell;
    }
    
    else if ([self isLastRow:indexPath.row])
    {
        DCDescriptionTextCell * _cell = (DCDescriptionTextCell*)[tableView dequeueReusableCellWithIdentifier:cellIdBottom];
        _cell.descriptionWebView.delegate = self;
        self.lastIndexPath = indexPath;
        [_cell.descriptionWebView loadHTMLString:_speaker.characteristic];
        cell = _cell;
    }
    
    else // all events cells
    {
        DCEvent * event = _events[indexPath.row-1];
        DCSpeakerEventCell * _cell = (DCSpeakerEventCell*)[tableView dequeueReusableCellWithIdentifier:cellIdEvent];
        
        //        _cell.favorite = [event.favorite boolValue];
        [_cell setSelected:[event.favorite boolValue]];
        [_cell favoriteButtonDidSelected:^(UITableViewCell *cell, BOOL isSelected) {
            [self updateFavoriteItemsInIndexPath:[self.speakerDetailTbl indexPathForCell:cell]
                                       withValue:isSelected];
        }];
        [_cell.nameLabel setText:event.name];
        [_cell.eventDateValueLbl setText:[event.date stringForSpeakerEventCell]];
        [_cell.eventTimeValueLbl setText:[event.timeRange stringValue]];
        [_cell setTrack:[[event.tracks allObjects].firstObject name]];
        [_cell setLevel:event.level.name];
        cell = _cell;
    }
    
    return cell;
}

- (void)fillSpeakerHeaderCell:(DCSpeakerHeaderCell *)newCell
{
    
    [newCell.pictureImg sd_setImageWithURL:[NSURL URLWithString:_speaker.avatarPath]
                        placeholderImage:[UIImage imageNamed:@"avatar_placeholder"]
                               completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [newCell setNeedsDisplay];
                                   });
                                   
                               }];
    
    
    [newCell.nameLbl setText:_speaker.name];
    [newCell.organizationLbl setText:_speaker.organizationName];
    [newCell.jobTitleLbl setText:_speaker.jobTitle];
    if ([_speaker.webSite length]) {
        [newCell.webButton setHidden:NO];
        [newCell.webButton addTarget:self action:@selector(openWebSite:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [newCell.webButton setHidden:YES];
    }
    
    if ([_speaker.twitterName length]) {
        [newCell.twitterButton addTarget:self action:@selector(openTwitterSite:) forControlEvents:UIControlEventTouchUpInside];
        [newCell.twitterButton setHidden:NO];
    } else {
         [newCell.twitterButton setHidden:YES];
    }
    
}

- (void)openWebSite:(id)sender
{
    [[UIApplication sharedApplication]
     openURL:[NSURL URLWithString:_speaker.webSite]];
}

- (void)openTwitterSite:(id)sender
{
    NSString *twitter = [NSString stringWithFormat:@"http://twitter.com/%@", _speaker.twitterName];
    [[UIApplication sharedApplication]
     openURL:[NSURL URLWithString:twitter]];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (![self.cellsHeight objectForKey:self.lastIndexPath]) {
        float height = [[webView stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"] floatValue];
        [self.cellsHeight setObject:[NSNumber numberWithFloat:height] forKey:self.lastIndexPath];
        [self updateCellAtIndexPath];
    }
    
}

-(BOOL) webView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType {
    if ( inType == UIWebViewNavigationTypeLinkClicked ) {
        [[UIApplication sharedApplication] openURL:[inRequest URL]];
        return NO;
    }
    
    return YES;
}

- (void)updateCellAtIndexPath
{
    [self.speakerDetailTbl beginUpdates];
    [self.speakerDetailTbl reloadRowsAtIndexPaths:@[self.lastIndexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.speakerDetailTbl endUpdates];
}


- (void)updateFavoriteItemsInIndexPath:(NSIndexPath *)anIndexPath
                             withValue:(BOOL)isFavorite {
    DCEvent * event = [self eventFromIndexPath:anIndexPath];
    event.favorite = [NSNumber numberWithBool:isFavorite];
    if (isFavorite) {
        [[DCMainProxy sharedProxy]
         addToFavoriteEventWithID:event.eventID];
    } else {
        [[DCMainProxy sharedProxy]
         removeFavoriteEventWithID:event.eventID];
    }
    
}

- (DCEvent *)eventFromIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row || [self isLastRow:indexPath.row]) {
        return [self.events firstObject];
    } else {
        return [self.events objectAtIndex:indexPath.row];
    }
}
#pragma mark -

- (BOOL)isLastRow:(NSInteger)row
{
    return (row == _events.count + 1);
}

@end