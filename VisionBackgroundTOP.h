//
//  VisionBackgroundTOP.hpp
//  VisionBackgroundTOP
//
//  Created by marte on 05/07/2025.
//

#pragma once

#include "TOP_CPlusPlusBase.h"

class VisionBackgroundTOP : public TD::TOP_CPlusPlusBase
{
public:
    VisionBackgroundTOP(const TD::OP_NodeInfo* info);
    virtual ~VisionBackgroundTOP();

    void getGeneralInfo(TD::TOP_GeneralInfo*, const TD::OP_Inputs*, void* reserved1) override;
    int getNumOutputs() const { return 2; }
    bool getOutputFormat(TD::TOP_OutputFormat*, const TD::OP_Inputs*, TD::TOP_Context*, int outputIndex) ;
    void execute(TD::TOP_Output*, const TD::OP_Inputs*, void* reserved1) override;
    void setupParameters(TD::OP_ParameterManager* manager, void* reserved1) override;

private:
    class Impl;
    Impl* m_impl;
    TD::TOP_Context* m_context; // Store context pointer
};
