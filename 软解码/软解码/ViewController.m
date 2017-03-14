//
//  ViewController.m
//  软解码
//
//  Created by zhangzhifu on 2017/3/14.
//  Copyright © 2017年 seemygo. All rights reserved.
//

#import "ViewController.h"
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import "OpenGLView20.h"

@interface ViewController ()
{
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVFrame *pFrame;
    AVPacket packet;
    OpenGLView20 *glView;
    
    int videoIndex;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    // 0. 初始化OpenGL用于渲染YUV数据
    glView = [[OpenGLView20 alloc] initWithFrame:self.view.bounds];
    [self.view insertSubview:glView atIndex:0];
    
    // 初始化工作
    // 1. 注册所有的格式和编码格式
    av_register_all();
    
    // 2. 打开文件
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"story.mp4" ofType:nil];
    if (avformat_open_input(&pFormatCtx, [filePath UTF8String], NULL, NULL) < 0) {
        NSLog(@"打开文件失败");
        return;
    };
    
    // 3. 寻找AVStream信息
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        NSLog(@"查找流信息失败");
        return;
    };
    
    // 4. 获取视频信息
    videoIndex = -1;
    for (int i = 0; i < pFormatCtx->nb_streams; i++) {
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            break;
        }
    }
    
    // 5. 获取AVScream
    AVStream *pStream = pFormatCtx->streams[videoIndex];
    
    // 6. 获取AVCodecCtx
    pCodecCtx = pStream->codec;
    
    // 7. 查找解码器
    AVCodec *pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"查找解码器失败");
        return;
    }
    
    // 8. 打开解码器
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"解码器打开失败");
        return;
    }
    
    // 9. 创建AVFrame
    pFrame = av_frame_alloc();
}

- (IBAction)play:(id)sender {
    // 解码操作: AVFrame -> AVPacket -> 写入文件
    // 解码操作: AVPacket -> AVFrame -> YUV数据 -> OpenGL渲染
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        while (av_read_frame(pFormatCtx, &packet) >= 0) {
            int got_picture = -1;
            if (packet.stream_index == videoIndex) {
                if (avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, &packet) < 0) {
                    NSLog(@"解码失败,解码下一帧数据");
                    continue;
                };
                
                if (got_picture) {
                    char *buf = (char *)malloc(pFrame->width * pFrame->height * 3 / 2);
                    int w = pFrame->width;
                    int h = pFrame->height;
                    char *y = buf;
                    char *u = y + w * h;
                    char *v = u + w * h / 4;
                    for (int i=0; i<h; i++)
                        memcpy(y + w * i, pFrame->data[0] + pFrame->linesize[0] * i, w);
                    for (int i=0; i<h/2; i++)
                        memcpy(u + w / 2 * i, pFrame->data[1] + pFrame->linesize[1] * i, w / 2);
                    for (int i=0; i<h/2; i++)
                        memcpy(v + w / 2 * i, pFrame->data[2] + pFrame->linesize[2] * i, w / 2);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [glView displayYUV420pData:buf width:w height:h];
                    });
                }
            }
        }
    });
}

@end
