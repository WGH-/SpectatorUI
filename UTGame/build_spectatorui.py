#!/usr/bin/env python3
import os
import sys
import io

import build

import unreal_package
import unreal_bytecode

VERSION = "2_3"
PACKAGE_NAME = "SpectatorUI_" + VERSION

def patch_bytecode(bytecode):
    decoded = unreal_bytecode.BytecodeReader(io.BytesIO(bytecode))

    # sanity check
    if decoded.serialize() != bytecode:
        raise ValueError("bytecode decoder is broken")

    if not isinstance(decoded[0], unreal_bytecode.Opcodes.Op_Let):
        raise ValueError("unexpected %r opcode" % decoded[0])

    decoded[0].swap()

    return decoded.serialize()

def patch_package():
    # black magic
    with open("Published/CookedPC/Script/{}.u".format(PACKAGE_NAME), "r+b") as f:
        pkg = unreal_package.UnrealPackage(f)
        
        offset, size = pkg.find_function_bytecode(["Default__SpectatorUI_Mut", "ModifyParentSequence"])

        f.seek(offset)
        bytecode = f.read(size)

        bytecode = patch_bytecode(bytecode)

        f.seek(offset)
        f.write(bytecode)

        print("bytecode successfully patched", file=sys.stderr)

def main():
    if not os.path.exists("Src/{}".format(PACKAGE_NAME)):
        print("Please create a symlink from 'Src/SpectatorUI' to 'Src/{}'".format(PACKAGE_NAME), file=sys.stderr)
        raise SystemExit(1)

    build.build(
        mods=[PACKAGE_NAME],
        files_to_hide=[
            "Config/UTSpectatorUI_Bookmarks.ini", 
            "Config/UTSpectatorUI.ini",
        ],
        merges=[
            ("Unpublished/CookedPC/SpectatorUI_Content.upk", "Unpublished/CookedPC/Script/{}.u".format(PACKAGE_NAME)),
        ],
        cooking=[
            PACKAGE_NAME
        ]
    )
    
    patch_package()
    

if __name__ == "__main__":
    main()
