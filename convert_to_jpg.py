#!/usr/bin/env python3
import os
from PIL import Image

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
        
        try:
            img = Image.open(ppm_path)
            if img.mode != 'RGB':
                img = img.convert('RGB')
            img.save(jpg_path, 'JPEG', quality=95)
            print(f"✅ Converted: {filename} -> {filename.replace('.ppm', '.jpg')}")
            converted += 1
        except Exception as e:
            print(f"❌ Error converting {filename}: {e}")

print(f"\n✅ Converted {converted} images to JPEG")
