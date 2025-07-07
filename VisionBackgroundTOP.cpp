//
//  VisionBackgroundTOP.cpp
//  VisionBackgroundTOP
//
//  Created by marte on 05/07/2025.
//

#include "VisionBackgroundTOP.h"
#include <cstring>

void VisionBackgroundTOP::getGeneralInfo(TD::TOP_GeneralInfo* ginfo, const TD::OP_Inputs*, void* /*reserved1*/)
{
    ginfo->cookEveryFrame = true;
}

bool VisionBackgroundTOP::getOutputFormat(TD::TOP_OutputFormat* format, const TD::OP_Inputs* inputs, TD::TOP_Context*, int outputIndex)
{
    if (inputs->getNumInputs() > 0)
    {
        auto in = inputs->getInputTOP(0);
        if (in)
        {
            format->width = in->textureDesc.width;
            format->height = in->textureDesc.height;
            if (outputIndex == 0)
                format->pixelFormat = TD::OP_PixelFormat::BGRA8Fixed;
            else
                format->pixelFormat = TD::OP_PixelFormat::Mono8Fixed;
            return true;
        }
    }
    return false;
}
