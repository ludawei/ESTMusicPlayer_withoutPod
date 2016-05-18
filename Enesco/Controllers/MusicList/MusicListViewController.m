//
//  MusicListViewController.m
//  Enesco
//
//  Created by Aufree on 11/30/15.
//  Copyright © 2015 The EST Group. All rights reserved.
//

#import "MusicListViewController.h"
#import "MusicViewController.h"
#import "MusicListCell.h"
#import "MusicIndicator.h"
#import "MBProgressHUD.h"

#import <AVFoundation/AVFoundation.h>

@interface MusicListViewController () <MusicViewControllerDelegate, MusicListCellDelegate>
@property (nonatomic, strong) NSArray *musicEntities;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation MusicListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.navigationItem.title = @"for me";
    [self headerRefreshing];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self createIndicatorView];
}

# pragma mark - Custom right bar button item

- (void)createIndicatorView {
    MusicIndicator *indicator = [MusicIndicator sharedInstance];
    indicator.hidesWhenStopped = NO;
    indicator.tintColor = [UIColor redColor];
    
    if (indicator.state != NAKPlaybackIndicatorViewStatePlaying) {
        indicator.state = NAKPlaybackIndicatorViewStatePlaying;
        indicator.state = NAKPlaybackIndicatorViewStateStopped;
    } else {
        indicator.state = NAKPlaybackIndicatorViewStatePlaying;
    }
    
    [self.navigationController.navigationBar addSubview:indicator];
    
    UITapGestureRecognizer *tapInditator = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapIndicator)];
    tapInditator.numberOfTapsRequired = 1;
    [indicator addGestureRecognizer:tapInditator];
}

- (void)handleTapIndicator {
    MusicViewController *musicVC = [MusicViewController sharedInstance];
    if (musicVC.musicEntities.count == 0) {
        [self showMiddleHint:@"暂无正在播放的歌曲"];
        return;
    }
    musicVC.dontReloadMusic = YES;
    [self presentToMusicViewWithMusicVC:musicVC];
}

# pragma mark - Load data from server

- (void)headerRefreshing {
#if 0
    NSDictionary *musicsDict = [self dictionaryWithContentsOfJSONString:@"music_list.json"];
    self.musicEntities = [MusicEntity arrayOfEntitiesFromArray:musicsDict[@"data"]].mutableCopy;
#else
    self.musicEntities = [MusicEntity arrayOfEntitiesFromArray:[self localMusics]];
#endif
    [self.tableView reloadData];
}

-(NSArray *)localMusics
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *musicDirPath = [documentsPath stringByAppendingPathComponent:@"localmusics"];
    [self createDirIfNeed:musicDirPath];
    
    if ([[fileManager contentsOfDirectoryAtPath:musicDirPath error:nil] count] == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@[] forKey:@"localmusics"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSArray *fileArray = [fileManager contentsOfDirectoryAtPath:documentsPath error:nil];
    NSMutableArray *musicList = [NSMutableArray arrayWithCapacity:fileArray.count];
    
    for (NSString *fileName in fileArray) {
        if ([[fileName pathExtension] isEqualToString:@"mp3"]) {
            
            NSString *desMP3Path = [musicDirPath stringByAppendingPathComponent:fileName];
            NSError *error;
            if ([fileManager moveItemAtPath:[documentsPath stringByAppendingPathComponent:fileName] toPath:desMP3Path error:&error]) {
                NSDictionary *mp3Info = [self mp3InfoWithPath:desMP3Path];
                
                NSString *title = [mp3Info objectForKey:@"title"];
                NSString *albumName = [mp3Info objectForKey:@"albumName"];
                NSString *artist = [mp3Info objectForKey:@"artist"];
                [musicList addObject:@{
                                       @"id": @(musicList.count+100),
                                       @"title": title?title:fileName,
                                       @"artist": artist?artist:@"??",
                                       @"pic": @"",
                                       @"music_url" : [@"localmusics" stringByAppendingPathComponent:fileName],
                                       @"albumName" : albumName?albumName:@"??",
                                       }];
            }
            else
            {
                NSLog(@"copy error: %@", error);
            }
        }
    }
    
    if (musicList.count > 0) {
        NSMutableArray *savedMusics = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"localmusics"]];
        [savedMusics addObjectsFromArray:musicList];
        [[NSUserDefaults standardUserDefaults] setObject:savedMusics forKey:@"localmusics"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"localmusics"];
}

- (NSDictionary *)dictionaryWithContentsOfJSONString:(NSString *)fileLocation {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:[fileLocation stringByDeletingPathExtension] ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    __autoreleasing NSError* error = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data
                                                options:kNilOptions error:&error];
    if (error != nil) return nil;
    return result;
}

-(void)createDirIfNeed:(NSString *)dirPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:dirPath])
    {
        [fileManager createDirectoryAtPath:dirPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
}

-(NSDictionary *)mp3InfoWithPath:(NSString *)path
{
    NSDictionary *dict = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        AVURLAsset *avURLAsset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
        for(NSString *format in [avURLAsset availableMetadataFormats])
        {
            if ([format isEqualToString:@"org.id3"]) {
                
                NSMutableDictionary *tempDict = [NSMutableDictionary dictionary];
                for (AVMetadataItem *metadata in [avURLAsset metadataForFormat:format])
                {
                    //                NSLog(@"%@ %@", metadata.commonKey, metadata.value);
                    if([metadata.commonKey isEqualToString:@"title"]
                       || [metadata.commonKey isEqualToString:@"albumName"]
                       || [metadata.commonKey isEqualToString:@"artist"])
                    {
                        [tempDict setObject:metadata.value forKey:metadata.commonKey];
                    }
                    
                    //                if([metadata.commonKey isEqualToString:@"artwork"])
                    //                {
                    //                    UIImage *coverImage = [UIImage imageWithData:[(NSDictionary *)metadata.value objectForKey:@"data"]];//提取图片
                    //                }
                    
                }
                
                dict = [NSDictionary dictionaryWithDictionary:tempDict];
                break;
            }
        }
    }
    
    return dict;
}

# pragma mark - Tableview delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_delegate && [_delegate respondsToSelector:@selector(playMusicWithSpecialIndex:)]) {
        [_delegate playMusicWithSpecialIndex:indexPath.row];
    } else {
        MusicViewController *musicVC = [MusicViewController sharedInstance];
        musicVC.musicTitle = self.navigationItem.title;
        musicVC.musicEntities = _musicEntities;
        musicVC.specialIndex = indexPath.row;
        musicVC.delegate = self;
        [self presentToMusicViewWithMusicVC:musicVC];
    }
    [self updatePlaybackIndicatorWithIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

# pragma mark - Jump to music view

- (void)presentToMusicViewWithMusicVC:(MusicViewController *)musicVC {
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:musicVC];
    [self.navigationController presentViewController:navigationController animated:YES completion:nil];
}

# pragma mark - Update music indicator state

- (void)updatePlaybackIndicatorWithIndexPath:(NSIndexPath *)indexPath {
    for (MusicListCell *cell in self.tableView.visibleCells) {
        cell.state = NAKPlaybackIndicatorViewStateStopped;
    }
    MusicListCell *musicsCell = [self.tableView cellForRowAtIndexPath:indexPath];
    musicsCell.state = NAKPlaybackIndicatorViewStatePlaying;
}

- (void)updatePlaybackIndicatorOfCell:(MusicListCell *)cell {
    MusicEntity *music = cell.musicEntity;
    if (music.musicId == [[MusicViewController sharedInstance] currentPlayingMusic].musicId) {
        cell.state = NAKPlaybackIndicatorViewStateStopped;
        cell.state = [MusicIndicator sharedInstance].state;
    } else {
        cell.state = NAKPlaybackIndicatorViewStateStopped;
    }
}

- (void)updatePlaybackIndicatorOfVisisbleCells {
    for (MusicListCell *cell in self.tableView.visibleCells) {
        [self updatePlaybackIndicatorOfCell:cell];
    }
}

# pragma mark - Tableview datasource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 57;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _musicEntities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *musicListCell = @"musicListCell";
    MusicEntity *music = _musicEntities[indexPath.row];
    MusicListCell *cell = [tableView dequeueReusableCellWithIdentifier:musicListCell];
    cell.musicNumber = indexPath.row + 1;
    cell.musicEntity = music;
    cell.delegate = self;
    [self updatePlaybackIndicatorOfCell:cell];
    return cell;
}
         
# pragma mark - HUD
         
- (void)showMiddleHint:(NSString *)hint {
     UIView *view = [[UIApplication sharedApplication].delegate window];
     MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
     hud.userInteractionEnabled = NO;
     hud.mode = MBProgressHUDModeText;
     hud.labelText = hint;
     hud.labelFont = [UIFont systemFontOfSize:15];
     hud.margin = 10.f;
     hud.yOffset = 0;
     hud.removeFromSuperViewOnHide = YES;
     [hud hide:YES afterDelay:2];
}

@end