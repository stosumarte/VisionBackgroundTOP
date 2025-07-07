//
//  VisionBackgroundTOP.mm
//  VisionBackgroundTOP
//
//  Created by marte on 05/07/2025.
//

#import "VisionBackgroundTOP.h"
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <vector>

class VisionBackgroundTOP::Impl
{
public:
    Impl()
    : ciContext([[CIContext alloc] init]),
      colorSpace(CGColorSpaceCreateDeviceRGB()),
      segmentationRequest([[VNGeneratePersonSegmentationRequest alloc] init]),
      latestMask(nullptr),
      destroyed(false)
    {
        segmentationRequest.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelAccurate;
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    }

    ~Impl() {
        destroyed = true;
        CGColorSpaceRelease(colorSpace);
        if (latestMask) CVPixelBufferRelease(latestMask);
    }

    void removeBackground(const TD::TOP_OutputFormat* outputFormat, const TD::OP_Inputs* inputs, TD::TOP_Context* context, void* outData)
    {
        int qualityIdx = 0;
        int downscaleIdx = 0;
        if (inputs) {
            qualityIdx = inputs->getParInt("Quality");
            downscaleIdx = inputs->getParInt("Downscale");
        }

        VNGeneratePersonSegmentationRequestQualityLevel qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelAccurate;
        if (qualityIdx == 1) qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelBalanced;
        else if (qualityIdx == 2) qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelFast;

        float downscale = 1.0f;
        if (downscaleIdx == 1) downscale = 0.5f;
        else if (downscaleIdx == 2) downscale = 0.25f;

        auto in = inputs->getInputTOP(0);
        if (!in) return;

        TD::OP_TOPInputDownloadOptions opts;
        opts.pixelFormat = TD::OP_PixelFormat::BGRA8Fixed;
        auto download = in->downloadTexture(opts, nullptr);
        if (!download) return;

        uint8_t* inData = (uint8_t*)download->getData();
        size_t width = outputFormat->width;
        size_t height = outputFormat->height;
        size_t bytesPerRow = width * 4;

        // Step 1: Create full-resolution CIImage from input
        CIImage* ciImageFull = [CIImage imageWithBitmapData:[NSData dataWithBytesNoCopy:inData
                                                                                  length:bytesPerRow * height
                                                                            freeWhenDone:NO]
                                                 bytesPerRow:bytesPerRow
                                                       size:CGSizeMake(width, height)
                                                     format:kCIFormatBGRA8
                                                 colorSpace:colorSpace];

        // Step 2: Downscale for segmentation if needed
        size_t dsWidth = (size_t)(width * downscale);
        size_t dsHeight = (size_t)(height * downscale);
        CVPixelBufferRef pixelBufferIn = nullptr;
        CIImage* ciImageForSeg = ciImageFull;

        NSDictionary* attrs = @{ (NSString*)kCVPixelBufferCGImageCompatibilityKey: @YES,
                                 (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES };

        if (downscale < 1.0f) {
            ciImageForSeg = [ciImageFull imageByApplyingFilter:@"CILanczosScaleTransform"
                                            withInputParameters:@{
                                                @"inputScale": @(downscale),
                                                @"inputAspectRatio": @1.0
                                            }];
            CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, dsWidth, dsHeight,
                                                  kCVPixelFormatType_32BGRA,
                                                  (__bridge CFDictionaryRef)attrs,
                                                  &pixelBufferIn);
            if (status != kCVReturnSuccess || !pixelBufferIn) return;

            CGRect dsRect = CGRectMake(0, 0, dsWidth, dsHeight);
            [ciContext render:ciImageForSeg toCVPixelBuffer:pixelBufferIn bounds:dsRect colorSpace:colorSpace];
        } else {
            CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height,
                                                           kCVPixelFormatType_32BGRA,
                                                           inData,
                                                           bytesPerRow,
                                                           NULL,
                                                           NULL,
                                                           (__bridge CFDictionaryRef)attrs,
                                                           &pixelBufferIn);
            if (status != kCVReturnSuccess || !pixelBufferIn) return;
        }

        // Step 3: Synchronous segmentation
        segmentationRequest.qualityLevel = qualityLevel;
        VNImageRequestHandler* handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBufferIn options:@{}];
        NSError* error = nil;
        [handler performRequests:@[segmentationRequest] error:&error];
        if (error) {
            NSLog(@"Segmentation error: %@", error);
            CVPixelBufferRelease(pixelBufferIn);
            return;
        }
        VNPixelBufferObservation* result = (VNPixelBufferObservation*)segmentationRequest.results.firstObject;
        CVPixelBufferRef maskToUse = result.pixelBuffer;
        if (!maskToUse) {
            CVPixelBufferRelease(pixelBufferIn);
            return;
        }
        CVPixelBufferRetain(maskToUse);
        CVPixelBufferRelease(pixelBufferIn);

        // Step 4: Composite full-resolution image with upscaled mask
        CIImage* maskImage = [CIImage imageWithCVPixelBuffer:maskToUse];
        CGSize maskSize = maskImage.extent.size;
        CGFloat scaleX = (CGFloat)width / maskSize.width;
        CGFloat scaleY = (CGFloat)height / maskSize.height;
        maskImage = [maskImage imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
        maskImage = [maskImage imageByCroppingToRect:CGRectMake(0, 0, width, height)];

        CIImage* transparentBG = [CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:0]];
        transparentBG = [transparentBG imageByCroppingToRect:CGRectMake(0, 0, width, height)];

        CIImage* person = [ciImageFull imageByApplyingFilter:@"CIBlendWithMask"
                                         withInputParameters:@{
                                             kCIInputBackgroundImageKey: transparentBG,
                                             kCIInputMaskImageKey: maskImage
                                         }];

        CGRect rect = CGRectMake(0, 0, width, height);
        [ciContext render:person toBitmap:outData rowBytes:bytesPerRow bounds:rect format:kCIFormatBGRA8 colorSpace:colorSpace];
        CVPixelBufferRelease(maskToUse);
    }

private:
    CIContext* ciContext;
    CGColorSpaceRef colorSpace;
    VNGeneratePersonSegmentationRequest* segmentationRequest;
    CVPixelBufferRef latestMask;
    bool destroyed;
};

VisionBackgroundTOP::VisionBackgroundTOP(const TD::OP_NodeInfo* info)
{
    m_impl = new Impl();
    m_context = static_cast<TD::TOP_Context*>(info->context);
}

VisionBackgroundTOP::~VisionBackgroundTOP()
{
    delete m_impl;
}

void VisionBackgroundTOP::execute(TD::TOP_Output* output, const TD::OP_Inputs* inputs, void*)
{
    if (inputs->getNumInputs() > 0)
    {
        auto in = inputs->getInputTOP(0);
        if (in)
        {
            TD::OP_TOPInputDownloadOptions opts;
            opts.pixelFormat = TD::OP_PixelFormat::BGRA8Fixed;
            auto download = in->downloadTexture(opts, nullptr);
            if (download)
            {
                //uint8_t* inData = (uint8_t*)download->getData();
                size_t width = in->textureDesc.width;
                size_t height = in->textureDesc.height;
                size_t bytesPerRow = width * 4;

                if (!m_context) {
                    NSLog(@"Context is null");
                    return;
                }

                auto outBuffer = m_context->createOutputBuffer(bytesPerRow * height, TD::TOP_BufferFlags::None, nullptr);
                if (outBuffer) {
                    void* outData = outBuffer->data;
                    TD::TOP_OutputFormat outputFormat;
                    outputFormat.width = width;
                    outputFormat.height = height;
                    outputFormat.pixelFormat = TD::OP_PixelFormat::BGRA8Fixed;

                    m_impl->removeBackground(&outputFormat, const_cast<TD::OP_Inputs*>(inputs), m_context, outData);

                    TD::TOP_UploadInfo uploadInfo;
                    uploadInfo.textureDesc.width = width;
                    uploadInfo.textureDesc.height = height;
                    uploadInfo.textureDesc.pixelFormat = TD::OP_PixelFormat::BGRA8Fixed;
                    uploadInfo.textureDesc.texDim = TD::OP_TexDim::e2D;
                    output->uploadBuffer(&outBuffer, uploadInfo, nullptr);
                } else {
                    NSLog(@"Failed to create output buffer");
                }
            } else {
                NSLog(@"Failed to download input texture");
            }
        } else {
            NSLog(@"No input TOP connected");
        }
    } else {
        NSLog(@"No inputs available");
    }
}

void VisionBackgroundTOP::setupParameters(TD::OP_ParameterManager* manager, void*)
{
    TD::OP_StringParameter sp;
    sp.name = "Quality";
    sp.label = "Segmentation Quality";
    sp.defaultValue = "1";
    const char* names[] = {"Accurate", "Balanced", "Fast"};
    const char* labels[] = {"Accurate (Slowest, Best Quality)", "Balanced (Default)", "Fast (Fastest, Lowest Quality)"};
    manager->appendMenu(sp, 3, names, labels);

    TD::OP_StringParameter dp;
    dp.name = "Downscale";
    dp.label = "Downscale Factor";
    const char* dsNames[] = {"None", "Half", "Quarter"};
    const char* dsLabels[] = {"None (Full Resolution)", "Half (50%)", "Quarter (25%)"};
    manager->appendMenu(dp, 3, dsNames, dsLabels);
}

extern "C" {
void FillTOPPluginInfo(TD::TOP_PluginInfo* info) {
    info->apiVersion = TD::TOPCPlusPlusAPIVersion;
    info->customOPInfo.opType->setString("Visionbackground");
    info->customOPInfo.opLabel->setString("Vision Background");
    info->customOPInfo.opIcon->setString("VBG");
    info->customOPInfo.authorName->setString("Marte Tagliabue");
    info->customOPInfo.authorEmail->setString("ciao@marte.ee");
    info->customOPInfo.majorVersion = 1;
    info->customOPInfo.minorVersion = 0;
    info->customOPInfo.minInputs = 1;
    info->customOPInfo.maxInputs = 1;
}

TD::TOP_CPlusPlusBase* CreateTOPInstance(const TD::OP_NodeInfo* info) {
    return new VisionBackgroundTOP(info);
}

void DestroyTOPInstance(TD::TOP_CPlusPlusBase* instance, TD::TOP_Context*) {
    delete instance;
}
}
