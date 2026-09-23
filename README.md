# Webcam-ESP32

Turn an ESP32-S3 N16R8 board with an OV5640 camera into a USB webcam. The
firmware sends MJPEG video over USB Video Class (UVC), so Windows recognizes it
as **UVC CAM1** without a custom webcam driver.

The tested setup is an ESP32-S3-WROOM-1 N16R8 board (16 MB flash, 8 MB octal
PSRAM) with an OV5640 on its camera connector and two USB-C ports. Its
USB-to-UART port uses a CH343 chip; the other port is the ESP32-S3's native
USB port. No external USB wiring is needed.

## Use it on Windows

If the webcam firmware is already flashed, plug the cable into the **native
USB-C port** and open Windows Camera. Flashing another ESP32 project replaces
the webcam firmware until you flash this project again.

For a fresh flash and launch, double-click `flash&start_camera.bat`:

1. Move the cable to the **USB-to-UART/programming port** when prompted. The
   launcher finds its COM port and checks the connected ESP32-S3.
2. It builds and flashes the current project with ESP-IDF.
3. Move the cable to the **native USB/webcam port** when prompted. The launcher
   waits for **UVC CAM1**, then opens Windows Camera.

The launcher was tested on Windows 11 with ESP-IDF 5.5.5 installed under
`C:\Espressif`. Its ESP-IDF paths are in `tools/flash_and_start.ps1`; change
them if your installation is elsewhere. To restrict flashing to a particular
board, put its MAC address in `tools/board_mac.txt`. That optional file is kept
out of Git.

## Build or flash manually

In an ESP-IDF PowerShell terminal, run these commands from this directory:

```powershell
idf.py build
idf.py -p COMx flash monitor
```

Replace `COMx` with the programming port shown in Device Manager. Exit the
monitor with Ctrl+]. Then move the cable to the native USB port. The build
target and memory settings are in `sdkconfig.defaults`; dependency versions
are declared in `main/idf_component.yml` and recorded in `dependencies.lock`.

At boot, the firmware logs the detected sensor and checks one 640×480 JPEG
capture before starting UVC. If the webcam appears but its stream does not
start, use the programming port and serial monitor to check this boot test.

## Camera settings and test results

The initial stream is **640×480 MJPEG at a nominal 15 FPS**, using isochronous
USB transfer. The camera GPIO mapping is in `sdkconfig.defaults` (XCLK 15,
SIOD 4, SIOC 5, VSYNC 6, HREF 7, PCLK 13, and data GPIOs
11/9/8/10/12/18/17/16). Similar ESP32-S3 N16R8 boards can use a different
camera pin map; these values describe PCB connections, not wires to add.

On the tested board, the boot check detected OV5640 (PID `0x5640`) and captured
a valid JPEG. Windows enumerated **UVC CAM1**, FFmpeg received 60 frames, and
OpenCV received 20 frames at a measured 11.6 FPS. Actual speed depends on
lighting, JPEG size, and USB throughput. Linux support follows the UVC
interface, but it has not been tested with this board.

To run the included Windows capture test, install OpenCV and run:

```powershell
python -m pip install opencv-python-headless
python tools/capture_test.py
```

The test saves `capture.jpg` and reports frame size and measured FPS.

## Source and license

The application is adapted from Espressif's
[`usb_webcam` example](https://github.com/espressif/esp-iot-solution/tree/master/examples/usb/device/usb_webcam).
The included example code is licensed under [Apache-2.0](LICENSE); the camera
and USB components are fetched through the ESP-IDF component manager.
