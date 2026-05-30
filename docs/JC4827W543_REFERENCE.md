# Reference materielle - JC4827W543 (ESP32-S3 4.3")

## Objectif
Document de reference rapide pour configurer correctement la carte `JC4827W543` dans les firmwares n3 (affichage, tactile, memoire, flash).

## Resume materiel (sources croisees)
- MCU: `ESP32-S3-WROOM-1-N4R8`
- Ecran: `4.3"` IPS, resolution `480x272`
- Driver ecran: `NV3041A` (bus QSPI)
- Tactile capacitif: `GT911` (I2C)
- Memoire typique: `4MB Flash` + `8MB PSRAM`

## Pinout pratique (utilise dans les exemples fonctionnels)
### Ecran NV3041A (Arduino_GFX / QSPI)
- BL: `GPIO1`
- CS: `GPIO45`
- SCK: `GPIO47`
- D0: `GPIO21`
- D1: `GPIO48`
- D2: `GPIO40`
- D3: `GPIO39`

Exemple declaration:
```cpp
Arduino_DataBus *bus = new Arduino_ESP32QSPI(45, 47, 21, 48, 40, 39);
Arduino_NV3041A *panel = new Arduino_NV3041A(bus, GFX_NOT_DEFINED, 0, true);
Arduino_GFX *gfx = new Arduino_Canvas(480, 272, panel);
```

### Tactile GT911 (TouchLib)
- SCL: `GPIO4`
- SDA: `GPIO8`
- RST: `GPIO38`
- INT: `GPIO3`

Macros usuelles:
```cpp
#define TOUCH_MODULES_GT911
#define TOUCH_MODULE_ADDR GT911_SLAVE_ADDRESS1
#define TOUCH_SCL 4
#define TOUCH_SDA 8
#define TOUCH_RES 38
#define TOUCH_INT 3
```

## Parametres PlatformIO recommandes (stables en pratique)
Pour ce modele, utiliser:
- `board = esp32-s3-devkitc-1`
- `board_upload.flash_size = 4MB`
- `board_build.partitions = huge_app.csv`
- `board_build.arduino.memory_type = qio_opi`

Ces options evitent notamment:
- bootloop `partition table exceeds flash chip size`
- erreurs PSRAM (`PSRAM not initialized` / mauvais mode PSRAM)

## Notes d integration LVGL
- Version LVGL recommandee: `8.4.x`
- En config LVGL, verifier:
  - `LV_COLOR_DEPTH 16`
  - `LV_COLOR_16_SWAP` selon chemin de rendu (souvent `0` en rendu direct NV3041A)
- Pour `Arduino_Canvas`, un `gfx->flush()` est souvent necessaire apres `lv_timer_handler()`.

## Variantes a surveiller
Certaines cartes proches (ex: suffixes differents type `...543C`) peuvent differer legerement:
- driver tactile (GT911 vs autre)
- routage IO expose
- options par defaut de flash/psram dans les toolchains

Toujours confirmer avec un boot serie apres flash.

## Sources
- Depot de reference board + exemples:
  - https://github.com/profi-max/JC4827W543_4.3inch_ESP32S3_board
- Notes community / retour d experience Arduino_GFX:
  - https://github.com/moononournation/Arduino_GFX/discussions/557
- Resume hardware:
  - https://www.cncwiki.org/index.php?title=JCZN_JC4827W543_ESP32_4.3%22_Touch_Screen_Display_Module
- Infos Micropython board profile:
  - https://github.com/straga/micropython_lcd/blob/master/device/JC4827W543/README.md

