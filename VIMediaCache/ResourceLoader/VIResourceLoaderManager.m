//
//  VIResourceLoaderManager.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VICacheManager.h"
#import "VIResourceLoader.h"
#import "VIResourceLoaderManager.h"

static NSString *kCacheScheme = @"__VIMediaCache___:";

@interface VIResourceLoaderManager () <VIResourceLoaderDelegate>

@property (nonatomic, strong) NSMutableDictionary<id<NSCoding>, VIResourceLoader *> *loaders;

@end

@implementation VIResourceLoaderManager

- (instancetype)init {
	self = [super init];
	if (self) {
		_loaders = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)cleanCache {
	[self.loaders removeAllObjects];
}

- (void)cancelLoaders {
	[self.loaders enumerateKeysAndObjectsUsingBlock:^(id<NSCoding> _Nonnull key, VIResourceLoader *_Nonnull obj, BOOL *_Nonnull stop) {
		[obj cancel];
	}];
	[self.loaders removeAllObjects];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
	NSURL *resourceURL = [loadingRequest.request URL];
	if ([resourceURL.absoluteString hasPrefix:kCacheScheme]) {
		VIResourceLoader *loader = [self loaderForRequest:loadingRequest];
		if (!loader) {
			NSURL *originURL    = nil;
			NSString *originStr = [resourceURL absoluteString];
			originStr           = [originStr stringByReplacingOccurrencesOfString:kCacheScheme withString:@""];
			originURL           = [NSURL URLWithString:originStr];
			loader              = [[VIResourceLoader alloc] initWithURL:originURL];
			loader.delegate     = self;
			NSString *key       = [self keyForResourceLoaderWithURL:resourceURL];
			self.loaders[key]   = loader;
		}
		[loader addRequest:loadingRequest];
		return YES;
	}

	return NO;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
	VIResourceLoader *loader = [self loaderForRequest:loadingRequest];
	[loader removeRequest:loadingRequest];
}

#pragma mark - VIResourceLoaderDelegate

- (void)resourceLoader:(VIResourceLoader *)resourceLoader didFailWithError:(NSError *)error {
	[resourceLoader cancel];
	if ([self.delegate respondsToSelector:@selector(resourceLoaderManagerLoadURL:didFailWithError:)]) {
		[self.delegate resourceLoaderManagerLoadURL:resourceLoader.url didFailWithError:error];
	}
}

#pragma mark - Helper

- (NSString *)keyForResourceLoaderWithURL:(NSURL *)requestURL {
	if ([[requestURL absoluteString] hasPrefix:kCacheScheme]) {
		NSString *s = requestURL.absoluteString;
		return s;
	}
	return nil;
}

- (VIResourceLoader *)loaderForRequest:(AVAssetResourceLoadingRequest *)request {
	NSString *requestKey     = [self keyForResourceLoaderWithURL:request.request.URL];
	VIResourceLoader *loader = self.loaders[requestKey];
	return loader;
}

@end

@implementation VIResourceLoaderManager (Convenient)

+ (NSURL *)assetURLWithURL:(NSURL *)url {
	if (!url) {
		return nil;
	}

	NSURL *assetURL = [NSURL URLWithString:[kCacheScheme stringByAppendingString:[url absoluteString]]];
	return assetURL;
}

- (AVPlayerItem *)playerItemWithURL:(NSURL *)url options:(nullable NSDictionary<NSString *, id> *)options {
	VICacheConfiguration *conf = [VICacheManager cacheConfigurationForURL:url];
	if (conf.progress >= 1.0) {
		// 缓存完成,改为本地文件播放
		NSString *videoPath = [conf.filePath stringByReplacingOccurrencesOfString:@".mt_cfg" withString:@""];
		if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
			NSURL *assetURL          = [NSURL fileURLWithPath:videoPath];
			AVURLAsset *urlAsset     = [AVURLAsset URLAssetWithURL:assetURL options:options];
			AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
			return playerItem;
		}
	}

	NSURL *assetURL      = [VIResourceLoaderManager assetURLWithURL:url];
	AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:assetURL options:options];
	[urlAsset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
	if ([playerItem respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]) {
		playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
	}
	return playerItem;
}

@end
