LSFastDownloader
================

Using this library, you can download a single file faster by downloading it parallely in chunks.All you got to do is init with url and after download is finished completion block will be called with file location. The server must support range based download for that file.

HOW TO USE ->

    NSURL *url = [NSURL URLWithString:@"link to some file"];
    LSFastDownloadTask *downloadTask = [[LSFastDownloadTask alloc] initWithURL:url completion:^(NSError *error, NSURL *fileLocation) {
        if (fileLocation) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithContentsOfFile:[fileLocation path]];
                self.imageView.image = image;
            });
        }
    }];

You can use this class and create an Internet Download Manger (IDM) application with UI and stuff.



