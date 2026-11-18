#!/usr/bin/env python3
"""Распаковка скина LKMP (res/r7.dat → zlib-контейнер с XML и шрифтами).

Формат (B1.P.i()):
  байты 0..2  — BE-24 размер распакованных данных
  байты 3..5  — BE-24 размер сжатого блока
  далее zlib (java Inflater = deflate)
Контейнер:
  байт 0..2   — (пропускается, f1502d = start+5)
  байты 3..4  — BE-16 число файлов
  байты 5..7  — BE-24 смещение секции данных (Q3)
  файлы: 1 байт длина имени, имя, BE-24 длина данных
"""
import struct
import sys
import zlib

SRC = '/tmp/work/apkres/res/r7.dat'


def be(data, off, n):
    v = 0
    for i in range(n):
        v = (v << 8) | (data[off + i] & 0xFF)
    return v


def unpack():
    raw = open(SRC, 'rb').read()
    decompressed_size = be(raw, 0, 3)
    compressed_size = be(raw, 3, 3)
    blob = zlib.decompress(raw[6:6 + compressed_size])
    assert len(blob) == decompressed_size, (len(blob), decompressed_size)
    print(f'распаковано: {len(blob)} байт (ожидалось {decompressed_size})')

    count = be(blob, 3, 2)
    data_off = be(blob, 5, 3)
    print(f'файлов в скине: {count}, данные с offset={data_off}')

    pos = 8
    entries = []
    for _ in range(count):
        name_len = blob[pos]; pos += 1
        name = blob[pos:pos + name_len].decode('utf-8'); pos += name_len
        size = be(blob, pos, 3); pos += 3
        entries.append((name, data_off, size))
        data_off += size
    return blob, entries


if __name__ == '__main__':
    blob, entries = unpack()
    for name, off, size in entries:
        print(f'  {name}  off={off} size={size}')
