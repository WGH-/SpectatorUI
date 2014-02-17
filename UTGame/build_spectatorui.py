#!/usr/bin/env python3
import os
import sys
import build

def main():
    if not os.path.exists("Src/SpectatorUI_2"):
        print("Please create a symlink from 'Src/SpectatorUI' to 'Src/SpectatorUI_2'", file=sys.stderr)
        raise SystemExit(1)

    build.build(
        mods=["SpectatorUI_2"],
        files_to_hide=[
            "Config/UTSpectatorUI_Bookmarks.ini", 
            "Config/UTSpectatorUI.ini",
        ],
        merges=[
            ("Unpublished/CookedPC/SpectatorUI_Content.upk", "Unpublished/CookedPC/Script/SpectatorUI_2.u"),
        ],
        cooking=[
            "SpectatorUI_2"
        ]
    )
    

if __name__ == "__main__":
    main()
