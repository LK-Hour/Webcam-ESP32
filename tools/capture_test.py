"""Capture a few frames from the connected UVC webcam on Windows."""

import argparse
import time
from pathlib import Path

import cv2


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--frames", type=int, default=20)
    parser.add_argument("--output", type=Path, default=Path("capture.jpg"))
    args = parser.parse_args()

    camera = None
    backend_name = None
    for name, backend in (("Media Foundation", cv2.CAP_MSMF),
                          ("DirectShow", cv2.CAP_DSHOW)):
        candidate = cv2.VideoCapture(args.index, backend)
        if candidate.isOpened():
            camera = candidate
            backend_name = name
            break
        candidate.release()
    if camera is None:
        print(f"Cannot open camera index {args.index} with Media Foundation or DirectShow")
        return 1

    print(f"Opened camera index {args.index} using {backend_name}")
    print(f"Reported size: {camera.get(cv2.CAP_PROP_FRAME_WIDTH):.0f}x"
          f"{camera.get(cv2.CAP_PROP_FRAME_HEIGHT):.0f}")
    start = time.monotonic()
    count = 0
    first = None
    try:
        for _ in range(args.frames):
            ok, frame = camera.read()
            if not ok or frame is None:
                print(f"Frame read failed after {count} successful frames")
                return 2
            if first is None:
                first = frame.copy()
            count += 1
    finally:
        camera.release()

    elapsed = time.monotonic() - start
    if first is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if not cv2.imwrite(str(args.output), first):
            print(f"Could not save frame to {args.output}")
            return 3
        print(f"Frame size: {first.shape[1]}x{first.shape[0]}")
        print(f"Saved: {args.output.resolve()}")
    print(f"Captured {count} frames in {elapsed:.2f}s ({count / elapsed:.1f} FPS)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
