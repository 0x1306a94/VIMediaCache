//
//  VIResoureLoader.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIResourceLoader.h"
#import "VIMediaDownloader.h"
#import "VIResourceLoadingRequestWorker.h"
#import "VIContentInfo.h"

NSString * const MCResourceLoaderErrorDomain = @"LSFilePlayerResourceLoaderErrorDomain";

@interface VIResourceLoader () <VIResourceLoadingRequestWorkerDelegate>

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong) VIMediaDownloader *mediaDownloader;
@property (nonatomic, strong) NSMutableArray<VIResourceLoadingRequestWorker *> *pendingRequestWorkers;

@property (nonatomic, getter=isCancelled) BOOL cancelled;

@end

@implementation VIResourceLoader


- (void)dealloc {
    [_mediaDownloader cancel];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = url;
        _mediaDownloader = [[VIMediaDownloader alloc] initWithURL:url];
        _pendingRequestWorkers = [NSMutableArray array];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"Use - initWithURL: instead");
    return nil;
}

- (void)addRequest:(AVAssetResourceLoadingRequest *)request {
    if (self.pendingRequestWorkers.count > 0) {
        NSLog(@"====== start No cache");
        [self startNoCacheWorkerWithRequest:request];
    } else {
        NSLog(@"====== start cache");
        [self startWorkerWithRequest:request];
    }
}

- (void)removeRequest:(AVAssetResourceLoadingRequest *)request {
    __block VIResourceLoadingRequestWorker *requestWorker = nil;
    [self.pendingRequestWorkers enumerateObjectsUsingBlock:^(VIResourceLoadingRequestWorker *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.request == request) {
            requestWorker = obj;
            *stop = YES;
        }
    }];
    if (requestWorker) {
        [requestWorker finish];
        [self.pendingRequestWorkers removeObject:requestWorker];
    }
}

- (void)cancel {
    [self.mediaDownloader cancel];
}

#pragma mark - VIResourceLoadingRequestWorkerDelegate

- (void)resourceLoadingRequestWorker:(VIResourceLoadingRequestWorker *)requestWorker didCompleteWithError:(NSError *)error {
    [self removeRequest:requestWorker.request];
    if (error && [self.delegate respondsToSelector:@selector(resourceLoader:didFailWithError:)]) {
        [self.delegate resourceLoader:self didFailWithError:error];
    }

    if (self.pendingRequestWorkers.count > 0) {
        VIResourceLoadingRequestWorker *worker = [self.pendingRequestWorkers lastObject];
        [self.pendingRequestWorkers removeLastObject];
        [self startWorkerWithRequest:worker.request];
    }
}

#pragma mark - Helper

- (void)startNoCacheWorkerWithRequest:(AVAssetResourceLoadingRequest *)request {
    VIMediaDownloader *mediaDownloader = [[VIMediaDownloader alloc] initWithURL:self.url];
    mediaDownloader.saveToCache = false;
    VIResourceLoadingRequestWorker *requestWorker = [[VIResourceLoadingRequestWorker alloc] initWithMediaDownloader:self.mediaDownloader
                                                                                             resourceLoadingRequest:request];
    [self.pendingRequestWorkers addObject:requestWorker];
    requestWorker.delegate = self;
    [requestWorker startWork];
}

- (void)startWorkerWithRequest:(AVAssetResourceLoadingRequest *)request {
    VIResourceLoadingRequestWorker *requestWorker = [[VIResourceLoadingRequestWorker alloc] initWithMediaDownloader:self.mediaDownloader
                                                                                             resourceLoadingRequest:request];
    [self.pendingRequestWorkers addObject:requestWorker];
    requestWorker.delegate = self;
    [requestWorker startWork];
}

- (NSError *)loaderCancelledError{
    NSError *error = [[NSError alloc] initWithDomain:MCResourceLoaderErrorDomain
                                                code:-3
                                            userInfo:@{NSLocalizedDescriptionKey:@"Resource loader cancelled"}];
    return error;
}

@end
