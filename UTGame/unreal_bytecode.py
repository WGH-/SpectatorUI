import sys
import struct

import binary_reader

def opcode_meta(name, parents, dict):
    codes = {}
    dict["codes"] = codes

    for k, v in dict.items():
       if k.startswith("Op_"):
            codes[v.code] = v 

    return type(name, parents, dict)

class Opcodes(metaclass=opcode_meta):
    class Op_Let:
        code = 0x0F
        def __init__(self, reader):
            self.left = reader._read_bytecode()
            self.right = reader._read_bytecode()

        def swap(self):
            self.left, self.right = self.right, self.left

        def serialize(self):
            return bytes([self.code]) + self.left.serialize() + self.right.serialize()

    class Op_LocalVariable:
        code = 0x00
        def __init__(self, reader):
            self.ref = reader.Ref(reader)
        
        def serialize(self):
            return bytes([self.code]) + self.ref.serialize()
    
    class Op_InstanceVariable(Op_LocalVariable):
        code = 0x01

    class Op_DefaultVariable(Op_LocalVariable):
        code = 0x02
    
    class Op_Context:
        code = 0x19
        def __init__(self, reader):
            self.context = reader._read_bytecode()
            self.exprSize = reader.r.read_int16()
            self.bSize = reader.r.read_int8()
            self.value = reader._read_bytecode()

        def serialize(self):
            return bytes([self.code]) + self.context.serialize() + struct.pack("h", self.exprSize) + struct.pack("b", self.bSize) + self.value.serialize()
    
    class Op_Return:
        code = 0x04
        def __init__(self, reader):
            self.value = reader._read_bytecode()
        
        def serialize(self):
            return bytes([self.code]) + self.value.serialize()

    class Op_Nothing:
        code = 0x0B
        def __init__(self, reader):
            pass

        def serialize(self):
            return bytes([self.code])

    class Op_EndOfScript:
        code = 0x53
        def __init__(self, reader):
            pass

        def serialize(self):
            return bytes([self.code])

class BytecodeReader():
    class Ref:
        def __init__(self, reader):
            self._id = reader.r.read_int32()
        
        def serialize(self):
            return struct.pack("i", self._id)
    
    def _read_bytecode(self):
        opcode = self.r.read_uint8()

        try:
            clazz = Opcodes.codes[opcode]
        except KeyError:
            print("Opcode 0x%02X not known" % opcode, file=sys.stderr)
            raise
        return clazz(self)

    def _read_bytecode_all(self):
        while True:
            op = self._read_bytecode()
            self._bytecodes.append(op)
            if isinstance(op, Opcodes.Op_EndOfScript):
                break

    # public interface
    def __init__(self, file_object):
        self.r = binary_reader.BinaryReader(file_object)
        self._bytecodes = []
        self._read_bytecode_all()

    def __getitem__(self, index):
        return self._bytecodes[index]

    def serialize(self):
        return b"".join(x.serialize() for x in self._bytecodes)
