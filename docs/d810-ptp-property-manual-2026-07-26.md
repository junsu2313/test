# Nikon D810 PTP property manual

This document catalogs every configuration block returned by `gphoto2 --list-all-config` for the connected Nikon D810. It is a PTP exposure catalog, not proof that every camera menu item is exposed.

## Capture summary

- Source: `d810-gphoto-list-all-config-2026-07-26.txt`
- Total output lines: 4,028
- Property blocks: 314
- Camera firmware observed: V1.14
- Access: `Readonly: 0` means gPhoto reports writable; `Readonly: 1` means read-only.
- Unknown values are preserved exactly as reported; they require raw PTP descriptor validation before implementation.

## Cross-reference status

The Nikon manual organizes options into playback, photo shooting, movie shooting, custom settings, setup, retouch, and my menu/recent settings. This catalog is grouped by gPhoto path, so each entry below must be classified as direct menu-backed, vendor/internal, status-only, or action-only during the final manual comparison. The raw catalog is complete; semantic mapping is intentionally not guessed.

## Actions (`/main/actions/`)

### `/main/actions/bulb`

| Field | Value |
|---|---|
| Label | Bulb Mode |
| Access | Writable (`Readonly: 0`) |
| Type | TOGGLE |
| Current | `2` |

### `/main/actions/autofocusdrive`

| Field | Value |
|---|---|
| Label | Drive Nikon DSLR Autofocus |
| Access | Writable (`Readonly: 0`) |
| Type | TOGGLE |
| Current | `0` |

### `/main/actions/manualfocusdrive`

| Field | Value |
|---|---|
| Label | Drive Nikon DSLR Manual focus |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `0` |
| Range | `-32767 / 32767 / 1` |

### `/main/actions/changeafarea`

| Field | Value |
|---|---|
| Label | Set Nikon Autofocus area |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `0x0` |

### `/main/actions/controlmode`

| Field | Value |
|---|---|
| Label | Set Nikon Control Mode |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `0` |

### `/main/actions/viewfinder`

| Field | Value |
|---|---|
| Label | Nikon Viewfinder |
| Access | Writable (`Readonly: 0`) |
| Type | TOGGLE |
| Current | `0` |

### `/main/actions/movie`

| Field | Value |
|---|---|
| Label | Movie Capture |
| Access | Writable (`Readonly: 0`) |
| Type | TOGGLE |
| Current | `2` |

### `/main/actions/opcode`

| Field | Value |
|---|---|
| Label | PTP Opcode |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `0x1001,0xparam1,0xparam2` |

## Settings (`/main/settings/`)

### `/main/settings/datetime`

| Field | Value |
|---|---|
| Label | Camera Date and Time |
| Access | Writable (`Readonly: 0`) |
| Type | DATE |
| Current | `1785079487` |

### `/main/settings/imagecomment`

| Field | Value |
|---|---|
| Label | Image Comment |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/settings/imagecommentenable`

| Field | Value |
|---|---|
| Label | Enable Image Comment |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/settings/recordingmedia`

| Field | Value |
|---|---|
| Label | Recording Media |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Card` |
| Choices | 0 Card<br>1 SDRAM<br>2 Unknown value 0002 |

### `/main/settings/artist`

| Field | Value |
|---|---|
| Label | Artist |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `` |

### `/main/settings/copyright`

| Field | Value |
|---|---|
| Label | Copyright |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `` |

### `/main/settings/cleansensor`

| Field | Value |
|---|---|
| Label | Clean Sensor |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Startup and Shutdown` |
| Choices | 0 Off<br>1 Startup<br>2 Shutdown<br>3 Startup and Shutdown |

### `/main/settings/flickerreduction`

| Field | Value |
|---|---|
| Label | Flicker Reduction |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `60 Hz` |
| Choices | 0 50 Hz<br>1 60 Hz<br>2 Auto |

### `/main/settings/fastfs`

| Field | Value |
|---|---|
| Label | Fast Filesystem |
| Access | Writable (`Readonly: 0`) |
| Type | TOGGLE |
| Current | `1` |

### `/main/settings/capturetarget`

| Field | Value |
|---|---|
| Label | Capture Target |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Internal RAM` |
| Choices | 0 Internal RAM<br>1 Memory card |

### `/main/settings/autofocus`

| Field | Value |
|---|---|
| Label | Autofocus |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `On` |
| Choices | 0 On<br>1 Off |

## Status (`/main/status/`)

### `/main/status/serialnumber`

| Field | Value |
|---|---|
| Label | Serial Number |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `00000000000000000000000005508120` |

### `/main/status/manufacturer`

| Field | Value |
|---|---|
| Label | Camera Manufacturer |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `Nikon Corporation` |

### `/main/status/cameramodel`

| Field | Value |
|---|---|
| Label | Camera Model |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `D810` |

### `/main/status/deviceversion`

| Field | Value |
|---|---|
| Label | Device Version |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `V1.14` |

### `/main/status/vendorextension`

| Field | Value |
|---|---|
| Label | Vendor Extension |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `Microsoft.com/DeviceServices:` |

### `/main/status/acpower`

| Field | Value |
|---|---|
| Label | AC Power |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/status/externalflash`

| Field | Value |
|---|---|
| Label | External Flash |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/status/batterylevel`

| Field | Value |
|---|---|
| Label | Battery Level |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `20%` |

### `/main/status/orientation`

| Field | Value |
|---|---|
| Label | Camera Orientation |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `0'` |
| Choices | 0 0'<br>1 270'<br>2 90'<br>3 180' |

### `/main/status/orientation2`

| Field | Value |
|---|---|
| Label | Camera Orientation |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `1'` |

### `/main/status/flashopen`

| Field | Value |
|---|---|
| Label | Flash Open |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/status/flashcharged`

| Field | Value |
|---|---|
| Label | Flash Charged |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/status/minfocallength`

| Field | Value |
|---|---|
| Label | Focal Length Minimum |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `28 mm` |

### `/main/status/maxfocallength`

| Field | Value |
|---|---|
| Label | Focal Length Maximum |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `70 mm` |

### `/main/status/apertureatminfocallength`

| Field | Value |
|---|---|
| Label | Maximum Aperture at Focal Length Minimum |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `3` |

### `/main/status/apertureatmaxfocallength`

| Field | Value |
|---|---|
| Label | Maximum Aperture at Focal Length Maximum |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `3` |

### `/main/status/lowlight`

| Field | Value |
|---|---|
| Label | Low Light |
| Access | Read-only (`Readonly: 1`) |
| Type | RANGE |
| Current | `0` |
| Range | `0 / 3 / 1` |

### `/main/status/lightmeter`

| Field | Value |
|---|---|
| Label | Light Meter |
| Access | Read-only (`Readonly: 1`) |
| Type | RANGE |
| Current | `0` |
| Range | `-60 / 60 / 1` |

### `/main/status/aflocked`

| Field | Value |
|---|---|
| Label | AF Locked |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/status/aelocked`

| Field | Value |
|---|---|
| Label | AE Locked |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/status/fvlocked`

| Field | Value |
|---|---|
| Label | FV Locked |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

## Image settings (`/main/imgsettings/`)

### `/main/imgsettings/imagesize`

| Field | Value |
|---|---|
| Label | Image Size |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `7360x4912` |
| Choices | 0 7360x4912<br>1 5520x3680<br>2 3680x2456 |

### `/main/imgsettings/iso`

| Field | Value |
|---|---|
| Label | ISO Speed |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `400` |
| Choices | 0 32<br>1 40<br>2 50<br>3 64<br>4 80<br>5 100<br>6 125<br>7 160<br>8 200<br>9 250<br>10 320<br>11 400<br>12 500<br>13 640<br>14 800<br>15 1000<br>16 1250<br>17 1600<br>18 2000<br>19 2500<br>20 3200<br>21 4000<br>22 5000<br>23 6400<br>24 8000<br>25 10000<br>26 12800<br>27 16000<br>28 20000<br>29 25600<br>30 51200 |

### `/main/imgsettings/movieiso`

| Field | Value |
|---|---|
| Label | Movie ISO Speed |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `100` |
| Choices | 0 64<br>1 80<br>2 100<br>3 125<br>4 160<br>5 200<br>6 250<br>7 320<br>8 400<br>9 500<br>10 640<br>11 800<br>12 1000<br>13 1250<br>14 1600<br>15 2000<br>16 2500<br>17 3200<br>18 4000<br>19 5000<br>20 6400<br>21 8000<br>22 10000<br>23 12800<br>24 16000<br>25 20000<br>26 25600<br>27 51200 |

### `/main/imgsettings/whitebalance`

| Field | Value |
|---|---|
| Label | WhiteBalance |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Automatic` |
| Choices | 0 Automatic<br>1 Daylight<br>2 Fluorescent<br>3 Tungsten<br>4 Flash<br>5 Cloudy<br>6 Shade<br>7 Color Temperature<br>8 Preset |

### `/main/imgsettings/colorspace`

| Field | Value |
|---|---|
| Label | Color Space |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `sRGB` |
| Choices | 0 sRGB<br>1 AdobeRGB |

### `/main/imgsettings/autoiso`

| Field | Value |
|---|---|
| Label | Auto ISO |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `On` |
| Choices | 0 On<br>1 Off |

## Capture settings (`/main/capturesettings/`)

### `/main/capturesettings/minimumshutterspeed`

| Field | Value |
|---|---|
| Label | Minimum Shutter Speed |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Unknown value 0020` |
| Choices | 0 1/2000<br>1 1/1600<br>2 1/1250<br>3 1/1000<br>4 1/800<br>5 1/640<br>6 1/500<br>7 1/400<br>8 1/320<br>9 1/250<br>10 1/200<br>11 1/160<br>12 1/125<br>13 1/100<br>14 1/80<br>15 1/60<br>16 1/50<br>17 1/40<br>18 1/30<br>19 1/15<br>20 1/8<br>21 1/4<br>22 1/2<br>23 1<br>24 Unknown value 0018<br>25 Unknown value 0019<br>26 Unknown value 001a<br>27 Unknown value 001b<br>28 Unknown value 001c<br>29 Unknown value 001d<br>30 Unknown value 001e<br>31 Unknown value 001f<br>32 Unknown value 0020 |

### `/main/capturesettings/isoautohilimit`

| Field | Value |
|---|---|
| Label | ISO Auto Hi Limit |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Unknown value 001e` |
| Choices | 0 400<br>1 800<br>2 1600<br>3 3200<br>4 Hi 1<br>5 Hi 2<br>6 Unknown value 0006<br>7 Unknown value 0007<br>8 Unknown value 0008<br>9 Unknown value 0009<br>10 Unknown value 000a<br>11 Unknown value 000b<br>12 Unknown value 000c<br>13 Unknown value 000d<br>14 Unknown value 000e<br>15 Unknown value 000f<br>16 Unknown value 0010<br>17 Unknown value 0011<br>18 Unknown value 0012<br>19 Unknown value 0013<br>20 Unknown value 0014<br>21 Unknown value 0015<br>22 Unknown value 0016<br>23 Unknown value 0017<br>24 Unknown value 0018<br>25 Unknown value 0019<br>26 Unknown value 001a<br>27 Unknown value 001b<br>28 Unknown value 001c<br>29 Unknown value 001d<br>30 Unknown value 001e<br>31 Unknown value 001f<br>32 Unknown value 0020<br>33 Unknown value 0021<br>34 Unknown value 0022<br>35 Unknown value 0023 |

### `/main/capturesettings/dlighting`

| Field | Value |
|---|---|
| Label | Active D-Lighting |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Normal` |
| Choices | 0 Extra high<br>1 High<br>2 Normal<br>3 Low<br>4 Off<br>5 Auto |

### `/main/capturesettings/highisonr`

| Field | Value |
|---|---|
| Label | High ISO Noise Reduction |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Normal` |
| Choices | 0 Off<br>1 Low<br>2 Normal<br>3 High |

### `/main/capturesettings/shootingspeed`

| Field | Value |
|---|---|
| Label | Continuous Shooting Speed Slow |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `1 fps` |
| Choices | 0 4 fps<br>1 3 fps<br>2 2 fps<br>3 1 fps<br>4 Unknown value 0004<br>5 Unknown value 0005 |

### `/main/capturesettings/maximumcontinousrelease`

| Field | Value |
|---|---|
| Label | Maximum continuous release |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `100` |
| Range | `1 / 100 / 1` |

### `/main/capturesettings/moviequality`

| Field | Value |
|---|---|
| Label | Movie Quality |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `320x216` |
| Choices | 0 320x216<br>1 640x424<br>2 1280x720<br>3 Unknown value 0003<br>4 Unknown value 0004<br>5 Unknown value 0005<br>6 Unknown value 0006 |

### `/main/capturesettings/rawcompression`

| Field | Value |
|---|---|
| Label | Raw Compression |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Lossless` |
| Choices | 0 Lossless<br>1 Lossy<br>2 Unknown value 0002 |

### `/main/capturesettings/flashsyncspeed`

| Field | Value |
|---|---|
| Label | Flash Sync. Speed |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `1/250s (Auto FP)` |
| Choices | 0 1/250s (Auto FP)<br>1 1/250s<br>2 1/200s<br>3 1/160s<br>4 1/125s<br>5 1/100s<br>6 1/80s<br>7 1/60s<br>8 Unknown value 0008 |

### `/main/capturesettings/flashshutterspeed`

| Field | Value |
|---|---|
| Label | Flash Shutter Speed |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `1/60s` |
| Choices | 0 1/60s<br>1 1/30s<br>2 1/15s<br>3 1/8s<br>4 1/4s<br>5 1/2s<br>6 1s<br>7 2s<br>8 4s<br>9 8s<br>10 15s<br>11 30s |

### `/main/capturesettings/longexpnr`

| Field | Value |
|---|---|
| Label | Long Exp Noise Reduction |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/assistlight`

| Field | Value |
|---|---|
| Label | Assist Light |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/exposurecompensation`

| Field | Value |
|---|---|
| Label | Exposure Compensation |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `0` |
| Choices | 0 -5<br>1 -4.666<br>2 -4.333<br>3 -4<br>4 -3.666<br>5 -3.333<br>6 -3<br>7 -2.666<br>8 -2.333<br>9 -2<br>10 -1.666<br>11 -1.333<br>12 -1<br>13 -0.666<br>14 -0.333<br>15 0<br>16 0.333<br>17 0.666<br>18 1<br>19 1.333<br>20 1.666<br>21 2<br>22 2.333<br>23 2.666<br>24 3<br>25 3.333<br>26 3.666<br>27 4<br>28 4.333<br>29 4.666<br>30 5 |

### `/main/capturesettings/flashmode`

| Field | Value |
|---|---|
| Label | Flash Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Auto` |
| Choices | 0 Flash off<br>1 Red-eye automatic<br>2 Auto<br>3 Auto Slow Sync<br>4 Rear Curtain Sync + Slow Sync<br>5 Red-eye Reduction + Slow Sync |

### `/main/capturesettings/nikonflashmode`

| Field | Value |
|---|---|
| Label | Nikon Flash Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `iTTL` |
| Choices | 0 iTTL<br>1 Manual<br>2 Commander<br>3 Repeating |

### `/main/capturesettings/f-number`

| Field | Value |
|---|---|
| Label | F-Number |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `f/4` |
| Choices | 0 f/2.8<br>1 f/3.2<br>2 f/3.5<br>3 f/4<br>4 f/4.5<br>5 f/5<br>6 f/5.6<br>7 f/6.3<br>8 f/7.1<br>9 f/8<br>10 f/9<br>11 f/10<br>12 f/11<br>13 f/13<br>14 f/14<br>15 f/16<br>16 f/18<br>17 f/20<br>18 f/22 |

### `/main/capturesettings/movief-number`

| Field | Value |
|---|---|
| Label | Movie F-Number |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `f/2.8` |
| Choices | 0 f/2.8<br>1 f/3.2<br>2 f/3.5<br>3 f/4<br>4 f/4.5<br>5 f/5<br>6 f/5.6<br>7 f/6.3<br>8 f/7.1<br>9 f/8<br>10 f/9<br>11 f/10<br>12 f/11<br>13 f/13<br>14 f/14<br>15 f/16<br>16 f/18<br>17 f/20<br>18 f/22 |

### `/main/capturesettings/flexibleprogram`

| Field | Value |
|---|---|
| Label | Flexible Program |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `0` |
| Range | `-30 / 30 / 2` |

### `/main/capturesettings/imagequality`

| Field | Value |
|---|---|
| Label | Image Quality |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `NEF+Fine` |
| Choices | 0 JPEG Basic<br>1 JPEG Normal<br>2 JPEG Fine<br>3 Unknown value 0003<br>4 NEF (Raw)<br>5 NEF+Basic<br>6 NEF+Normal<br>7 NEF+Fine |

### `/main/capturesettings/focallength`

| Field | Value |
|---|---|
| Label | Focal Length |
| Access | Read-only (`Readonly: 1`) |
| Type | RANGE |
| Current | `70` |
| Range | `28 / 70 / 0.01` |

### `/main/capturesettings/focusmode`

| Field | Value |
|---|---|
| Label | Focus Mode |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `AF-S` |
| Choices | 0 Manual<br>1 AF-S<br>2 AF-C<br>3 Unknown value 8013 |

### `/main/capturesettings/focusmode2`

| Field | Value |
|---|---|
| Label | Focus Mode 2 |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `AF-S` |
| Choices | 0 AF-S<br>1 AF-C<br>2 AF-A<br>3 MF (fixed)<br>4 MF (selection) |

### `/main/capturesettings/expprogram`

| Field | Value |
|---|---|
| Label | Exposure Program |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `A` |
| Choices | 0 M<br>1 P<br>2 A<br>3 S |

### `/main/capturesettings/hdrmode`

| Field | Value |
|---|---|
| Label | HDR Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/hdrhighdynamic`

| Field | Value |
|---|---|
| Label | HDR High Dynamic |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Auto` |
| Choices | 0 Auto<br>1 1 EV<br>2 2 EV<br>3 3 EV |

### `/main/capturesettings/hdrsmoothing`

| Field | Value |
|---|---|
| Label | HDR Smoothing |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Normal` |
| Choices | 0 High<br>1 Normal<br>2 Low |

### `/main/capturesettings/capturemode`

| Field | Value |
|---|---|
| Label | Still Capture Mode |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Single Shot` |
| Choices | 0 Single Shot<br>1 Burst<br>2 Continuous Low Speed<br>3 Timer<br>4 Mirror Up<br>5 Quiet Release<br>6 Unknown value 8018 |

### `/main/capturesettings/focusmetermode`

| Field | Value |
|---|---|
| Label | Focus Metering Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Unknown value 8015` |
| Choices | 0 Multi-spot<br>1 Single Area<br>2 Closest Subject<br>3 Group Dynamic<br>4 Unknown value 8013<br>5 Unknown value 8014<br>6 Unknown value 8015 |

### `/main/capturesettings/exposuremetermode`

| Field | Value |
|---|---|
| Label | Exposure Metering Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Multi Spot` |
| Choices | 0 Center Weighted<br>1 Multi Spot<br>2 Center Spot<br>3 Unknown value 8010 |

### `/main/capturesettings/shutterspeed`

| Field | Value |
|---|---|
| Label | Shutter Speed |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `0.0062s` |
| Choices | 0 0.0001s<br>1 0.0002s<br>2 0.0003s<br>3 0.0004s<br>4 0.0005s<br>5 0.0006s<br>6 0.0008s<br>7 0.0010s<br>8 0.0012s<br>9 0.0015s<br>10 0.0020s<br>11 0.0025s<br>12 0.0031s<br>13 0.0040s<br>14 0.0050s<br>15 0.0062s |

### `/main/capturesettings/shutterspeed2`

| Field | Value |
|---|---|
| Label | Shutter Speed 2 |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `1/160` |
| Choices | 0 1/8000<br>1 1/6400<br>2 1/5000<br>3 1/4000<br>4 1/3200<br>5 1/2500<br>6 1/2000<br>7 1/1600<br>8 1/1250<br>9 1/1000<br>10 1/800<br>11 1/640<br>12 1/500<br>13 1/400<br>14 1/320<br>15 1/250<br>16 1/200<br>17 1/160 |

### `/main/capturesettings/movieshutterspeed`

| Field | Value |
|---|---|
| Label | Movie Shutter Speed 2 |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `1/8000` |
| Choices | 0 1/8000<br>1 1/6400<br>2 1/5000<br>3 1/4000<br>4 1/3200<br>5 1/2500<br>6 1/2000<br>7 1/1600<br>8 1/1250<br>9 1/1000<br>10 1/800<br>11 1/640<br>12 1/500<br>13 1/400<br>14 1/320<br>15 1/250<br>16 1/200<br>17 1/160<br>18 1/125<br>19 1/100<br>20 1/80<br>21 1/60 |

### `/main/capturesettings/focusareawrap`

| Field | Value |
|---|---|
| Label | Focus Area Wrap |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/exposuredelaymode`

| Field | Value |
|---|---|
| Label | Exposure Delay Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `On` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/liveviewafmode`

| Field | Value |
|---|---|
| Label | Live View AF Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Normal-area AF` |
| Choices | 0 Face-priority AF<br>1 Wide-area AF<br>2 Normal-area AF<br>3 Subject-tracking AF |

### `/main/capturesettings/liveviewaffocus`

| Field | Value |
|---|---|
| Label | Live View AF Focus |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Single-servo AF` |
| Choices | 0 Single-servo AF<br>1 Full-time-servo AF<br>2 Unknown value 0003<br>3 Manual Focus |

### `/main/capturesettings/filenrsequencing`

| Field | Value |
|---|---|
| Label | File Number Sequencing |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `On` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/imagerotationflag`

| Field | Value |
|---|---|
| Label | Image Rotation Flag |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/nocfcardrelease`

| Field | Value |
|---|---|
| Label | Release without CF card |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/autofocusarea`

| Field | Value |
|---|---|
| Label | Auto Focus Area |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Top` |
| Choices | 0 Top<br>1 Bottom<br>2 Left<br>3 Right<br>4 Unknown value 0005<br>5 Unknown value 0006<br>6 Unknown value 0007<br>7 Unknown value 0008<br>8 Unknown value 0009<br>9 Unknown value 000a<br>10 Unknown value 000b<br>11 Unknown value 000c<br>12 Unknown value 000d<br>13 Unknown value 000e<br>14 Unknown value 000f<br>15 Unknown value 0010<br>16 Unknown value 0011<br>17 Unknown value 0012<br>18 Unknown value 0013<br>19 Unknown value 0014<br>20 Unknown value 0015<br>21 Unknown value 0016<br>22 Unknown value 0017<br>23 Unknown value 0018<br>24 Unknown value 0019<br>25 Unknown value 001a<br>26 Unknown value 001b<br>27 Unknown value 001c<br>28 Unknown value 001d<br>29 Unknown value 001e<br>30 Unknown value 001f<br>31 Unknown value 0020<br>32 Unknown value 0021<br>33 Unknown value 0022<br>34 Unknown value 0023<br>35 Unknown value 0024<br>36 Unknown value 0025<br>37 Unknown value 0026<br>38 Unknown value 0027<br>39 Unknown value 0028<br>40 Unknown value 0029<br>41 Unknown value 002a<br>42 Unknown value 002b<br>43 Unknown value 002c<br>44 Unknown value 002d<br>45 Unknown value 002e<br>46 Unknown value 002f<br>47 Unknown value 0030<br>48 Unknown value 0031<br>49 Unknown value 0032<br>50 Unknown value 0033 |

### `/main/capturesettings/flashexposurecompensation`

| Field | Value |
|---|---|
| Label | Flash Exposure Compensation |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `0` |
| Range | `-3 / 1 / 0.333333` |

### `/main/capturesettings/bracketing`

| Field | Value |
|---|---|
| Label | Bracketing |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Off` |
| Choices | 0 On<br>1 Off |

### `/main/capturesettings/bracketmode`

| Field | Value |
|---|---|
| Label | Bracketing |
| Access | Read-only (`Readonly: 1`) |
| Type | RADIO |
| Current | `Flash/speed` |
| Choices | 0 Flash/speed<br>1 Flash/speed/aperture<br>2 Flash/aperture<br>3 Flash only |

### `/main/capturesettings/evstep`

| Field | Value |
|---|---|
| Label | EV Step |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `1/3` |
| Choices | 0 1/3<br>1 1/2<br>2 Unknown value 0002 |

### `/main/capturesettings/bracketset`

| Field | Value |
|---|---|
| Label | Bracket Set |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `AE & Flash` |
| Choices | 0 AE & Flash<br>1 AE only<br>2 Flash only<br>3 WB bracketing<br>4 ADL bracketing |

### `/main/capturesettings/bracketorder`

| Field | Value |
|---|---|
| Label | Bracket Order |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `MTR > Under` |
| Choices | 0 MTR > Under<br>1 Under > MTR |

### `/main/capturesettings/burstnumber`

| Field | Value |
|---|---|
| Label | Burst Number |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `1` |
| Range | `1 / 100 / 1` |

### `/main/capturesettings/whitebiaspresetno`

| Field | Value |
|---|---|
| Label | White Balance Bias Preset Nr |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `1` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5 |

### `/main/capturesettings/whitebiaspreset1`

| Field | Value |
|---|---|
| Label | White Balance Bias Preset 1 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/capturesettings/whitebiaspreset2`

| Field | Value |
|---|---|
| Label | White Balance Bias Preset 2 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/capturesettings/whitebiaspreset3`

| Field | Value |
|---|---|
| Label | White Balance Bias Preset 3 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/capturesettings/whitebiaspreset4`

| Field | Value |
|---|---|
| Label | White Balance Bias Preset 4 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/capturesettings/centerweightsize`

| Field | Value |
|---|---|
| Label | Center Weight Area |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Average` |
| Choices | 0 6 mm<br>1 8 mm<br>2 10 mm<br>3 12 mm<br>4 Average |

### `/main/capturesettings/applicationmode`

| Field | Value |
|---|---|
| Label | Application Mode |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Application Mode 0` |
| Choices | 0 Application Mode 0<br>1 Application Mode 1 |

### `/main/capturesettings/microphone`

| Field | Value |
|---|---|
| Label | Microphone |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `Auto sensitivity` |
| Choices | 0 Auto sensitivity<br>1 High sensitivity<br>2 Medium sensitivity<br>3 Low sensitivity<br>4 Microphone off<br>5 Unknown value 0005 |

### `/main/capturesettings/autodistortioncontrol`

| Field | Value |
|---|---|
| Label | Auto Distortion Control |
| Access | Writable (`Readonly: 0`) |
| Type | RADIO |
| Current | `On` |
| Choices | 0 On<br>1 Off |

## Nikon/vendor PTP properties (`/main/other/`)

### `/main/other/5001`

| Field | Value |
|---|---|
| Label | Battery Level |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `20` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 7<br>7 8<br>8 9<br>9 10<br>10 11<br>11 12<br>12 13<br>13 14<br>14 15<br>15 16<br>16 17<br>17 18<br>18 19<br>19 20<br>20 21<br>21 22<br>22 23<br>23 24<br>24 25<br>25 26<br>26 27<br>27 28<br>28 29<br>29 30<br>30 31<br>31 32<br>32 33<br>33 34<br>34 35<br>35 36<br>36 37<br>37 38<br>38 39<br>39 40<br>40 41<br>41 42<br>42 43<br>43 44<br>44 45<br>45 46<br>46 47<br>47 48<br>48 49<br>49 50<br>50 51<br>51 52<br>52 53<br>53 54<br>54 55<br>55 56<br>56 57<br>57 58<br>58 59<br>59 60<br>60 61<br>61 62<br>62 63<br>63 64<br>64 65<br>65 66<br>66 67<br>67 68<br>68 69<br>69 70<br>70 71<br>71 72<br>72 73<br>73 74<br>74 75<br>75 76<br>76 77<br>77 78<br>78 79<br>79 80<br>80 81<br>81 82<br>82 83<br>83 84<br>84 85<br>85 86<br>86 87<br>87 88<br>88 89<br>89 90<br>90 91<br>91 92<br>92 93<br>93 94<br>94 95<br>95 96<br>96 97<br>97 98<br>98 99<br>99 100 |

### `/main/other/5003`

| Field | Value |
|---|---|
| Label | Image Size |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `7360x4912` |
| Choices | 0 7360x4912<br>1 5520x3680<br>2 3680x2456 |

### `/main/other/5004`

| Field | Value |
|---|---|
| Label | Compression Setting |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `7` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7 |

### `/main/other/5005`

| Field | Value |
|---|---|
| Label | White Balance |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 2<br>1 4<br>2 5<br>3 6<br>4 7<br>5 32784<br>6 32785<br>7 32786<br>8 32787 |

### `/main/other/5007`

| Field | Value |
|---|---|
| Label | F-Number |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `400` |
| Choices | 0 280<br>1 320<br>2 350<br>3 400<br>4 450<br>5 500<br>6 560<br>7 630<br>8 710<br>9 800<br>10 900<br>11 1000<br>12 1100<br>13 1300<br>14 1400<br>15 1600<br>16 1800<br>17 2000<br>18 2200 |

### `/main/other/5008`

| Field | Value |
|---|---|
| Label | Focal Length |
| Access | Read-only (`Readonly: 1`) |
| Type | RANGE |
| Current | `7000` |
| Range | `2800 / 7000 / 1` |

### `/main/other/500a`

| Field | Value |
|---|---|
| Label | Focus Mode |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `32784` |
| Choices | 0 1<br>1 32784<br>2 32785<br>3 32787 |

### `/main/other/500b`

| Field | Value |
|---|---|
| Label | Exposure Metering Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 2<br>1 3<br>2 4<br>3 32784 |

### `/main/other/500c`

| Field | Value |
|---|---|
| Label | Flash Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `32784` |
| Choices | 0 2<br>1 4<br>2 32784<br>3 32785<br>4 32786<br>5 32787 |

### `/main/other/500d`

| Field | Value |
|---|---|
| Label | Exposure Time |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `62` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 8<br>7 10<br>8 12<br>9 15<br>10 20<br>11 25<br>12 31<br>13 40<br>14 50<br>15 62 |

### `/main/other/500e`

| Field | Value |
|---|---|
| Label | Exposure Program Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4 |

### `/main/other/500f`

| Field | Value |
|---|---|
| Label | Exposure Index (film speed ISO) |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `400` |
| Choices | 0 32<br>1 40<br>2 50<br>3 64<br>4 80<br>5 100<br>6 125<br>7 160<br>8 200<br>9 250<br>10 320<br>11 400<br>12 500<br>13 640<br>14 800<br>15 1000<br>16 1250<br>17 1600<br>18 2000<br>19 2500<br>20 3200<br>21 4000<br>22 5000<br>23 6400<br>24 8000<br>25 10000<br>26 12800<br>27 16000<br>28 20000<br>29 25600<br>30 51200 |

### `/main/other/5010`

| Field | Value |
|---|---|
| Label | Exposure Bias Compensation |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -5000<br>1 -4666<br>2 -4333<br>3 -4000<br>4 -3666<br>5 -3333<br>6 -3000<br>7 -2666<br>8 -2333<br>9 -2000<br>10 -1666<br>11 -1333<br>12 -1000<br>13 -666<br>14 -333<br>15 0<br>16 333<br>17 666<br>18 1000<br>19 1333<br>20 1666<br>21 2000<br>22 2333<br>23 2666<br>24 3000<br>25 3333<br>26 3666<br>27 4000<br>28 4333<br>29 4666<br>30 5000 |

### `/main/other/5011`

| Field | Value |
|---|---|
| Label | Date & Time |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `20260727T002447` |

### `/main/other/5013`

| Field | Value |
|---|---|
| Label | Still Capture Mode |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 1<br>1 2<br>2 32784<br>3 32785<br>4 32786<br>5 32790<br>6 32792 |

### `/main/other/5018`

| Field | Value |
|---|---|
| Label | Burst Number |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 7<br>7 8<br>8 9<br>9 10<br>10 11<br>11 12<br>12 13<br>13 14<br>14 15<br>15 16<br>16 17<br>17 18<br>18 19<br>19 20<br>20 21<br>21 22<br>22 23<br>23 24<br>24 25<br>25 26<br>26 27<br>27 28<br>28 29<br>29 30<br>30 31<br>31 32<br>32 33<br>33 34<br>34 35<br>35 36<br>36 37<br>37 38<br>38 39<br>39 40<br>40 41<br>41 42<br>42 43<br>43 44<br>44 45<br>45 46<br>46 47<br>47 48<br>48 49<br>49 50<br>50 51<br>51 52<br>52 53<br>53 54<br>54 55<br>55 56<br>56 57<br>57 58<br>58 59<br>59 60<br>60 61<br>61 62<br>62 63<br>63 64<br>64 65<br>65 66<br>66 67<br>67 68<br>68 69<br>69 70<br>70 71<br>71 72<br>72 73<br>73 74<br>74 75<br>75 76<br>76 77<br>77 78<br>78 79<br>79 80<br>80 81<br>81 82<br>82 83<br>83 84<br>84 85<br>85 86<br>86 87<br>87 88<br>88 89<br>89 90<br>90 91<br>91 92<br>92 93<br>93 94<br>94 95<br>95 96<br>96 97<br>97 98<br>98 99<br>99 100 |

### `/main/other/501c`

| Field | Value |
|---|---|
| Label | Focus Metering Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `32789` |
| Choices | 0 2<br>1 32784<br>2 32785<br>3 32786<br>4 32787<br>5 32788<br>6 32789 |

### `/main/other/501e`

| Field | Value |
|---|---|
| Label | Artist |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `` |

### `/main/other/501f`

| Field | Value |
|---|---|
| Label | Copyright Info |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `` |

### `/main/other/d303`

| Field | Value |
|---|---|
| Label | PTP Property 0xd303 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `1` |

### `/main/other/d406`

| Field | Value |
|---|---|
| Label | PTP Property 0xd406 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `Windows/6.0.5330.0 MTPClassDriver/6.0.5330.0` |

### `/main/other/d407`

| Field | Value |
|---|---|
| Label | PTP Property 0xd407 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `1` |

### `/main/other/d010`

| Field | Value |
|---|---|
| Label | Shooting Bank |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d011`

| Field | Value |
|---|---|
| Label | Shooting Bank Name A |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d012`

| Field | Value |
|---|---|
| Label | Shooting Bank Name B |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d013`

| Field | Value |
|---|---|
| Label | Shooting Bank Name C |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d014`

| Field | Value |
|---|---|
| Label | Shooting Bank Name D |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d015`

| Field | Value |
|---|---|
| Label | Reset Bank 0 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d016`

| Field | Value |
|---|---|
| Label | Raw Compression |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d017`

| Field | Value |
|---|---|
| Label | Auto White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d018`

| Field | Value |
|---|---|
| Label | Tungsten White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d019`

| Field | Value |
|---|---|
| Label | Fluorescent White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d01a`

| Field | Value |
|---|---|
| Label | Daylight White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d01b`

| Field | Value |
|---|---|
| Label | Flash White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d01c`

| Field | Value |
|---|---|
| Label | Cloudy White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d01d`

| Field | Value |
|---|---|
| Label | Shady White Balance Bias |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d01e`

| Field | Value |
|---|---|
| Label | White Balance Colour Temperature |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `4760` |
| Range | `2500 / 10000 / 10` |

### `/main/other/d01f`

| Field | Value |
|---|---|
| Label | White Balance Preset Number |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6 |

### `/main/other/d021`

| Field | Value |
|---|---|
| Label | White Balance Preset Name 1 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d022`

| Field | Value |
|---|---|
| Label | White Balance Preset Name 2 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d023`

| Field | Value |
|---|---|
| Label | White Balance Preset Name 3 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d024`

| Field | Value |
|---|---|
| Label | White Balance Preset Name 4 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d026`

| Field | Value |
|---|---|
| Label | White Balance Preset Value 1 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/other/d027`

| Field | Value |
|---|---|
| Label | White Balance Preset Value 2 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/other/d028`

| Field | Value |
|---|---|
| Label | White Balance Preset Value 3 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/other/d029`

| Field | Value |
|---|---|
| Label | White Balance Preset Value 4 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/other/d02e`

| Field | Value |
|---|---|
| Label | Lens Focal Length (Non CPU) |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `17` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22<br>23 23<br>24 24<br>25 25<br>26 26<br>27 27<br>28 28<br>29 29<br>30 30<br>31 31<br>32 32<br>33 33<br>34 34<br>35 35<br>36 36<br>37 37<br>38 38<br>39 39<br>40 40 |

### `/main/other/d02f`

| Field | Value |
|---|---|
| Label | Lens Maximum Aperture (Non CPU) |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `10` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22 |

### `/main/other/d030`

| Field | Value |
|---|---|
| Label | Shooting Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d031`

| Field | Value |
|---|---|
| Label | JPEG Compression Policy |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d032`

| Field | Value |
|---|---|
| Label | Color Space |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d033`

| Field | Value |
|---|---|
| Label | Auto DX Crop |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d034`

| Field | Value |
|---|---|
| Label | Flicker Reduction |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d038`

| Field | Value |
|---|---|
| Label | PTP Property 0xd038 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d039`

| Field | Value |
|---|---|
| Label | PTP Property 0xd039 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d03a`

| Field | Value |
|---|---|
| Label | PTP Property 0xd03a |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d03b`

| Field | Value |
|---|---|
| Label | PTP Property 0xd03b |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d03c`

| Field | Value |
|---|---|
| Label | PTP Property 0xd03c |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d03d`

| Field | Value |
|---|---|
| Label | PTP Property 0xd03d |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d03e`

| Field | Value |
|---|---|
| Label | PTP Property 0xd03e |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/other/d03f`

| Field | Value |
|---|---|
| Label | PTP Property 0xd03f |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `32833877` |

### `/main/other/d040`

| Field | Value |
|---|---|
| Label | PTP_DPC_NIKON_CSMMenuBankSelect |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d041`

| Field | Value |
|---|---|
| Label | Menu Bank Name A |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d042`

| Field | Value |
|---|---|
| Label | Menu Bank Name B |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d043`

| Field | Value |
|---|---|
| Label | Menu Bank Name C |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d044`

| Field | Value |
|---|---|
| Label | Menu Bank Name D |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                    ` |

### `/main/other/d045`

| Field | Value |
|---|---|
| Label | Reset Menu Bank |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d048`

| Field | Value |
|---|---|
| Label | PTP_DPC_NIKON_A1AFCModePriority |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d049`

| Field | Value |
|---|---|
| Label | PTP_DPC_NIKON_A2AFSModePriority |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d04f`

| Field | Value |
|---|---|
| Label | Focus Area Wrap |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d051`

| Field | Value |
|---|---|
| Label | AF Lock On |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5 |

### `/main/other/d053`

| Field | Value |
|---|---|
| Label | Enable Copyright |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d054`

| Field | Value |
|---|---|
| Label | Auto ISO |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d055`

| Field | Value |
|---|---|
| Label | Exposure ISO Step |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d056`

| Field | Value |
|---|---|
| Label | Exposure Step |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d057`

| Field | Value |
|---|---|
| Label | Exposure Compensation (EV) |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d059`

| Field | Value |
|---|---|
| Label | Centre Weight Area |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `4` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4 |

### `/main/other/d05a`

| Field | Value |
|---|---|
| Label | Exposure Base Matrix |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -6<br>1 -5<br>2 -4<br>3 -3<br>4 -2<br>5 -1<br>6 0<br>7 1<br>8 2<br>9 3<br>10 4<br>11 5<br>12 6 |

### `/main/other/d05b`

| Field | Value |
|---|---|
| Label | Exposure Base Center |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -6<br>1 -5<br>2 -4<br>3 -3<br>4 -2<br>5 -1<br>6 0<br>7 1<br>8 2<br>9 3<br>10 4<br>11 5<br>12 6 |

### `/main/other/d05c`

| Field | Value |
|---|---|
| Label | Exposure Base Spot |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -6<br>1 -5<br>2 -4<br>3 -3<br>4 -2<br>5 -1<br>6 0<br>7 1<br>8 2<br>9 3<br>10 4<br>11 5<br>12 6 |

### `/main/other/d05d`

| Field | Value |
|---|---|
| Label | Live View AF Area |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d061`

| Field | Value |
|---|---|
| Label | Live View AF Focus |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 2<br>2 3<br>3 4 |

### `/main/other/d067`

| Field | Value |
|---|---|
| Label | Angle Level |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `46080` |

### `/main/other/d068`

| Field | Value |
|---|---|
| Label | Shooting Speed |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5 |

### `/main/other/d069`

| Field | Value |
|---|---|
| Label | Maximum Shots |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `100` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 7<br>7 8<br>8 9<br>9 10<br>10 11<br>11 12<br>12 13<br>13 14<br>14 15<br>15 16<br>16 17<br>17 18<br>18 19<br>19 20<br>20 21<br>21 22<br>22 23<br>23 24<br>24 25<br>25 26<br>26 27<br>27 28<br>28 29<br>29 30<br>30 31<br>31 32<br>32 33<br>33 34<br>34 35<br>35 36<br>36 37<br>37 38<br>38 39<br>39 40<br>40 41<br>41 42<br>42 43<br>43 44<br>44 45<br>45 46<br>46 47<br>47 48<br>48 49<br>49 50<br>50 51<br>51 52<br>52 53<br>53 54<br>54 55<br>55 56<br>56 57<br>57 58<br>58 59<br>59 60<br>60 61<br>61 62<br>62 63<br>63 64<br>64 65<br>65 66<br>66 67<br>67 68<br>68 69<br>69 70<br>70 71<br>71 72<br>72 73<br>73 74<br>74 75<br>75 76<br>76 77<br>77 78<br>78 79<br>79 80<br>80 81<br>81 82<br>82 83<br>83 84<br>84 85<br>85 86<br>86 87<br>87 88<br>88 89<br>89 90<br>90 91<br>91 92<br>92 93<br>93 94<br>94 95<br>95 96<br>96 97<br>97 98<br>98 99<br>99 100 |

### `/main/other/d06a`

| Field | Value |
|---|---|
| Label | Exposure delay mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d06b`

| Field | Value |
|---|---|
| Label | Long Exposure Noise Reduction |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d06c`

| Field | Value |
|---|---|
| Label | File Number Sequencing |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d070`

| Field | Value |
|---|---|
| Label | High ISO noise reduction |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d072`

| Field | Value |
|---|---|
| Label | Artist Name |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `` |

### `/main/other/d073`

| Field | Value |
|---|---|
| Label | Copyright Information |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `` |

### `/main/other/d074`

| Field | Value |
|---|---|
| Label | Flash Sync. Speed |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8 |

### `/main/other/d075`

| Field | Value |
|---|---|
| Label | Flash Shutter Speed |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11 |

### `/main/other/d078`

| Field | Value |
|---|---|
| Label | Bracket Set |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4 |

### `/main/other/d079`

| Field | Value |
|---|---|
| Label | Manual Mode Bracketing |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d07a`

| Field | Value |
|---|---|
| Label | Bracket Order |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d07d`

| Field | Value |
|---|---|
| Label | PTP Property 0xd07d |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `22689508` |

### `/main/other/d07e`

| Field | Value |
|---|---|
| Label | PTP Property 0xd07e |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `-1` |

### `/main/other/d07f`

| Field | Value |
|---|---|
| Label | PTP Property 0xd07f |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d087`

| Field | Value |
|---|---|
| Label | Aperture Setting |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d08a`

| Field | Value |
|---|---|
| Label | No CF Card Release |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d08d`

| Field | Value |
|---|---|
| Label | AF Area Point |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d08f`

| Field | Value |
|---|---|
| Label | Clean Image Sensor |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d090`

| Field | Value |
|---|---|
| Label | Image Comment String |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `                                    ` |

### `/main/other/d091`

| Field | Value |
|---|---|
| Label | Image Comment Enable |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d092`

| Field | Value |
|---|---|
| Label | Image Rotation |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d093`

| Field | Value |
|---|---|
| Label | Manual Set Lens Number |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8 |

### `/main/other/d09c`

| Field | Value |
|---|---|
| Label | PTP Property 0xd09c |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0a0`

| Field | Value |
|---|---|
| Label | Movie Screen Size |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6 |

### `/main/other/d0a2`

| Field | Value |
|---|---|
| Label | Movie Microphone |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5 |

### `/main/other/d0a3`

| Field | Value |
|---|---|
| Label | Movie Card Slot |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0a4`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0a4 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `0` |

### `/main/other/d0a7`

| Field | Value |
|---|---|
| Label | Movie Quality |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0a8`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0a8 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `15` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 7<br>7 8<br>8 9<br>9 10<br>10 11<br>11 12<br>12 13<br>13 14<br>14 15<br>15 16<br>16 17<br>17 18<br>18 19<br>19 20 |

### `/main/other/d0aa`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0aa |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0ac`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0ac |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0ad`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0ad |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0ae`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0ae |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `24` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22<br>23 23<br>24 24<br>25 25<br>26 26<br>27 27<br>28 28<br>29 29 |

### `/main/other/d0b5`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0b5 |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `4000` |

### `/main/other/d0b6`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0b6 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `7360x4912` |
| Choices | 0 7360x4912<br>1 3680x2456 |

### `/main/other/d0c0`

| Field | Value |
|---|---|
| Label | Bracketing Enable |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0c1`

| Field | Value |
|---|---|
| Label | Exposure Bracketing Step |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5 |

### `/main/other/d0c2`

| Field | Value |
|---|---|
| Label | Exposure Bracketing Program |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7 |

### `/main/other/d0c3`

| Field | Value |
|---|---|
| Label | Auto Exposure Bracket Count |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 1 |

### `/main/other/d0c4`

| Field | Value |
|---|---|
| Label | White Balance Bracket Step |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d0c5`

| Field | Value |
|---|---|
| Label | White Balance Bracket Program |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `4` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7 |

### `/main/other/d0c6`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0c6 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d0c7`

| Field | Value |
|---|---|
| Label | PTP Property 0xd0c7 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4 |

### `/main/other/d0e0`

| Field | Value |
|---|---|
| Label | Lens ID |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `65256` |

### `/main/other/d0e1`

| Field | Value |
|---|---|
| Label | Lens Sort |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d0e2`

| Field | Value |
|---|---|
| Label | Lens Type |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `3` |

### `/main/other/d0e3`

| Field | Value |
|---|---|
| Label | Min. Focal Length |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `2800` |

### `/main/other/d0e4`

| Field | Value |
|---|---|
| Label | Max. Focal Length |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `7000` |

### `/main/other/d0e5`

| Field | Value |
|---|---|
| Label | Max. Aperture at Min. Focal Length |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `280` |

### `/main/other/d0e6`

| Field | Value |
|---|---|
| Label | Max. Aperture at Max. Focal Length |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `280` |

### `/main/other/d0f7`

| Field | Value |
|---|---|
| Label | Vignette Control |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d0f8`

| Field | Value |
|---|---|
| Label | Auto Distortion Control |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d100`

| Field | Value |
|---|---|
| Label | Nikon Exposure Time |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `65696` |
| Choices | 0 73536<br>1 71936<br>2 70536<br>3 69536<br>4 68736<br>5 68036<br>6 67536<br>7 67136<br>8 66786<br>9 66536<br>10 66336<br>11 66176<br>12 66036<br>13 65936<br>14 65856<br>15 65786<br>16 65736<br>17 65696 |

### `/main/other/d101`

| Field | Value |
|---|---|
| Label | AC Power |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d102`

| Field | Value |
|---|---|
| Label | Warning Status |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `0` |

### `/main/other/d104`

| Field | Value |
|---|---|
| Label | AF Locked |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d105`

| Field | Value |
|---|---|
| Label | AE Locked |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d106`

| Field | Value |
|---|---|
| Label | FV Locked |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d108`

| Field | Value |
|---|---|
| Label | Active AF Sensor |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 7<br>7 8<br>8 9<br>9 10<br>10 11<br>11 12<br>12 13<br>13 14<br>14 15<br>15 16<br>16 17<br>17 18<br>18 19<br>19 20<br>20 21<br>21 22<br>22 23<br>23 24<br>24 25<br>25 26<br>26 27<br>27 28<br>28 29<br>29 30<br>30 31<br>31 32<br>32 33<br>33 34<br>34 35<br>35 36<br>36 37<br>37 38<br>38 39<br>39 40<br>40 41<br>41 42<br>42 43<br>43 44<br>44 45<br>45 46<br>46 47<br>47 48<br>48 49<br>49 50<br>50 51 |

### `/main/other/d109`

| Field | Value |
|---|---|
| Label | Flexible Program |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `0` |
| Range | `-30 / 30 / 2` |

### `/main/other/d10b`

| Field | Value |
|---|---|
| Label | Recording Media |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d10c`

| Field | Value |
|---|---|
| Label | USB Speed |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d10e`

| Field | Value |
|---|---|
| Label | Camera Orientation |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d112`

| Field | Value |
|---|---|
| Label | TV Lock Setting |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d113`

| Field | Value |
|---|---|
| Label | AV Lock Setting |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d120`

| Field | Value |
|---|---|
| Label | External Flash Attached |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d121`

| Field | Value |
|---|---|
| Label | External Flash Status |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d122`

| Field | Value |
|---|---|
| Label | External Flash Sort |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d124`

| Field | Value |
|---|---|
| Label | External Flash Compensation |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -18<br>1 -17<br>2 -16<br>3 -15<br>4 -14<br>5 -13<br>6 -12<br>7 -11<br>8 -10<br>9 -9<br>10 -8<br>11 -7<br>12 -6<br>13 -5<br>14 -4<br>15 -3<br>16 -2<br>17 -1<br>18 0<br>19 1<br>20 2<br>21 3<br>22 4<br>23 5<br>24 6<br>25 7<br>26 8<br>27 9<br>28 10<br>29 11<br>30 12<br>31 13<br>32 14<br>33 15<br>34 16<br>35 17<br>36 18 |

### `/main/other/d125`

| Field | Value |
|---|---|
| Label | External Flash Mode |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7 |

### `/main/other/d126`

| Field | Value |
|---|---|
| Label | Flash Exposure Compensation |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `0` |
| Range | `-18 / 6 / 2` |

### `/main/other/d12d`

| Field | Value |
|---|---|
| Label | PTP Property 0xd12d |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d130`

| Field | Value |
|---|---|
| Label | HDR Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d131`

| Field | Value |
|---|---|
| Label | HDR High Dynamic |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d132`

| Field | Value |
|---|---|
| Label | HDR Smoothing |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d141`

| Field | Value |
|---|---|
| Label | PTP Property 0xd141 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d148`

| Field | Value |
|---|---|
| Label | Slot 2 Save Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d149`

| Field | Value |
|---|---|
| Label | Raw Bit Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d14e`

| Field | Value |
|---|---|
| Label | Active D-Lighting |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5 |

### `/main/other/d14f`

| Field | Value |
|---|---|
| Label | Flourescent Type |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6 |

### `/main/other/d150`

| Field | Value |
|---|---|
| Label | Tune Colour Temperature |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `24` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22<br>23 23<br>24 24<br>25 25<br>26 26<br>27 27<br>28 28<br>29 29<br>30 30<br>31 31<br>32 32<br>33 33<br>34 34<br>35 35<br>36 36<br>37 37<br>38 38<br>39 39<br>40 40<br>41 41<br>42 42<br>43 43<br>44 44<br>45 45<br>46 46<br>47 47<br>48 48 |

### `/main/other/d152`

| Field | Value |
|---|---|
| Label | Tune Preset 1 |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d153`

| Field | Value |
|---|---|
| Label | Tune Preset 2 |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d154`

| Field | Value |
|---|---|
| Label | Tune Preset 3 |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d155`

| Field | Value |
|---|---|
| Label | Tune Preset 4 |
| Access | Writable (`Readonly: 0`) |
| Type | RANGE |
| Current | `612` |
| Range | `0 / 1224 / 1` |

### `/main/other/d156`

| Field | Value |
|---|---|
| Label | PTP Property 0xd156 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d158`

| Field | Value |
|---|---|
| Label | PTP Property 0xd158 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d159`

| Field | Value |
|---|---|
| Label | PTP Property 0xd159 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d15a`

| Field | Value |
|---|---|
| Label | PTP Property 0xd15a |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d15b`

| Field | Value |
|---|---|
| Label | PTP Property 0xd15b |
| Access | Read-only (`Readonly: 1`) |
| Type | RANGE |
| Current | `100` |
| Range | `100 / 999 / 1` |

### `/main/other/d15c`

| Field | Value |
|---|---|
| Label | PTP Property 0xd15c |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d15d`

| Field | Value |
|---|---|
| Label | PTP Property 0xd15d |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d161`

| Field | Value |
|---|---|
| Label | Autofocus Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4 |

### `/main/other/d163`

| Field | Value |
|---|---|
| Label | AF Assist Lamp |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d164`

| Field | Value |
|---|---|
| Label | Auto ISO P/A/DVP Setting |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `32` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22<br>23 23<br>24 24<br>25 25<br>26 26<br>27 27<br>28 28<br>29 29<br>30 30<br>31 31<br>32 32 |

### `/main/other/d167`

| Field | Value |
|---|---|
| Label | Flash Mode |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d176`

| Field | Value |
|---|---|
| Label | PTP Property 0xd176 |
| Access | Writable (`Readonly: 0`) |
| Type | TEXT |
| Current | `0` |

### `/main/other/d177`

| Field | Value |
|---|---|
| Label | PTP Property 0xd177 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2 |

### `/main/other/d183`

| Field | Value |
|---|---|
| Label | ISO Auto High Limit |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `30` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22<br>23 23<br>24 24<br>25 25<br>26 26<br>27 27<br>28 28<br>29 29<br>30 30<br>31 31<br>32 32<br>33 33<br>34 34<br>35 35 |

### `/main/other/d197`

| Field | Value |
|---|---|
| Label | PTP Property 0xd197 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1a2`

| Field | Value |
|---|---|
| Label | Live View Status |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1a3`

| Field | Value |
|---|---|
| Label | Live View Image Zoom Ratio |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7 |

### `/main/other/d1a4`

| Field | Value |
|---|---|
| Label | Live View Prohibit Condition |
| Access | Read-only (`Readonly: 1`) |
| Type | TEXT |
| Current | `0` |

### `/main/other/d1a5`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1a5 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1a6`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1a6 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1a7`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1a7 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `32788` |
| Choices | 0 2<br>1 4<br>2 5<br>3 6<br>4 7<br>5 32784<br>6 32785<br>7 32786<br>8 32787<br>9 32788 |

### `/main/other/d1a8`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1a8 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `73536` |
| Choices | 0 73536<br>1 71936<br>2 70536<br>3 69536<br>4 68736<br>5 68036<br>6 67536<br>7 67136<br>8 66786<br>9 66536<br>10 66336<br>11 66176<br>12 66036<br>13 65936<br>14 65856<br>15 65786<br>16 65736<br>17 65696<br>18 65661<br>19 65636<br>20 65616<br>21 65596 |

### `/main/other/d1a9`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1a9 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `280` |
| Choices | 0 280<br>1 320<br>2 350<br>3 400<br>4 450<br>5 500<br>6 560<br>7 630<br>8 710<br>9 800<br>10 900<br>11 1000<br>12 1100<br>13 1300<br>14 1400<br>15 1600<br>16 1800<br>17 2000<br>18 2200 |

### `/main/other/d1aa`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1aa |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `100` |
| Choices | 0 64<br>1 80<br>2 100<br>3 125<br>4 160<br>5 200<br>6 250<br>7 320<br>8 400<br>9 500<br>10 640<br>11 800<br>12 1000<br>13 1250<br>14 1600<br>15 2000<br>16 2500<br>17 3200<br>18 4000<br>19 5000<br>20 6400<br>21 8000<br>22 10000<br>23 12800<br>24 16000<br>25 20000<br>26 25600<br>27 51200 |

### `/main/other/d1ab`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1ab |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -3000<br>1 -2666<br>2 -2333<br>3 -2000<br>4 -1666<br>5 -1333<br>6 -1000<br>7 -666<br>8 -333<br>9 0<br>10 333<br>11 666<br>12 1000<br>13 1333<br>14 1666<br>15 2000<br>16 2333<br>17 2666<br>18 3000 |

### `/main/other/d1ac`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1ac |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 1<br>1 2 |

### `/main/other/d1af`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1af |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `2` |
| Choices | 0 2<br>1 3<br>2 32784 |

### `/main/other/d1b0`

| Field | Value |
|---|---|
| Label | Exposure Display Status |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d1b1`

| Field | Value |
|---|---|
| Label | Exposure Indicate Status |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -60<br>1 -59<br>2 -58<br>3 -57<br>4 -56<br>5 -55<br>6 -54<br>7 -53<br>8 -52<br>9 -51<br>10 -50<br>11 -49<br>12 -48<br>13 -47<br>14 -46<br>15 -45<br>16 -44<br>17 -43<br>18 -42<br>19 -41<br>20 -40<br>21 -39<br>22 -38<br>23 -37<br>24 -36<br>25 -35<br>26 -34<br>27 -33<br>28 -32<br>29 -31<br>30 -30<br>31 -29<br>32 -28<br>33 -27<br>34 -26<br>35 -25<br>36 -24<br>37 -23<br>38 -22<br>39 -21<br>40 -20<br>41 -19<br>42 -18<br>43 -17<br>44 -16<br>45 -15<br>46 -14<br>47 -13<br>48 -12<br>49 -11<br>50 -10<br>51 -9<br>52 -8<br>53 -7<br>54 -6<br>55 -5<br>56 -4<br>57 -3<br>58 -2<br>59 -1<br>60 0<br>61 1<br>62 2<br>63 3<br>64 4<br>65 5<br>66 6<br>67 7<br>68 8<br>69 9<br>70 10<br>71 11<br>72 12<br>73 13<br>74 14<br>75 15<br>76 16<br>77 17<br>78 18<br>79 19<br>80 20<br>81 21<br>82 22<br>83 23<br>84 24<br>85 25<br>86 26<br>87 27<br>88 28<br>89 29<br>90 30<br>91 31<br>92 32<br>93 33<br>94 34<br>95 35<br>96 36<br>97 37<br>98 38<br>99 39<br>100 40<br>101 41<br>102 42<br>103 43<br>104 44<br>105 45<br>106 46<br>107 47<br>108 48<br>109 49<br>110 50<br>111 51<br>112 52<br>113 53<br>114 54<br>115 55<br>116 56<br>117 57<br>118 58<br>119 59<br>120 60 |

### `/main/other/d1b2`

| Field | Value |
|---|---|
| Label | Info Display Error Status |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1b3`

| Field | Value |
|---|---|
| Label | Exposure Indicate Lightup |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1b4`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1b4 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `17` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3<br>4 4<br>5 5<br>6 6<br>7 7<br>8 8<br>9 9<br>10 10<br>11 11<br>12 12<br>13 13<br>14 14<br>15 15<br>16 16<br>17 17<br>18 18<br>19 19<br>20 20<br>21 21<br>22 22<br>23 23<br>24 24<br>25 25<br>26 26<br>27 27<br>28 28<br>29 29<br>30 30<br>31 31<br>32 32<br>33 33<br>34 34<br>35 35<br>36 36<br>37 37<br>38 38<br>39 39<br>40 40<br>41 41<br>42 42<br>43 43<br>44 44<br>45 45<br>46 46<br>47 47<br>48 48<br>49 49<br>50 50<br>51 51<br>52 52<br>53 53<br>54 54<br>55 55<br>56 56<br>57 57<br>58 58<br>59 59<br>60 60<br>61 61<br>62 62<br>63 63<br>64 64<br>65 65<br>66 66<br>67 67<br>68 68<br>69 69<br>70 70<br>71 71<br>72 72<br>73 73<br>74 74<br>75 75<br>76 76<br>77 77<br>78 78<br>79 79<br>80 80<br>81 81<br>82 82<br>83 83<br>84 84<br>85 85<br>86 86<br>87 87<br>88 88<br>89 89<br>90 90<br>91 91<br>92 92<br>93 93<br>94 94<br>95 95<br>96 96<br>97 97<br>98 98<br>99 99<br>100 100 |

### `/main/other/d1c0`

| Field | Value |
|---|---|
| Label | Flash Open |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1c1`

| Field | Value |
|---|---|
| Label | Flash Charged |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1f0`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1f0 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 0<br>1 1 |

### `/main/other/d1f1`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1f1 |
| Access | Read-only (`Readonly: 1`) |
| Type | RANGE |
| Current | `1112` |
| Range | `0 / 65535 / 1` |

### `/main/other/d1f2`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1f2 |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1<br>2 2<br>3 3 |

### `/main/other/d1f4`

| Field | Value |
|---|---|
| Label | PTP Property 0xd1f4 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 -2<br>1 -1<br>2 0<br>3 1<br>4 2 |

### `/main/other/d200`

| Field | Value |
|---|---|
| Label | Active Pic Ctrl Item |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `3` |
| Choices | 0 1<br>1 2<br>2 3<br>3 4<br>4 5<br>5 6<br>6 7<br>7 201<br>8 202<br>9 203<br>10 204<br>11 205<br>12 206<br>13 207<br>14 208<br>15 209 |

### `/main/other/d201`

| Field | Value |
|---|---|
| Label | Change Pic Ctrl Item |
| Access | Read-only (`Readonly: 1`) |
| Type | MENU |
| Current | `0` |

### `/main/other/d20d`

| Field | Value |
|---|---|
| Label | PTP Property 0xd20d |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `1` |
| Choices | 0 0<br>1 1 |

### `/main/other/d239`

| Field | Value |
|---|---|
| Label | PTP Property 0xd239 |
| Access | Writable (`Readonly: 0`) |
| Type | MENU |
| Current | `0` |
| Choices | 0 -6<br>1 -5<br>2 -4<br>3 -3<br>4 -2<br>5 -1<br>6 0<br>7 1<br>8 2<br>9 3<br>10 4<br>11 5<br>12 6 |

## Implementation rules

1. Treat the path and raw value as the source record; labels are presentation metadata.
2. Never write a property solely because gPhoto marks it writable; verify descriptor type, range, and camera response first.
3. Keep read-only status properties out of save/apply payloads.
4. For every setting selected for the application layer, record PTP property code, data type, encoding, allowed values, and observed response.
5. The next comparison pass should mark each Nikon manual item as `PTP confirmed`, `PTP partial`, `PTP not found`, or `UI/action only`.

## References

- Nikon D810 User's Manual: https://download.nikonimglib.com/archive2/Uslma00vmWju01F4NIw08vXsPQ61/D810FM_DL%28En%2901.pdf
- Raw capture: `d810-gphoto-list-all-config-2026-07-26.txt`

