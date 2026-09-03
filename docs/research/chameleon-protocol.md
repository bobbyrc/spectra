# Chameleon Ultra protocol (firmware main, v2.2.0, researched 2026-09-02)

Sources: wiki/protocol, firmware/application/src/data_cmd.h, app_status.h, utils/netdata.h, dataframe.c, app_cmd.c, rfid/nfctag/tag_base_type.h, settings.h, ble_main.c, usb_main.c, software/script/chameleon_*.py.

## Frame (same for cmd and response, all u16 big-endian)
| Off | Size | Field |
|---|---|---|
| 0 | 1 | SOF 0x11 |
| 1 | 1 | LRC1 over byte 0 (always 0xEF) |
| 2 | 2 | CMD |
| 4 | 2 | STATUS (0 in requests) |
| 6 | 2 | LEN |
| 8 | 1 | LRC2 over bytes 2..7 |
| 9 | LEN | DATA |
| 9+LEN | 1 | LRC3 over DATA |
- LRC = (0x100 - sum(bytes) & 0xFF) & 0xFF. Max DATA 4096 (fw >= 2.1; wiki says 512). Byte-stream parser, resyncs on SOF, fragmentation across USB/BLE packets is normal: reassemble.
- No sequence number; responses matched by CMD. One command in flight at a time. Default timeout 3s, longer for attacks (hardnested 30s).
- ENTER_BOOTLOADER example: 11 EF 03 F2 00 00 00 00 0B 00 (no response).

## Status codes
0x00 HF_TAG_OK, 0x01 HF_TAG_NO, 0x02 HF_ERR_STAT, 0x03 HF_ERR_CRC, 0x04 HF_COLLISION, 0x05 HF_ERR_BCC, 0x06 MF_ERR_AUTH, 0x07 HF_ERR_PARITY, 0x08 HF_ERR_ATS, 0x40 LF_TAG_OK, 0x41 LF_TAG_NO_FOUND, 0x42 LF_TAG_LOGIN_REQUIRED, 0x60 PAR_ERR, 0x66 DEVICE_MODE_ERROR, 0x67 INVALID_CMD, 0x68 SUCCESS, 0x69 NOT_IMPLEMENTED, 0x70 FLASH_WRITE_FAIL, 0x71 FLASH_READ_FAIL, 0x72 INVALID_SLOT_TYPE, 0x73 MEM_ERR, 0x74 CREATE_RESPONSE_ERR, 0x75 CMD_ERR.
Success = 0x68 for 1xxx/4xxx/5xxx, 0x00 for 2xxx, 0x40 for 3xxx.

## Commands
### Device/slots/settings 1000-1040 (any mode)
1000 GET_APP_VERSION -> major(1) minor(1); 1001 CHANGE_DEVICE_MODE mode(1) 0=emu 1=reader (Lite: NOT_IMPLEMENTED); 1002 GET_DEVICE_MODE; 1003 SET_ACTIVE_SLOT slot(1); 1004 SET_SLOT_TAG_TYPE slot(1) type(2); 1005 SET_SLOT_DATA_DEFAULT slot type(2); 1006 SET_SLOT_ENABLE slot sense enable; 1007 SET_SLOT_TAG_NICK slot sense utf8<=32; 1008 GET_SLOT_TAG_NICK slot sense; 1009 SLOT_DATA_CONFIG_SAVE; 1010 ENTER_BOOTLOADER (no resp); 1011 GET_DEVICE_CHIP_ID -> 8B; 1012 GET_DEVICE_ADDRESS -> 6B; 1013 SAVE_SETTINGS; 1014 RESET_SETTINGS; 1015/1016 SET/GET_ANIMATION_MODE (0 full,1 minimal,2 none,3 symmetric); 1017 GET_GIT_VERSION -> utf8; 1018 GET_ACTIVE_SLOT; 1019 GET_SLOT_INFO -> 8x(hf(2) lf(2)); 1020 WIPE_FDS; 1021 DELETE_SLOT_TAG_NICK; 1023 GET_ENABLED_SLOTS -> 8x(hf(1) lf(1)); 1024 DELETE_SLOT_SENSE_TYPE; 1025 GET_BATTERY_INFO -> mV(2) pct(1) (wait ~5s after wake); 1026-1029 GET/SET (LONG) BUTTON_PRESS_CONFIG button('A'|'B') fn(1); 1030/1031 SET/GET_BLE_PAIRING_KEY 6 ascii digits; 1032 DELETE_ALL_BLE_BONDS; 1033 GET_DEVICE_MODEL 0=Ultra 1=Lite; 1034 GET_DEVICE_SETTINGS -> ver anim btnA btnB longA longB pairing_en key(6) [+sleep_timeout in v6; verify length]; 1035 GET_DEVICE_CAPABILITIES -> list u16; 1036/1037 GET/SET_BLE_PAIRING_ENABLE; 1038 GET_ALL_SLOT_NICKS -> 8x(hf_len hf lf_len lf); 1039/1040 GET/SET_SLEEP_TIMEOUT sec 5..60.
Button fn: 0 none,1 next slot,2 prev slot,3 clone UID,4 battery,5 NFC field gen. Sense: 0 none,1 LF,2 HF.

### HF reader 2000-2201 (Ultra only, reader mode)
2000 HF14A_SCAN -> per tag uidlen uid atqa(2) sak atslen ats; 2001 MF1_DETECT_SUPPORT; 2002 MF1_DETECT_PRNG (0 static,1 weak,2 hard); 2003 MF1_STATIC_NESTED_ACQUIRE; 2004 MF1_DARKSIDE_ACQUIRE; 2005 MF1_DETECT_NT_DIST; 2006 MF1_NESTED_ACQUIRE; 2007 MF1_AUTH_ONE_KEY_BLOCK type blk key(6); 2008 MF1_READ_ONE_BLOCK -> 16B; 2009 MF1_WRITE_ONE_BLOCK type blk key data(16); 2010 HF14A_RAW options(1) timeout(2) bitlen(2) data; 2011 MF1_MANIPULATE_VALUE_BLOCK; 2012 MF1_CHECK_KEYS_OF_SECTORS mask(10) keys[N<=83] -> found(10) keys[40][2]; 2013 MF1_HARDNESTED_ACQUIRE; 2014 MF1_ENC_NESTED_ACQUIRE; 2015 MF1_CHECK_KEYS_ON_BLOCK; 2016 HF14A_SCAN_KEEP; 2017 HF14A_AUTH_TRACE; 2020 HF14A_SNIFF; 2100/2101 FIELD_ON/OFF; 2200/2201 HF14A_GET/SET_CONFIG (bcc cl2 cl3 rats). Key type 0x60=A 0x61=B.

### LF reader 3000-3032 (Ultra only, reader mode)
3000 EM410X_SCAN -> 5B; 3001 EM410X_WRITE_TO_T55XX id(5) newkey(4) oldkeys(4xN); 3002 HIDPROX_SCAN -> 13B; 3003 HIDPROX_WRITE_TO_T55XX; 3004/3005 VIKING scan(4B)/write; 3006 EM410X_ELECTRA_WRITE; 3009 ADC_GENERIC_READ; 3010/3011 IOPROX scan/write; 3012 IOPROX_DECODE_RAW; 3013 IOPROX_COMPOSE_ID; 3014/3015 PAC (8B); 3016 LF_T55XX_WRITE; 3018 IDTECK_WRITE; 3019/3020 JABLOTRON (5B); 3030 EM4X05_SCAN pwd(4); 3031 LF_SNIFF timeout(2).

### HF emulator 4000-4044 (all models, active slot)
4000 MF1_WRITE_EMU_BLOCK_DATA start Nx16; 4001 HF14A_SET_ANTI_COLL_DATA uidlen uid atqa sak atslen ats; 4004/4007 MF1 SET/GET_DETECTION_ENABLE; 4005 GET_DETECTION_COUNT u32; 4006 GET_DETECTION_LOG idx(u32) -> Nx18B; 4008 MF1_READ_EMU_BLOCK_DATA start count<=32; 4009 MF1_GET_EMULATOR_CONFIG -> detection gen1a gen2 block_anticoll write_mode; 4010-4017 GET/SET GEN1A, GEN2, BLOCK_ANTI_COLL, WRITE_MODE (0 normal,1 denied,2 deceive,3 shadow,4 shadow-req); 4018 HF14A_GET_ANTI_COLL_DATA; 4019/4020 MF0_NTAG UID_MAGIC_MODE; 4021/4022 MF0_NTAG READ/WRITE_EMU_PAGE_DATA page count; 4023/4024 VERSION_DATA 8B; 4025/4026 SIGNATURE 32B; 4027/4028 COUNTER; 4029 RESET_AUTH_CNT; 4030 GET_PAGE_COUNT; 4031/4032 MF0 WRITE_MODE; 4033-4037 MF0 detection/config; 4038/4039 MF1 FIELD_OFF_DO_RESET; 4040/4041 MF1 PRNG_TYPE; 4042-4044 SEOS read/write emu data/keys (2.2.0, undocumented).

### LF emulator 5000-5013 (all models)
5000/5001 EM410X SET/GET_EMU_ID 5B; 5002/5003 HIDPROX 13B; 5004/5005 VIKING 4B; 5006/5007 PAC 8B; 5008/5009 IOPROX; 5010/5011 JABLOTRON 5B; 5012/5013 IDTECK 8B.

### ISO14443-4 6000-6005 (Ultra only)
6000 APDU_RECV; 6001 APDU_SEND; 6002 SET_ANTI_COLL; 6003 STATIC_RESP; 6004 READER_APDU; 6005 EMV_SCAN.

## Transport
- USB CDC-ACM: VID 0x6868 PID 0x8686, manufacturer "Proxgrind", product "<ChameleonUltra|ChameleonLite>: hw_vN, fw_vN". Baud nominal 115200. Assert DTR after open. No flow control.
- BLE: NUS service 6E400001-B5A3-F393-E0A9-E50E24DCCA9E; write 6E400002; notify 6E400003. Names ChameleonUltra/ChameleonLite (+ Battery Service 0x180F). Firmware requests MTU 247; notifications chunked to mtu-3, reassemble. Conn interval 20-75ms.
- BLE pairing: LESC+MITM, DISPLAY_ONLY, static 6-digit passkey default 123456 (cmd 1030). When pairing enabled (1036/1037): chars require MITM security and a bonded-peer whitelist applies to advertising; clear bonds via 1032. Change needs SAVE_SETTINGS + reboot.
- Sleep timeout default 8s when not connected/on USB.

## DFU
- Nordic Secure DFU (nRF5 SDK, S140 7.2.0, sd-req 0x0100), protocol v1. USB bootloader VID 0x1915 PID 0x521F; BLE adv name CU / CL, no bonds required. Inactivity timeout 30s.
- Enter: cmd 1010 (no response) or hold B while plugging USB. LEDs 4/5 green waiting, blue flashing, red fail.
- Packages: nrfutil zip (manifest.json + .bin + .dat). Assets: ultra-dfu-app.zip, lite-dfu-app.zip, *-dfu-full.zip. Signed ECDSA P-256 with publicly committed key resource/dfu_key/chameleon.pem. hw-version 0 Ultra / 1 Lite, bootloader rejects other model. No practical downgrade prevention. FDS user data survives app DFU.

## Ultra vs Lite
Lite has no reader chip: no reader mode, no 2xxx/3xxx/6xxx (INVALID_CMD, absent from capabilities). Detect via 1033, gate UI by 1035.

## Slots
8 slots idx 0..7 (UI 1..8). Each: enabled_hf, enabled_lf, tag_hf(u16), tag_lf(u16), nick per sense type (<=32 UTF-8). Persist with 1009.
Tag types: 0 UNDEFINED; LF: 100 EM410X, 104 EM410X_ELECTRA, 150 PAC, 170 VIKING, 180 JABLOTRON, 200 HID_PROX, 201 IOPROX, 310 IDTECK; HF: 1000 MF_Mini, 1001 MF_1K, 1002 MF_2K, 1003 MF_4K, 1100 NTAG_213, 1101 NTAG_215, 1102 NTAG_216, 1103 MF0ICU1, 1104 MF0ICU2, 1105 MF0UL11, 1106 MF0UL21, 1107 NTAG_210, 1108 NTAG_212, 3000 HF14A_4, 3001 SEOS.

## Connect handshake
1. Open transport (USB: DTR; BLE: subscribe notify, MTU, pair if required).
2. 1035 capabilities (fail => pre-2.0, refuse). 3. 1000 version; same MAJOR ok, higher MAJOR refuse; legacy 00 01 => must update. 4. 1033 model, 1017 git version, 1011/1012 identity. 5. 1002 mode; switch to reader only around reader ops, return to emu after. 6. 1018, 1019, 1023, 1038 (or 1008 per slot), 1034, 1025. 7. After slot edits 1009; after settings 1013.

Uncertain: wiki lags firmware for several payload formats (2013-2017, 2020, 3004+, 4031+, 5004+, 6xxx, SEOS, settings length). Validate on hardware.
