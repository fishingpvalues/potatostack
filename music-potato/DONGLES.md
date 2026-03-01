# USB Radio Hardware — Buying Guide

For **music-potato** (Le Potato AML-S905X-CC, Armbian Trixie, aarch64).

**Rule:** only buy chipsets with **in-kernel drivers** — plug in, run `setup-radios.sh`, done.
No compiling. No DKMS. No pain after kernel updates.

---

## Recommended Shopping List

Buy **one WiFi dongle** + **one Bluetooth dongle** (or one combo if available).

| Priority | Type | Chipset | Driver | Product | ~Price |
|---|---|---|---|---|---|
| ★★★ Best | WiFi | MediaTek MT7921au | `mt7921u` | ALFA AWUS036AXML | €35 |
| ★★★ Best | BT | Realtek RTL8761B | `btrtl` | TP-Link UB500 | €10 |
| ★★ Good | WiFi | MediaTek MT7612u | `mt76x2u` | ALFA AWUS036ACM | €30 |
| ★★ Good | WiFi | Ralink RT5370 | `rt2800usb` | many no-name dongles | €5 |
| ★ Budget | WiFi | MediaTek MT7601u | `mt7601u` | any "N150 USB" cheap dongle | €4 |
| ★ Budget | BT | CSR8510 clone | `btusb` | any "BT 4.0 USB nano" | €4 |

> **Warning on CSR clones:** The €3-4 Bluetooth nano dongles labelled "CSR" are
> mostly counterfeits with buggy firmware. They often work, but can disconnect randomly.
> The TP-Link UB500 (RTL8761B) is €10 and rock-solid.

> **Warning on Realtek WiFi:** RTL8811AU/RTL8812AU need Linux **6.14+** (rtw88 in-kernel).
> On older kernels these required DKMS. If you have kernel < 6.14, use MediaTek.

---

## Verified Best Combo (recommended buy)

```
WiFi: ALFA AWUS036AXML  (MT7921au)  — WiFi 6, dual-band, USB-C, great range
BT  : TP-Link UB500     (RTL8761B)  — BT 5.0, plug and forget
```

Both plug into Le Potato's USB-A ports. Total cost: ~€45.

---

## Full Chipset Table

### WiFi — All Supported Driverless Chipsets

| Chipset | Driver | Kernel | Band | Speed | Notes |
|---|---|---|---|---|---|
| MT7921au | `mt7921u` | 5.18+ | 2.4+5 GHz | WiFi 6 (574Mbps) | Best choice for audio streaming |
| MT7925 | `mt7925u` | 6.7+ | 2.4+5+6 GHz | WiFi 7 (up to 2.4Gbps) | Overkill but future-proof |
| MT7612u | `mt76x2u` | 4.19+ | 2.4+5 GHz | AC1200 | Mature, reliable |
| MT7610u | `mt76x0u` | 4.19+ | 2.4+5 GHz | AC600 | Good budget 5GHz |
| MT7601u | `mt7601u` | 4.2+ | 2.4 GHz only | N150 | Cheapest, only 2.4GHz |
| RT5370 | `rt2800usb` | 3.x+ | 2.4 GHz only | N150 | No firmware needed at all |
| RT5372 | `rt2800usb` | 3.x+ | 2.4 GHz only | N300 | No firmware needed |
| AR9271 | `ath9k_htc` | 2.6+ | 2.4 GHz only | N150 | TP-Link TL-WN722N **v1 only** |
| RTL8812AU | `rtw8812au` | 6.14+ | 2.4+5 GHz | AC1200 | Good if kernel 6.14+ |

**For audio streaming, any of these is more than fast enough.** Lossless FLAC over NFS
needs ~5 Mbps. Even the cheapest N150 MT7601u handles it easily.

### Bluetooth — All Supported Driverless Chipsets

| Chipset | Driver | BT Version | Notes |
|---|---|---|---|
| RTL8761B | `btrtl` + `btusb` | 5.0 | TP-Link UB500 — **recommended** |
| MT7921 BT | `btmtk` + `btusb` | 5.2 | Part of ALFA AWUS036AXML combo chip |
| QCA3010 | `ath3k` + `btusb` | 4.0 | Qualcomm, needs firmware-atheros |
| QCA9377 | `btusb` | 4.2 | Qualcomm, needs firmware-atheros |
| CSR8510 | `btusb` | 4.0 | Cheap but unreliable clones — avoid |
| Intel AX201 BT | `btusb` | 5.2 | Rare as USB — usually M.2 only |

---

## How to check your dongle chipset before buying

Search the seller's product page for `VID:PID` or `USB ID`. Or once plugged in:

```bash
lsusb
# Look for entries like:
# Bus 001 Device 003: ID 0e8d:7961 MediaTek Inc. MT7921 802.11ax [...]
#                        ─────────
#                        VID:PID — look this up in setup-radios.sh database

# Check which driver loaded:
dmesg | tail -20 | grep -i "usb\|wifi\|bt\|firmware"
```

---

## What to avoid

| Chipset | Why |
|---|---|
| RTL8188EUS / RTL8188EU | Needs DKMS on kernels < 6.x — check version |
| RTL8811CU / RTL8821CU | DKMS — avoid |
| RTL8814AU | DKMS — avoid |
| TP-Link TL-WN722N **v2/v3** | v1=AR9271 (OK), v2/v3=RTL8188EUS (DKMS) — v1 only |
| Broadcom BCM43xx USB | Firmware licensing hell on aarch64 |
| Intel WiFi USB adapters | Very rare and poorly supported as USB |

---

## Checking kernel version

```bash
uname -r
# Example: 6.12.73+deb13-amd64
# MT7921u needs 5.18+ → fine
# RTL8812AU needs 6.14+ → needs update
```

Le Potato with Armbian Trixie ships with Linux 6.x. Most MediaTek/Ralink chipsets work fine.
