//C++ BRSTM reader
//Copyright (C) 2020 Extrasklep
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <fstream>

// Header definitions
struct Brstm {
    //Byte order mark
    bool BOM = 0;
    //File type, 1 = BRSTM, see above for full list
    unsigned int  file_format   = 0;
    //Audio codec, 0 = PCM8, 1 = PCM16, 2 = DSPADPCM
    unsigned int  codec         = 0;
    bool          loop_flag     = 0;
    unsigned int  num_channels  = 0;
    unsigned long sample_rate   = 0;
    unsigned long loop_start    = 0;
    unsigned long total_samples = 0;
    unsigned long audio_offset  = 0;
    unsigned long total_blocks  = 0;
    unsigned long blocks_size   = 0;
    unsigned long blocks_samples  = 0;
    unsigned long final_block_size  = 0;
    unsigned long final_block_samples = 0;
    unsigned long final_block_size_p  = 0;
    
    //track information
    unsigned int  num_tracks      = 0;
    unsigned int  track_desc_type = 0;
    unsigned int  track_num_channels[8] = {0,0,0,0,0,0,0,0};
    unsigned int  track_lchannel_id [8] = {0,0,0,0,0,0,0,0};
    unsigned int  track_rchannel_id [8] = {0,0,0,0,0,0,0,0};
    unsigned int  track_volume      [8] = {0,0,0,0,0,0,0,0};
    unsigned int  track_panning     [8] = {0,0,0,0,0,0,0,0};
    
    int16_t* PCM_samples[16];
    int16_t* PCM_buffer [16];
    
    unsigned char* ADPCM_data   [16];
    unsigned char* ADPCM_buffer [16]; //Not used yet
    int16_t  ADPCM_coefs    [16][16];
    int16_t* ADPCM_hsamples_1   [16];
    int16_t* ADPCM_hsamples_2   [16];
    
    //Encoder
    unsigned char* encoded_file = nullptr;
    unsigned long  encoded_file_size = 0;
    
    //Things you probably shouldn't touch
    //block cache
    int16_t* PCM_blockbuffer[16];
    int PCM_blockbuffer_currentBlock = -1;
    bool getbuffer_useBuffer = true;
    //Audio stream format,
    //0 for normal block data in BRSTM and similar files
    //1 for WAV which has 1 sample per block
    //so the block size here can be made bigger and block reads
    //won't be made one by one for every sample
    unsigned int audio_stream_format = 0;
};

Brstm* brstmp;
std::ifstream brstmfile;

unsigned char brstm_read(Brstm* brstmi,const unsigned char* fileData,signed int debugLevel,uint8_t decodeAudio);
void brstm_getbuffer(Brstm * brstmi,const unsigned char* fileData,unsigned long sampleOffset,unsigned int bufferSamples);
void brstm_fstream_getbuffer(Brstm * brstmi,std::ifstream& stream,unsigned long sampleOffset,unsigned int bufferSamples);
unsigned char brstm_fstream_read(Brstm * brstmi,std::ifstream& stream,signed int debugLevel);
void brstm_close(Brstm * brstmi);

//Getters for outer world access

extern "C" void initStruct(){
    brstmp = new Brstm;
    for (unsigned int c = 0; c < 16; c++){
        brstmp->ADPCM_buffer[c] = nullptr;
        brstmp->ADPCM_data[c] = nullptr;
        brstmp->ADPCM_hsamples_1[c] = nullptr;
        brstmp->ADPCM_hsamples_2[c] = nullptr;
        brstmp->PCM_blockbuffer[c] = nullptr;
        brstmp->PCM_buffer[c] = nullptr;
        brstmp->PCM_samples[c] = nullptr;
    }
}

extern "C" unsigned long  gHEAD1_sample_rate(){
    return brstmp->sample_rate;
};
extern "C" unsigned long gHEAD1_loop_start(){
    return brstmp->loop_start;
}
extern "C" unsigned char readABrstm (const unsigned char* fileData, unsigned char debugLevel, bool decodeADPCM){
    return brstm_read(brstmp, fileData, debugLevel, decodeADPCM);
}
extern "C" unsigned char readFstreamBrstm(){
    return brstm_fstream_read(brstmp, brstmfile, 1);
}
extern "C" int16_t** gPCM_samples(){
    return brstmp->PCM_samples;
}
extern "C" unsigned int  gHEAD3_num_channels(){
    return brstmp->num_channels;
}
extern "C" unsigned long gHEAD1_blocks_samples(){
    return brstmp->blocks_samples;
}



extern "C" int16_t**  getBufferBlock(unsigned long sampleOffset){
    unsigned int readLength;
    if (sampleOffset/brstmp->blocks_samples < (brstmp->total_blocks)) readLength = brstmp->blocks_samples;
    else readLength = brstmp->final_block_size;
    brstm_fstream_getbuffer(brstmp, brstmfile, sampleOffset, readLength);
    return brstmp->PCM_buffer;
}

extern "C" int16_t** getbuffer(unsigned long offset, uint32_t frames) {
    brstm_fstream_getbuffer(brstmp, brstmfile, offset, frames);
    return brstmp->PCM_buffer;
}

extern "C" void closeBrstm(){
    brstm_close(brstmp);
    delete brstmp;
    brstmfile.close();
}
extern "C" unsigned long gHEAD1_total_samples(){
    return brstmp->total_samples;
}
extern "C" unsigned int gHEAD1_loop(){
    return brstmp->loop_flag;
}

extern "C" int createIFSTREAMObject(char* filename){
     brstmfile.open(filename);
     return brstmfile.is_open();
}
extern "C" unsigned long gHEAD1_total_blocks(){
    return brstmp->total_blocks;
}

extern "C" unsigned long gHEAD1_final_block_samples(){
    return brstmp->final_block_samples;
}

extern "C" unsigned int gFileType(){
    return brstmp->file_format;
}

extern "C" unsigned int gFileCodec() {
    return brstmp->codec;
}
