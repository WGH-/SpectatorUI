import struct

def magic_meta(name, parents, dict):
    def read_maker(name, format_string):
        s = struct.Struct(format_string)
        def read(self):
            return s.unpack(self._f.read(s.size))[0]
        read.__name__ = name
        return read

    for k, v in dict.items():
        if k.startswith("read_") and type(v) == type(""):
            dict[k] = read_maker(k, v)

    return type(name, parents, dict)

class BinaryReader(metaclass=magic_meta):
    def __init__(self, f):
        self._f = f

    def seek(self, n):
        self._f.seek(n)

    def tell(self):
        return self._f.tell()

    read_int8 = "b"
    read_uint8 = "B"
    read_int16 = "h"
    read_uint16 = "H"
    read_int32 = "i"
    read_uint32 = "I"
    read_int64 = "q"
    read_uint64 = "Q"

    def read_string(self, n, encoding="ascii"):
        s = self._f.read(n).decode(encoding)
        if s[-1] != "\0":
            raise ValueError(binary)
        return s[:-1]
    
    def read_bytes(self, n):
        return self._f.read(n)

    def read_guid(self):
        return self._f.read(16)

    def read_discard(self, n):
        self._f.seek(n, 1)
