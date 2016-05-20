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

#import "UIAlertController+Blocks.h"
#import <AVFoundation/AVFoundation.h>

@interface MusicListViewController () <MusicViewControllerDelegate, MusicListCellDelegate>
@property (nonatomic, strong) NSMutableArray *musicEntities;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) UIActivityIndicatorView *actView;

@end

@implementation MusicListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(headerRefreshing) name:@"reloadLocalFiles" object:nil];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.navigationItem.title = @"for me";

    [self.actView startAnimating];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self headerRefreshing];
        
        [self.actView stopAnimating];
    });
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
    self.musicEntities = [NSMutableArray arrayWithArray:[MusicEntity arrayOfEntitiesFromArray:[self localMusics]]];
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

-(BOOL)removeFileWithIndex:(NSInteger)index
{
    NSInteger currPlayIndex = [self.musicEntities indexOfObject:[[MusicViewController sharedInstance] currentPlayingMusic]];
    if (currPlayIndex == index) {
        [[MusicViewController sharedInstance] playPreviousMusic:nil];
    }
    
    
    NSMutableArray *savedMusics = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"localmusics"]];
    
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *filePath = [documentsPath stringByAppendingPathComponent:[[savedMusics objectAtIndex:index] objectForKey:@"music_url"]];
    if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:nil]) {
        [savedMusics removeObjectAtIndex:index];
        
        [[NSUserDefaults standardUserDefaults] setObject:savedMusics forKey:@"localmusics"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return YES;
    }
    else
    {
        return NO;
    }
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
//        musicVC.musicTitle = self.navigationItem.title;
        musicVC.musicEntities = _musicEntities;
        musicVC.specialIndex = indexPath.row;
        musicVC.delegate = self;
        [self presentToMusicViewWithMusicVC:musicVC];
    }
    [self updatePlaybackIndicatorWithIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"删除";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 从数据源中删除
//    [_data removeObjectAtIndex:indexPath.row];
    // 从列表中删除
//    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [UIAlertController showAlertInViewController:self withTitle:@"提示" message:@"确定要删除？" cancelButtonTitle:@"取消" destructiveButtonTitle:@"确定" otherButtonTitles:nil tapBlock:^(UIAlertController * _Nonnull controller, UIAlertAction * _Nonnull action, NSInteger buttonIndex) {
        if (buttonIndex != controller.cancelButtonIndex) {
            if ([self removeFileWithIndex:indexPath.row]) {
                [self.musicEntities removeObjectAtIndex:indexPath.row];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                
                [self showMiddleHint:@"删除成功"];
            }
            else
            {
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                [self showMiddleHint:@"删除失败"];
            }
        }
        else
        {
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
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
     hud.label.text = hint;
     hud.label.font = [UIFont systemFontOfSize:15];
     hud.margin = 10.f;
     hud.removeFromSuperViewOnHide = YES;
     [hud hideAnimated:YES afterDelay:2];
}

-(UIActivityIndicatorView *)actView
{
    if (!_actView) {
        _actView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _actView.center = CGPointMake(self.view.center.x, _actView.frame.size.height/2 + 10);
        _actView.hidesWhenStopped = YES;
        [self.view addSubview:_actView];
    }
    
    return _actView;
}

@end
