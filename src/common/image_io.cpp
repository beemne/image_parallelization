#include "image_io.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <stdexcept>
#include <cmath>

// PPM Image I/O Implementation
bool PPMImageIO::read(const std::string& filename, Image& img) {
    std::ifstream file(filename, std::ios::binary);
    if (!file.is_open()) {
        std::cerr << "Failed to open file: " << filename << std::endl;
        return false;
    }
    
    std::string magic;
    file >> magic;
    
    if (magic != "P6") {
        // Try P3 format
        file.close();
        return readP3(filename, img);
    }
    
    int maxVal;
    file >> img.width >> img.height >> maxVal;
    file.get(); // Skip whitespace
    
    img.channels = 3;
    img.data.resize(img.width * img.height * img.channels);
    
    file.read(reinterpret_cast<char*>(img.data.data()), img.data.size());
    
    if (!file.good()) {
        std::cerr << "Error reading image data" << std::endl;
        return false;
    }
    
    return true;
}

bool PPMImageIO::write(const std::string& filename, const Image& img) {
    std::ofstream file(filename, std::ios::binary);
    if (!file.is_open()) {
        std::cerr << "Failed to create file: " << filename << std::endl;
        return false;
    }
    
    file << "P6\n" << img.width << " " << img.height << "\n255\n";
    file.write(reinterpret_cast<const char*>(img.data.data()), img.data.size());
    
    if (!file.good()) {
        std::cerr << "Error writing image data" << std::endl;
        return false;
    }
    
    return true;
}

bool PPMImageIO::readP3(const std::string& filename, Image& img) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Failed to open P3 file: " << filename << std::endl;
        return false;
    }
    
    std::string magic;
    file >> magic;
    
    if (magic != "P3") {
        std::cerr << "Invalid P3 header" << std::endl;
        return false;
    }
    
    int maxVal;
    file >> img.width >> img.height >> maxVal;
    
    img.channels = 3;
    img.data.resize(img.width * img.height * img.channels);
    
    for (int i = 0; i < img.data.size(); ++i) {
        int val;
        file >> val;
        img.data[i] = static_cast<uint8_t>(std::min(255, std::max(0, val)));
    }
    
    return true;
}

bool PPMImageIO::readRaw(const std::string& filename, Image& img, 
                         int width, int height, int channels) {
    std::ifstream file(filename, std::ios::binary);
    if (!file.is_open()) {
        std::cerr << "Failed to open raw file: " << filename << std::endl;
        return false;
    }
    
    img.width = width;
    img.height = height;
    img.channels = channels;
    img.data.resize(width * height * channels);
    
    file.read(reinterpret_cast<char*>(img.data.data()), img.data.size());
    
    if (!file.good()) {
        std::cerr << "Error reading raw data" << std::endl;
        return false;
    }
    
    return true;
}

// ImageGenerator Implementation
Image ImageGenerator::generateGradient(int width, int height) {
    Image img(width, height, 3);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            uint8_t r = static_cast<uint8_t>((x * 255) / width);
            uint8_t g = static_cast<uint8_t>((y * 255) / height);
            uint8_t b = static_cast<uint8_t>(((x + y) * 255) / (width + height));
            img.at(x, y, 0) = r;
            img.at(x, y, 1) = g;
            img.at(x, y, 2) = b;
        }
    }
    return img;
}

Image ImageGenerator::generateCheckerboard(int width, int height, int tileSize) {
    Image img(width, height, 3);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            bool isWhite = ((x / tileSize) + (y / tileSize)) % 2 == 0;
            uint8_t val = isWhite ? 255 : 0;
            img.at(x, y, 0) = val;
            img.at(x, y, 1) = val;
            img.at(x, y, 2) = val;
        }
    }
    return img;
}

Image ImageGenerator::generateRandom(int width, int height) {
    Image img(width, height, 3);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            uint8_t val = static_cast<uint8_t>(rand() % 256);
            img.at(x, y, 0) = val;
            img.at(x, y, 1) = val;
            img.at(x, y, 2) = val;
        }
    }
    return img;
}

Image ImageGenerator::generateSinWave(int width, int height, float frequency) {
    Image img(width, height, 3);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float value = 128.0f + 127.0f * sinf(2.0f * M_PI * frequency * 
                                                  sqrtf(x*x + y*y) / std::min(width, height));
            uint8_t val = static_cast<uint8_t>(std::min(255.0f, std::max(0.0f, value)));
            img.at(x, y, 0) = val;
            img.at(x, y, 1) = val;
            img.at(x, y, 2) = val;
        }
    }
    return img;
}