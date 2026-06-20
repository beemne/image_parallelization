#!/usr/bin/env python3
import os
import struct

def fix_ppm_and_convert(ppm_path, jpg_path):
    """Fix PPM header and convert to JPEG"""
    try:
        with open(ppm_path, 'rb') as f:
            # Read first few bytes to check header
            header = f.readline().strip()
            
            # Check if it's P6 format
            if header == b'P6':
                # Read dimensions
                line = f.readline()
                while line.startswith(b'#'):
                    line = f.readline()
                width, height = map(int, line.split())
                maxval = int(f.readline())
                
                # Read raw pixel data
                data = f.read()
                
                # Verify size
                expected_size = width * height * 3
                if len(data) != expected_size:
                    # Try to fix: maybe there are extra bytes
                    if len(data) > expected_size:
                        data = data[:expected_size]
                    else:
                        print(f"  ⚠️ File {ppm_path} seems incomplete")
                        return False
            else:
                # Try to read as PPM anyway
                f.seek(0)
                data = f.read()
                # Try to find the start of image data
                # Look for the pixel data after headers
                lines = []
                f.seek(0)
                for line in f:
                    if line.startswith(b'P'):
                        continue
                    if line.startswith(b'#'):
                        continue
                    if len(line.strip().split()) >= 2:
                        try:
                            width, height = map(int, line.split())
                            break
                        except:
                            continue
                # Simplified: just try to read the file
                f.seek(0)
                data = f.read()
        
        # Try to create image from raw data
        from PIL import Image
        import io
        
        # Try to read as PPM with PIL directly (it might work with proper handling)
        try:
            img = Image.open(ppm_path)
        except:
            # If PIL fails, create image from raw RGB data
            # Need to know dimensions - try to extract from filename
            filename = os.path.basename(ppm_path)
            if '4k' in filename:
                width, height = 3840, 2160
            elif '8k' in filename:
                width, height = 7680, 4320
            else:
                # Try to guess from file size
                file_size = os.path.getsize(ppm_path)
                if file_size > 30_000_000:
                    width, height = 7680, 4320
                elif file_size > 7_000_000:
                    width, height = 3840, 2160
                else:
                    width, height = 1920, 1080
            
            # Create image from raw RGB data
            img = Image.frombytes('RGB', (width, height), data[:width*height*3])
        
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Save as JPEG
        img.save(jpg_path, 'JPEG', quality=95)
        return True
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False

# Convert all PPM files
output_dir = 'datasets/output'
converted = 0

for filename in os.listdir(output_dir):
    if filename.endswith('.ppm'):
        ppm_path = os.path.join(output_dir, filename)
        jpg_path = ppm_path.replace('.ppm', '.jpg')
        
        # Skip if file is empty
        if os.path.getsize(ppm_path) == 0:
            print(f"⚠️ Skipping empty file: {filename}")
            continue
        
        print(f"Converting {filename}...")
        if fix_ppm_and_convert(ppm_path, jpg_path):
            print(f"  ✅ Converted: {filename}")
            converted += 1
        else:
            print(f"  ❌ Failed: {filename}")

print(f"\n✅ Converted {converted} images to JPEG")
