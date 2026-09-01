from PIL import Image
import argparse


def png_to_hex(input_file, output_file, mode="L"):
    """
    Convert a PNG image to a hex file.

    Modes:
        L      -> 8-bit grayscale (1 byte/pixel)
        RGB    -> RGB888 (3 bytes/pixel, one byte per line)
        RGB565 -> RGB565 (16-bit word per line)
    """

    if mode == "L":
        img = Image.open(input_file).convert("L")

    elif mode in ("RGB", "RGB565"):
        img = Image.open(input_file).convert("RGB")

    else:
        raise ValueError(f"Unsupported mode: {mode}")

    with open(output_file, "w") as f:

        if mode == "L":
            for p in img.get_flattened_data():
                f.write(f"{p:02X}\n")

        elif mode == "RGB":
            for r, g, b in img.get_flattened_data():
                f.write(f"{r:02X}\n")
                f.write(f"{g:02X}\n")
                f.write(f"{b:02X}\n")

        elif mode == "RGB565":
            for r, g, b in img.get_flattened_data():
                rgb565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
                f.write(f"{rgb565:04X}\n")

    print(f"Image size : {img.width} x {img.height}")
    print(f"Mode       : {mode}")
    print(f"Hex file written to {output_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input_png")
    parser.add_argument("output_hex")
    parser.add_argument(
        "--mode",
        choices=["L", "RGB", "RGB565"],
        default="L",
        help="Output format (default: grayscale)"
    )

    args = parser.parse_args()

    png_to_hex(args.input_png, args.output_hex, args.mode)
