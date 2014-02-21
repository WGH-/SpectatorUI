import struct

from binary_reader import BinaryReader

class UnrealPackage:

    class ImportTableEntry:
        __slots__ = [
            "package_name", 
            "class_name",
            "outer",
            "object_name",
            "flags"
        ]

    class ExportTableEntry:
        __slots__ = [
            "object_name",
            "clazz",
            "outer",
            "export_offset",
            "export_size",
            "children"
        ]

        def __init__(self):
            self.children = []

    def __init__(self, file_object):
        r = self._r = BinaryReader(file_object)

        signature = r.read_int32()
        package_version = r.read_int32()
        first_export_offset = r.read_int32()
        folder_name_length = r.read_int32()
        folder_name = r.read_string(folder_name_length)
        package_flags = r.read_int32()
        names_count = r.read_int32()
        names_offset = r.read_int32()
        exports_count = r.read_int32()
        exports_offset = r.read_int32()
        imports_count = r.read_int32()
        imports_offset = r.read_int32()
        r.read_int32()
        guid = r.read_guid()
        generations_counts = r.read_int32()

        for i in range(generations_counts):
            r.read_discard(12)

        engine_version = r.read_int32()
        cooker_version = r.read_int32()

        if engine_version == 3240:
            r.read_discard(28)

        if package_flags & 0x00800000:
            raise ValueError("compressed packages aren't supported")

        self._decode_names(names_offset, names_count)
        self._decode_import_table(imports_offset, imports_count)
        self._decode_export_table(exports_offset, exports_count)

        def resolve_attr(obj, attrname):
            val = getattr(obj, attrname)
            if val == 0:
                val = None
            elif val < 0:
                val = self._import_table[-(val + 1)]
            else:
                val = self._export_table[val]

            setattr(obj, attrname, val)

        self._toplevel_exports = []

        for entry in self._import_table:
            resolve_attr(entry, "outer")
        for entry in self._export_table:
            resolve_attr(entry, "clazz")
            resolve_attr(entry, "outer")

            if entry.outer is None:
                self._toplevel_exports.append(entry)
            else:
                entry.outer.children.append(entry)
                
    def _decode_names(self, offset, count):
        r = self._r

        r.seek(offset)
        table = self._name_table = []
        for i in range(count):
            n = r.read_int32()
            if n < 0:
                encoding = "UTF-16"
                n *= -2
            else:
                encoding = "ascii"

            s = r.read_string(n, encoding)
            flags = r.read_int64()

            table.append((s, flags))
            
    def _decode_import_table(self, offset, count):
        r = self._r
        r.seek(offset)

        table = self._import_table = []
        so = struct.Struct("=iiiiiii")
        
        for i in range(count):
            (
                package_name_idx,
                _,
                class_name_idx,
                _,
                outer_idx,
                object_name_idx,
                flags
            ) = so.unpack(r.read_bytes(so.size))

            entry = self.ImportTableEntry()

            entry.package_name = self._name_table[package_name_idx][0]
            entry.class_name = self._name_table[class_name_idx][0]
            entry.outer = outer_idx
            entry.object_name = self._name_table[object_name_idx][0]
            entry.flags = flags

            table.append(entry)
            
    def _decode_export_table(self, offset, count):
        r = self._r
        r.seek(offset)

        table = self._export_table = []
        so = struct.Struct("=iiiiiiqiii")

        for i in range(count):
            (
                class_index,
                super_idx,
                outer_idx,
                object_name_idx,
                _,
                _,
                flags,
                export_size,
                export_offset,
                component_map_count
            ) = so.unpack(r.read_bytes(so.size))

            r.read_discard(component_map_count * 3 * 4)

            export_flags = r.read_int32()
            net_object_count = r.read_int32()
            r.read_discard(4 * net_object_count)
            if net_object_count == 0:
                r.read_int32()
            guid = r.read_guid()
            if net_object_count > 0:
                r.read_int32()
            
            entry = self.ExportTableEntry()
            entry.object_name = self._name_table[object_name_idx][0]
            entry.clazz = class_index
            entry.outer = outer_idx
            entry.export_offset = export_offset
            entry.export_size = export_size

            table.append(entry)

    def find_function_bytecode(self, path):
        offset, size = self.find_function(path) 
        
        r = self._r
        r.seek(offset + 40)

        bytecode_size = r.read_int32()

        return r.tell(), bytecode_size

    def find_function(self, path):
        table = self._export_table

        while 1:
            name = path.pop(0)
            for entry in table:
                if entry.object_name == name:
                    break
            else:
                raise KeyError("couldn't find %r, problems at item %r" % (path, name))

            if not path:
                return entry.export_offset, entry.export_size

