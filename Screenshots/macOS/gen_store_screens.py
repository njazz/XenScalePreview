from pathlib import Path
from PIL import Image

INPUT_DIR = Path(".")
OUTPUT_DIR = Path("./screenshots_app_store")

CANVAS_SIZE = (2880, 1800)
BACKGROUND = (255, 255, 255)  # White

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

for path in INPUT_DIR.glob("*.png"):
    try:
        with Image.open(path) as source:
            image = source.convert("RGBA")

            # Scale to fit while preserving aspect ratio
            image.thumbnail(CANVAS_SIZE, Image.Resampling.LANCZOS)

            # Create the canvas
            canvas = Image.new(
                "RGBA",
                CANVAS_SIZE,
                BACKGROUND + (255,)
            )

            # Center the screenshot
            x = (CANVAS_SIZE[0] - image.width) // 2
            y = (CANVAS_SIZE[1] - image.height) // 2

            canvas.alpha_composite(image, (x, y))

            # Save as PNG without transparency
            output_path = OUTPUT_DIR / path.name
            canvas.convert("RGB").save(
                output_path,
                format="PNG",
                optimize=True
            )

            print(f"Saved: {output_path}")

    except Exception as e:
        print(f"Skipped {path.name}: {e}")

print("Done!")
