#ifndef IMAGE_IO_H
#define IMAGE_IO_H

#include "../../include/image_processing.h"
#include <string>
#include <fstream>
#include <vector>
#include <cstring>
#include <stdexcept>

// PPM Image I/O
class PPMImageIO {
public:
    static bool read(const std::string& filename, Image& img);
    static bool write(const std::string& filename, const Image& img);
    static bool readRaw(const std::string& filename, Image& img, 
                        int width, int height, int channels);
    static bool readP3(const std::string& filename, Image& img);
};

// Image Generator
class ImageGenerator {
public:
    static Image generateGradient(int width, int height);
    static Image generateCheckerboard(int width, int height, int tileSize = 32);
    static Image generateRandom(int width, int height);
    static Image generateSinWave(int width, int height, float frequency = 0.05f);
};

#endif // IMAGE_IO_H
