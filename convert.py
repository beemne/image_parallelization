from PIL import Image
import sys

for img_file in ['datasets/input/4k.jpg', 'datasets/input/8k.jpg']:
    try:
        img = Image.open(img_file)
        ppm_file = img_file.replace('.jpeg', '.ppm').replace('.jpg', '.ppm')
        img.save(ppm_file)
        print(f"Converted: {img_file} -> {ppm_file}")
    except Exception as e:
        print(f"Error converting {img_file}: {e}")
