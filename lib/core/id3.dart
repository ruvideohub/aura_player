import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class Id3Tags {
  String? title;
  String? artist;
  String? album;
  String? year;
  Uint8List? picture;
}

/// Минимальный самостоятельный парсер ID3v2.2 / 2.3 / 2.4.
/// Читает текстовые теги и встроенную обложку (APIC / PIC) из начала файла.
/// Никаких внешних зависимостей — только dart:io и dart:convert.
Id3Tags? readId3Tags(String path) {
  RandomAccessFile? raf;
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    raf = file.openSync();

    final header = raf.readSync(10);
    if (header.length < 10) return null;
    if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) {
      return null; // нет "ID3"
    }
    final major = header[3];
    if (major < 2 || major > 4) return null;

    final tagSize = _syncsafe(header[6], header[7], header[8], header[9]);
    if (tagSize <= 0 || tagSize > 12 * 1024 * 1024) return null;
    final tag = raf.readSync(tagSize);

    final tags = Id3Tags();
    var pos = 0;
    final frameIdPattern = RegExp(r'^[A-Z0-9]{3,4}$');

    while (pos < tag.length) {
      if (major >= 3) {
        if (pos + 10 > tag.length) break;
        final id = String.fromCharCodes(tag.sublist(pos, pos + 4));
        if (!frameIdPattern.hasMatch(id)) break;

        int frameSize;
        if (major == 4) {
          frameSize =
              _syncsafe(tag[pos + 4], tag[pos + 5], tag[pos + 6], tag[pos + 7]);
        } else {
          frameSize = (tag[pos + 4] << 24) |
              (tag[pos + 5] << 16) |
              (tag[pos + 6] << 8) |
              tag[pos + 7];
        }
        if (frameSize <= 0 || pos + 10 + frameSize > tag.length) break;

        final data = tag.sublist(pos + 10, pos + 10 + frameSize);
        _applyFrame(id, data, tags);
        pos += 10 + frameSize;
      } else {
        // ID3v2.2: заголовок 6 байт, идентификатор 3 символа, размер 3 байта
        if (pos + 6 > tag.length) break;
        final id = String.fromCharCodes(tag.sublist(pos, pos + 3));
        if (!frameIdPattern.hasMatch(id)) break;
        final frameSize =
            (tag[pos + 3] << 16) | (tag[pos + 4] << 8) | tag[pos + 5];
        if (frameSize <= 0 || pos + 6 + frameSize > tag.length) break;

        final data = tag.sublist(pos + 6, pos + 6 + frameSize);
        _applyFrame(_v22ToV23(id), data, tags);
        pos += 6 + frameSize;
      }
    }
    return tags;
  } catch (_) {
    return null;
  } finally {
    try {
      raf?.closeSync();
    } catch (_) {}
  }
}

int _syncsafe(int a, int b, int c, int d) =>
    (a << 21) | (b << 14) | (c << 7) | d;

String _v22ToV23(String id) {
  const map = {
    'TT2': 'TIT2',
    'TP1': 'TPE1',
    'TAL': 'TALB',
    'TYE': 'TYER',
    'PIC': 'APIC',
  };
  return map[id] ?? '';
}

void _applyFrame(String id, Uint8List data, Id3Tags tags) {
  if (id == 'TIT2') {
    tags.title = _decodeText(data);
  } else if (id == 'TPE1') {
    tags.artist = _decodeText(data);
  } else if (id == 'TALB') {
    tags.album = _decodeText(data);
  } else if (id == 'TYER' || id == 'TDRC') {
    tags.year = _decodeText(data);
  } else if (id == 'APIC') {
    final pic = _extractPicture(data);
    if (pic != null && pic.isNotEmpty && tags.picture == null) {
      tags.picture = pic;
    }
  }
}

String? _decodeText(Uint8List data) {
  if (data.isEmpty) return null;
  final enc = data[0];
  final body = data.sublist(1);
  try {
    String s;
    switch (enc) {
      case 0:
        s = latin1.decode(body);
        break;
      case 1:
        s = _decodeUtf16(body);
        break;
      case 2:
        s = _decodeUtf16be(body);
        break;
      case 3:
      default:
        s = utf8.decode(body, allowMalformed: true);
        break;
    }
    return s.replaceAll('\u0000', '').trim();
  } catch (_) {
    return null;
  }
}

String _decodeUtf16(Uint8List b) {
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    return _decodeUtf16le(b.sublist(2));
  }
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    return _decodeUtf16be(b.sublist(2));
  }
  return _decodeUtf16le(b);
}

String _decodeUtf16le(Uint8List b) {
  final chars = <int>[];
  for (var i = 0; i + 1 < b.length; i += 2) {
    chars.add((b[i + 1] << 8) | b[i]);
  }
  return String.fromCharCodes(chars);
}

String _decodeUtf16be(Uint8List b) {
  final chars = <int>[];
  for (var i = 0; i + 1 < b.length; i += 2) {
    chars.add((b[i] << 8) | b[i + 1]);
  }
  return String.fromCharCodes(chars);
}

Uint8List? _extractPicture(Uint8List data) {
  try {
    if (data.isEmpty) return null;
    final enc = data[0];
    final isUtf16 = enc == 1 || enc == 2;

    // MIME-строка, завершённая нулевым байтом
    var i = 1;
    while (i < data.length && data[i] != 0) {
      i++;
    }
    final mime =
        latin1.decode(data.sublist(1, i < data.length ? i : data.length));
    i++; // пропустить нулевой байт
    if (mime.toLowerCase() == '-->') return null; // ссылка, а не картинка

    // Описание, завершённое терминатором в своей кодировке
    if (isUtf16) {
      while (i + 1 < data.length && !(data[i] == 0 && data[i + 1] == 0)) {
        i += 2;
      }
      i += 2;
    } else {
      while (i < data.length && data[i] != 0) {
        i++;
      }
      i += 1;
    }

    if (i >= data.length) return null;
    final pic = data.sublist(i);
    return pic.isEmpty ? null : pic;
  } catch (_) {
    return null;
  }
}
