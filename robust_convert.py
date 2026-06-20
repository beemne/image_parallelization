#!/usr/bin/env python3
import os
import sys
from PIL import Image

def read_ppm_robust(filename):
    """Read PPM file with robust header parsing"""
    with open(filename, 'rb') as f:
        # Read magic number (P6)
        magic = f.readline().strip()
        if magic != b'P6':
            raise ValueError(f'Not P6 format: {magic}')
        
        # Skip comments and read dimensions
        width = height = None
        while True:
            line = f.readline()
            if not line:
                break
            line = line.strip()
            if line.startswith(b'#'):
                continue
            parts = line.split()
            if len(parts) >= 2:
                try:
                    width = int(parts[0])
                    height = int(parts[1])
                    break
                except:
                    continue
        
        if width is None or height is None:
            raise ValueError('Could not read dimensions')
        
        # Read max value (skip comments)
        while True:
            line = f.readline()
            if not line:
                break
            line = line.strip()
            if line.startswith(b'#'):
                continue
            maxval = int(line)
            break
        
        # Read the rest of the file as pixel data
        data = f.read()
        
        # Calculate expected size
        expected = width * height * 3
        
        # Handle data size mismatch
        if len(data) < expected:
            print(f"    Warning: Data too short ({len(data)} < {expected}), padding with zeros")
            data += b'\x00' * (expected - len(data))
        elif len(data) > expected:
            print(f"    Warning: Data too long ({len(data)} > {expected}), truncating")
            data = data[:expected]
        
        return Image.frombytes('RGB', (width, height), data)

# Convert all PPM files
output_dir = 'datasets/output'
converted = 0
failed = 0

for filename in os.listdir(output_dir):
    if filename.endswith('.ppm'):
        ppm_path = os.path.join(output_dir, filename)
        jpg_path = ppm_path.replace('.ppm', '.jpg')
        
        # Skip empty files
        if os.path.getsize(ppm_path) == 0:
            print(f"⚠️ Skipping empty: {filename}")
            continue
        
        print(f"Converting {filename}...")
        try:
            img = read_ppm_robust(ppm_path)
            img.save(jpg_path, 'JPEG', quality=95)
            print(f"  ✅ Converted to JPEG ({os.path.getsize(jpg_path)/1024:.1f} KB)")
            converted += 1
        except Exception as e:
            print(f"  ❌ Failed: {e}")
            failed += 1

print(f"\n✅ Converted {converted} images to JPEG")
print(f"❌ Failed: {failed}")
