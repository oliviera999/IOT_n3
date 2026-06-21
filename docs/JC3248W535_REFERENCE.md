# Reference materielle - JC3248W535 (ESP32-S3 3.5")

## Objectif
Document de reference rapide pour configurer correctement la carte `JC3248W535` dans les firmwares n3 (affichage, tactile, memoire, flash).

## Resume materiel (sources croisees)
- MCU: `ESP32-S3-WROOM-1` (souvent 16 Mo flash + 8 Mo PSRAM OPI)
- Ecran: `3.5"` IPS, resolution `320x480` (portrait)
- Driver ecran: `AXS15231B` (bus QSPI, tactile integre meme puce)
- Tactile capacitif: integre AXS15231B (I2C `0x3B`, **pas** GT911)
- Memoire typique: `16MB Flash` + `8MB PSRAM`

## Pinout pratique (utilise dans poissonglouton `pgl-s3-jc3248`)
### Ecran AXS15231B (Arduino_GFX / QSPI)
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
Arduino_GFX *panel = new Arduino_AXS15231B(
    bus, GFX_NOT_DEFINED, 0, false, 320, 480, 0, 0, 0, 0,
    axs15231b_320480_type2_init_operations,
    sizeof(axs15231b_320480_type2_init_operations));
Arduino_GFX *gfx = new Arduino_Canvas(320, 480, panel, 0, 0, 0);
```

### Tactile AXS15231B (I2C direct)
- SDA: `GPIO4`
- SCL: `GPIO8`
- INT: `GPIO3`
- Adresse I2C: `0x3B`
- Commande lecture: `{0xB5, 0xAB, 0xA5, 0x5A}`

**Ne pas utiliser** TouchLib / GT911 sur ce module.

### Capteur IR externe (poissonglouton)
- **GPIO7** recommande (libre du bus tactile I2C GPIO4/8)
- Eviter GPIO4 (SDA tactile)

## Parametres PlatformIO recommandes
- `board = esp32-s3-devkitc-1`
- `board_upload.flash_size = 16MB`
- `board_build.partitions = default_16MB.csv`
- `board_build.arduino.memory_type = qio_opi`
- `build_flags`: `-DPGL_BOARD_JC3248W535=1`, `-DBOARD_HAS_PSRAM`, `-mfix-esp32-psram-cache-issue`
- Init AXS15231B: `-DPGL_AX15231B_INIT_TYPE2=1` (Guition) ; basculer vers `TYPE1` si ecran noir au flash

## Notes d integration LVGL
- Version LVGL: `8.4.x`
- `LV_COLOR_DEPTH 16`, `LV_COLOR_16_SWAP 1`
- Flush: souvent `draw16bitBeRGBBitmap` (macro `PGL_LV_FLUSH_USE_BERGB` dans `pgl_display_board.h`)
- `gfx->flush()` apres `lv_timer_handler()` avec `Arduino_Canvas`

## Depannage flash
| Symptome | Action |
|----------|--------|
| Ecran noir | Basculer `PGL_AX15231B_INIT_TYPE2` → `TYPE1` dans `platformio.ini` |
| Couleurs inversees | Inverser `PGL_LV_FLUSH_USE_BERGB` dans `pgl_display_board.h` |
| Tactile decale | Ajuster mapping dans `touch_axs15231b.h` |

## Sources
- https://github.com/me-processware/JC3248W535-Driver
- https://f1atb.fr/en/esp32-s3-3-5-inch-capacitive-touch-ips-display-setup/
- https://github.com/moononournation/Arduino_GFX (driver `Arduino_AXS15231B`)
- Reference JC4827 (meme famille Guition): `docs/JC4827W543_REFERENCE.md`
