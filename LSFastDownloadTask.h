//
//  LSFastDownloadTask.h
//  testEmpty
//
//  Created by santhosh lakkanpalli on 06/01/15.
//  Copyright (c) 2015 Santhosh Kumar. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const AcceptRangeKey;
extern NSString * const RangeKey;
extern NSString * const BytesKey;
extern NSString * const LSErrorDomain;

typedef void(^LSCompletion)(NSError *error,NSURL *fileLocation);


@interface LSFastDownloadTask : NSObject

-(instancetype)initWithURL:(NSURL *)url completion:(LSCompletion)completion;

@end
