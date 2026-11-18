#!/usr/bin/env python3
"""Декодер бинарного XML скина LKMP (порт H1.f + H1.e + H1.a).

Формат узла (H1.e.a):
  tag   = varint (индекс в names); tag 0/1 => терминальный узел с текстом
  flags = 1 байт: старшие 2 бита — режим дочерних (0/0x40/0x80/0xC0),
          младшие 6 бит — число атрибутов
  терминальный: text = texts[varint]
  иначе: attr_count пар (индекс имени атрибута, индекс значения)
Значения (H1.e, g):
  len = varint; peek = data[pos]
  peek==19 -> int32 BE (после 1 байта типа)
  peek==23 -> массив float: [23][тип][hi][lo] + записи [char][count][floats]
  иначе    -> строка длиной len (peek — первый байт самой строки)

varint (H1.f.b): байт <128 -> значение; иначе ((b&0x7F)<<8)|следующий.
"""
import sys

sys.path.insert(0, '/home/z/my-project/scripts')
from skin_unpack import unpack, be  # noqa: E402


class Reader:
    def __init__(self, data, start, length):
        self.data = data
        self.pos = start
        self.start = start
        self.length = length  # длина секции узлов

    @property
    def consumed(self):
        return self.pos - self.start

    def a(self):  # int32 BE
        v = be(self.data, self.pos, 4)
        self.pos += 4
        return v

    def b(self):  # varint
        b1 = self.data[self.pos]
        if b1 & 0xFF >= 128:
            v = ((b1 & 0x7F) << 8) | (self.data[self.pos + 1] & 0xFF)
            self.pos += 2
            return v
        self.pos += 1
        return b1 & 0xFF

    def c(self, n):  # utf-8 строка
        s = self.data[self.pos:self.pos + n].decode('utf-8')
        self.pos += n
        return s


def half_to_float(i30):
    if i30 == 0:
        return 0.0
    if i30 == 0x7C00:
        return float('inf')
    if i30 == 0x8000:
        return -0.0
    if i30 == 0xFC00:
        return float('-inf')
    import struct
    bits = ((i30 & 1023) << 13) | ((i30 & 32768) << 16) | (((i30 & 31744) + 114688) << 13)
    return struct.unpack('<f', struct.pack('<I', bits))[0]


def mini8_to_float(b):
    v = b & 0xFF
    sign = (v >> 7) & 1
    exp = (v >> 2) & 31
    mant = v & 3
    if exp == 31:
        return float('-inf') if sign else float('inf') if mant else float('nan')
    if exp == 0:
        return -0.0 if sign else 0.0
    import struct
    bits = (sign << 31) | (((exp + 112) & 255) << 23) | (mant << 21)
    return struct.unpack('<f', struct.pack('<I', bits))[0]


def mini24_to_float(b0, b1, b2):
    i43 = ((b0 & 0xFF) << 16) | ((b1 & 0xFF) << 8) | (b2 & 0xFF)
    sign = (i43 >> 23) & 1
    exp = (i43 >> 16) & 127
    mant = i43 & 65535
    import struct
    if exp == 127:
        if mant == 0:
            return float('inf') if sign == 0 else float('nan')
        return float('-inf') if sign else float('inf')
    if exp == 0:
        return 0.0
    bits = (sign << 31) | (mant << 7) | ((exp + 64) << 23)
    return struct.unpack('<f', struct.pack('<I', bits))[0]


class Node:
    def __init__(self, name, terminal):
        self.name = name
        self.terminal = terminal
        self.attrs = {}
        self.children = []
        self.text = ''


def decode_xml(data, off, size):
    r = Reader(data, off, size)
    r.pos = off + 5  # магия "CASB" + версия
    n_names = r.b()
    n_attrs = r.b()
    n_values = r.b()
    n_texts = r.b()  # b5 читается ДО таблиц (H1.e конструктор)
    names = [r.c(r.b()) for _ in range(n_names)]
    attr_names = [r.c(r.b()) for _ in range(n_attrs)]
    values = []
    for _ in range(n_values):
        slen = r.b()
        peek = data[r.pos] & 0xFF
        if 15 < peek < 25:
            r.pos += 1
            if peek == 23:
                ftype = data[r.pos] & 0xFF          # i18 = pos_after_v
                cnt = ((data[r.pos + 1] & 0xFF) << 8) | (data[r.pos + 2] & 0xFF)
                r.pos += 4                           # i16+4
                floats = []
                for _i in range(cnt):
                    ch = data[r.pos] & 0xFF
                    n = data[r.pos + 1] & 0xFF
                    r.pos += 2
                    if n == 0:
                        pass
                    elif ftype == 1:
                        for _j in range(n):
                            i30 = ((data[r.pos] & 0xFF) << 8) | (data[r.pos + 1] & 0xFF)
                            r.pos += 2
                            floats.append(half_to_float(i30))
                    elif ftype == 3:
                        for _j in range(n):
                            floats.append(mini8_to_float(data[r.pos])); r.pos += 1
                    elif ftype == 2:
                        for _j in range(n):
                            floats.append(mini24_to_float(data[r.pos], data[r.pos + 1], data[r.pos + 2]))
                            r.pos += 3
                    else:
                        for _j in range(n):
                            import struct
                            bits = be(r.data, r.pos, 4); r.pos += 4
                            floats.append(struct.unpack('<f', struct.pack('<I', bits))[0])
                values.append(('F[%s]' % ','.join(f'{x:.4g}' for x in floats)))
            elif peek == 19:
                values.append(str(r.a()))
            else:
                values.append(f'VAL?type={peek}')
        else:
            values.append(r.c(slen))
    texts = [r.c(r.b()) for _ in range(n_texts)]
    # секция узлов
    node_r = Reader(data, r.pos, size - (r.pos - off))

    def fmt(v):
        if isinstance(v, str) and v.startswith('F['):
            return v[2:-1]
        return v

    def parse_nodes(parent, depth):
        while node_r.consumed != node_r.length:
            p0 = node_r.pos
            tag = node_r.b()
            terminal = tag in (0, 1)
            flags = data[node_r.pos] & 0xFF
            node_r.pos += 1
            mode = flags & 0xC0
            attr_count = flags & 0x3F
            node = Node(names[tag], terminal)
            if terminal:
                node.text = texts[node_r.b()]
            elif attr_count > 0:
                for _i in range(attr_count):
                    ai = node_r.b()
                    vi = node_r.b()
                    if ai >= len(attr_names) or vi >= len(values):
                        raise IndexError(
                            f'attr index out of range на offset {p0 - off} '
                            f'(tag={tag} flags={flags:#x}): ai={ai} vi={vi}')
                    node.attrs[attr_names[ai]] = fmt(values[vi])
            parent.children.append(node)
            if mode == 0x40:
                while parse_nodes(node, depth + 1):
                    pass
            elif mode == 0x80:
                return parse_nodes(node, depth + 1)
            elif mode == 0xC0:
                break
        return False

    root = Node('#root', False)
    parse_nodes(root, 0)
    return root


def render(node, indent=0):
    pad = '  ' * indent
    attrs = ' '.join(f'{k}="{v}"' for k, v in node.attrs.items())
    if node.terminal:
        return [f'{pad}<{node.name}>{node.text}</{node.name}>']
    lines = [f'{pad}<{node.name}{" " + attrs if attrs else ""}>']
    for ch in node.children:
        lines.extend(render(ch, indent + 1))
    lines.append(f'{pad}</{node.name}>')
    return lines


if __name__ == '__main__':
    blob, entries = unpack()
    wanted = ['route_auth.xml', 'auth_steep_enter_login.xml',
              'auth_steep_password.xml', 'auth_steep_code.xml']
    for name, off, size in entries:
        if name in wanted:
            root = decode_xml(blob, off, size)
            print(f'########## {name} ##########')
            print('\n'.join(render(root)))
            print()
