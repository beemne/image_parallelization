#ifndef IMAGE_IO_H
#define IMAGE_IO_H

#include <fstream>
#include <string>
#include <vector>
#include <cstring>
#include <stdexcept>

// Simple PPM (P6) format reader/writer
class PPMImageIO {
public:
    static bool read(const std::string& filename, Image& img) {
        std::ifstream file(filename, std::ios::binary);
        if (!file.is_open()) return false;
        
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
        
        return file.good();
    }
    
    static bool write(const std::string& filename, const Image& img) {
        std::ofstream file(filename, std::ios::binary);
        if (!file.is_open()) return false;
        
        file << "P6\n" << img.width << " " << img.height << "\n255\n";
        file.write(reinterpret_cast<const char*>(img.data.data()), img.data.size());
        
        return file.good();
    }
    
    static bool readRaw(const std::string& filename, Image& img, int width, int height, int channels) {
        std::ifstream file(filename, std::ios::binary);
        if (!file.is_open()) return false;
        
        img.width = width;
        img.height = height;
        img.channels = channels;
        img.data.resize(width * height * channels);
        
        file.read(reinterpret_cast<char*>(img.data.data()), img.data.size());
        
        return file.good();
    }
    
private:
    static bool readP3(const std::string& filename, Image& img) {
        std::ifstream file(filename);
        if (!file.is_open()) return false;
        
        std::string magic;
        file >> magic;
        
        if (magic != "P3") return false;
        
        int maxVal;
        file >> img.width >> img.height >> maxVal;
        
        img.channels = 3;
        img.data.resize(img.width * img.height * img.channels);
        
        for (int i = 0; i < img.data.size(); ++i) {
            int val;
            file >> val;
            img.data[i] = static_cast<uint8_t>(val);
        }
        
        return true;
    }
};

// Synthetic image generator for testing
class ImageGenerator {
public:
    static Image generateGradient(int width, int height) {
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
    
    static Image generateCheckerboard(int width, int height, int tileSize = 32) {
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
};

#endif // IMAGE_IO_H