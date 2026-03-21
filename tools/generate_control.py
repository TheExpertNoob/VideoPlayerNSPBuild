#!/usr/bin/env python3
# generate_control.py
# Usage: python3 generate_control.py <icon.jpg> <output_dir> --titleid <id> --title <title> --author <author> --displayver <ver>

import struct
import sys
import os
import shutil
import argparse

LANGUAGES = [
    "AmericanEnglish",
    "BritishEnglish",
    "Japanese",
    "French",
    "German",
    "LatinAmericanSpanish",
    "Spanish",
    "Italian",
    "Dutch",
    "CanadianFrench",
    "Portuguese",
    "Russian",
    "Korean",
    "TraditionalChinese",
    "SimplifiedChinese",
    "BrazilianPortuguese",
]

def generate_nacp(output_path, title_id, title, author, display_ver):
    nacp = bytearray(0x4000)

    def write_str(offset, s, max_len):
        b = s.encode('utf-8')[:max_len]
        nacp[offset:offset+len(b)] = b

    def write_u64(offset, val):
        struct.pack_into('<Q', nacp, offset, val)

    def write_u32(offset, val):
        struct.pack_into('<I', nacp, offset, val)

    def write_u8(offset, val):
        nacp[offset] = val

    # Title entries (0x300 * 16 = 0x3000)
    for i in range(16):
        base = i * 0x300
        write_str(base,         title,  0x200)
        write_str(base + 0x200, author, 0x100)

    # SupportedLanguageFlag @ 0x302C — bits 0-15, all 16 language entries
    write_u32(0x302C, 0x0000FFFF)

    # StartupUserAccount @ 0x3025 = 0 (None)
    write_u8(0x3025, 0)

    # Screenshot @ 0x3034 = 0 (Allow)
    write_u8(0x3034, 0)

    # VideoCapture @ 0x3035 = 1 (Manual)
    write_u8(0x3035, 1)

    # PresenceGroupId @ 0x3038
    write_u64(0x3038, title_id)

    # DisplayVersion @ 0x3060
    write_str(0x3060, display_ver, 0x10)

    # AddOnContentBaseId @ 0x3070
    write_u64(0x3070, 0)

    # SaveDataOwnerId @ 0x3078
    write_u64(0x3078, 0)

    # UserAccountSaveDataSize @ 0x3080
    write_u64(0x3080, 0)

    # UserAccountSaveDataJournalSize @ 0x3088
    write_u64(0x3088, 0)

    # UserAccountSaveDataSizeMax @ 0x3148
    write_u64(0x3148, 0)

    # UserAccountSaveDataJournalSizeMax @ 0x3150
    write_u64(0x3150, 0)

    # LogoType @ 0x30F0 = 0 (LicensedByNintendo)
    write_u8(0x30F0, 0)

    # LogoHandling @ 0x30F1 = 0 (Auto)
    write_u8(0x30F1, 0)

    # CrashReport @ 0x30F6 = 1 (Allow)
    write_u8(0x30F6, 1)

    # JitConfiguration @ 0x33B0
    write_u64(0x33B0, 0x0000000000000000)
    write_u64(0x33B8, 0x0000000004000000)

    with open(output_path, 'wb') as f:
        f.write(nacp)
    print(f"NACP written to {output_path}")

def generate_control_romfs(icon_path, output_dir, title_id, title, author, display_ver):
    os.makedirs(output_dir, exist_ok=True)
    generate_nacp(os.path.join(output_dir, "control.nacp"), title_id, title, author, display_ver)
    for lang in LANGUAGES:
        dst = os.path.join(output_dir, f"icon_{lang}.dat")
        shutil.copy(icon_path, dst)
        print(f"Written {dst}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('icon',       help='Path to icon.jpg')
    parser.add_argument('output_dir', help='Output directory')
    parser.add_argument('--titleid',    required=True, help='Title ID hex e.g. 0400000000420000')
    parser.add_argument('--title',      required=True, help='Application title')
    parser.add_argument('--author',     required=True, help='Author name')
    parser.add_argument('--displayver', default='1.0.0', help='Display version string')
    args = parser.parse_args()

    # Accept with or without 0x prefix
    title_id_int = int(args.titleid.replace('0x', '').replace('0X', ''), 16)

    generate_control_romfs(args.icon, args.output_dir, title_id_int, args.title, args.author, args.displayver)
