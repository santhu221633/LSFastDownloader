//
//  LSFastDownloadTask.m
//  testEmpty
//
//  Created by santhosh lakkanpalli on 06/01/15.
//  Copyright (c) 2015 Santhosh Kumar. All rights reserved.
//

#define MAX_CONNECTIONS_PER_HOST_PER_SESSION 6
#define TIMEOUT 120

#import "LSFastDownloadTask.h"

NSString  * const AcceptRangeKey = @"Accept-Ranges";
NSString  * const RangeKey = @"range";
NSString  * const BytesKey = @"bytes";
NSString  * const LSErrorDomain = @"LSErrorDomain";


@interface LSFastDownloadTask ()<NSURLSessionDataDelegate,NSURLSessionDownloadDelegate,NSURLSessionTaskDelegate>

// we access some of these from another thread without race or dead locks.
@property (nonatomic,strong) NSURL *urlToDownload;
@property (nonatomic,strong) NSURLSession *session;
@property (nonatomic,strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic,strong) NSOperationQueue *operationQueue;
@property (nonatomic,strong) NSMutableArray *locations;
@property (nonatomic,assign) int pendingDownloads;
@property (nonatomic,strong) LSCompletion completion;
@property (nonatomic,strong) NSURLSessionDataTask *initialDataTask;

@property (nonatomic,assign) int indexUsedForCreatingTempFiles;
@end

@implementation LSFastDownloadTask

-(instancetype)initWithURL:(NSURL *)url completion:(LSCompletion)completion{
    self = [super init];
    if (self) {
        self.urlToDownload = url;
        self.completion = completion;
        
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.sessionConfiguration.URLCache = nil;
        self.sessionConfiguration.HTTPMaximumConnectionsPerHost = MAX_CONNECTIONS_PER_HOST_PER_SESSION;
        
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:TIMEOUT];
        [request setHTTPMethod:@"GET"];
        
        self.initialDataTask = [_session dataTaskWithRequest:request];
        [self.initialDataTask resume];
        
    }
    return self;
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler{
    NSLog(@"Request Redirected");
    completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error) {
        if (task == self.initialDataTask) {
            self.initialDataTask = nil;
        }
        else{
            NSLog(@"%@",error);
            self.initialDataTask = nil;
            [self cancelSession:error];
        }
    }

}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    
    completionHandler(NSURLSessionResponseCancel);

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *allHeaderFields = httpResponse.allHeaderFields;

    if([allHeaderFields[AcceptRangeKey] isEqualToString:BytesKey]){
        //this server accepts "range" requests
        long long contentLength = [allHeaderFields[@"Content-Length"] longLongValue];
        int numberOfAsynchDownloads = 1;
        //content length is in bytes
        if (contentLength < 102400 ) {  //100KB
            //download in only one thread
            numberOfAsynchDownloads = 1;
        }
        else if (contentLength < 10485760){     //10MB
            numberOfAsynchDownloads = 4;
        }
        else{
            numberOfAsynchDownloads = MAX_CONNECTIONS_PER_HOST_PER_SESSION;
        }
        
        self.locations = [NSMutableArray arrayWithCapacity:numberOfAsynchDownloads];
        
        long long range = contentLength/numberOfAsynchDownloads;
        self.pendingDownloads = numberOfAsynchDownloads;
        
        int i;
        for(i=0;i<numberOfAsynchDownloads;i++){
            
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.urlToDownload cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:TIMEOUT];
            [request setHTTPMethod:@"GET"];

            if (i != 0 && i == (numberOfAsynchDownloads - 1)){
                NSString *byteRange = [NSString stringWithFormat:@"%@=%lld-",BytesKey,range*(i)];
                [request setValue:byteRange forHTTPHeaderField:RangeKey];
                
            }
            else if(i!=0 || numberOfAsynchDownloads >1){
                NSString *byteRange = [NSString stringWithFormat:@"%@=%lld-%lld",BytesKey,range*i,range*(i+1) - 1];
                [request setValue:byteRange forHTTPHeaderField:RangeKey];
            }
            
            NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request];
            [downloadTask resume];
            [self.locations addObject:downloadTask];
        }
    }
    else{
        [self cancelSession:nil];
    }
    
}


#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    self.pendingDownloads--;
    NSInteger index =  [self.locations indexOfObject:downloadTask];
    NSString *finalPath = [self moveFileDownloadAtTempLocation:location];
    if (finalPath) {
        [self.locations replaceObjectAtIndex:index withObject:finalPath];
    }
    
    if (self.pendingDownloads == 0) {
        //download finished. Now merge the files
        
        NSString *path = [self pathToDownloadDirectory];
        NSString *appendPath = [NSString stringWithFormat:@"/%@",self.urlToDownload.lastPathComponent];
        path = [path stringByAppendingString:appendPath];
        
        BOOL success = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        if (!success) {
            NSError *error = [NSError errorWithDomain:LSErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:@"Unable to create File"}];
            [self cancelSession:error];
            return;
        }
        
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        //file handle points to beginning because no data in file
        for(NSString *location in self.locations){
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:location];
            [fileHandle writeData:data];
        }
        [fileHandle closeFile];
        
        //delete temp copied files
        for(NSString *location in self.locations){
            NSError *error;
            BOOL success = [[NSFileManager defaultManager] removeItemAtPath:location error:&error];
            if (!success || error) {
                [self cancelSession:error];
            }
        }
        
        self.completion(nil,[NSURL fileURLWithPath:path]);
    }
    
}

#pragma mark - Private Methods

-(NSString *)pathToDocumentDirectory{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return path;
}

-(NSString *)pathToDownloadDirectory{
    NSString *path = [self pathToDocumentDirectory];
    path = [path stringByAppendingString:@"/downloads_ls"];
    
    BOOL doesDirectoryExists = NO;
    BOOL isExisting = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&doesDirectoryExists];
    if (isExisting || doesDirectoryExists) {
        return path;
    }
    else{
        NSError *error;
        BOOL isSuccess = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
        if (error || !isSuccess) {
            [self cancelSession:error];
            return nil;
        }
    }
    
    return path;
}

-(NSString *)moveFileDownloadAtTempLocation:(NSURL *)tempLocation{
    self.indexUsedForCreatingTempFiles++;
    NSString *newPath = [[self pathToDownloadDirectory] stringByAppendingFormat:@"/%@_temp_%d",self.urlToDownload.lastPathComponent,self.indexUsedForCreatingTempFiles];
    NSError *error;
    BOOL isSuccess = [[NSFileManager defaultManager] moveItemAtPath:[tempLocation path] toPath:newPath error:&error];
    if (!isSuccess || error) {
        [self cancelSession:error];
        return nil;
    }
    return newPath;
}

-(void)cancelSession:(NSError *)error{
    [self.session invalidateAndCancel];
    self.completion(error,nil);
}

@end



























