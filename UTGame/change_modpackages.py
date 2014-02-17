import re
import sys

MODPACKAGES_PATTERN = re.compile("^(;?)(ModPackages=)(?P<pkg>\w+)(.*)$")

def process_line(s, packages_to_enable):
    def repl(matchobj):
        comment = ""
        if matchobj.group("pkg") not in packages_to_enable:
            comment = ";"

        return comment + matchobj.expand(r"\2\3\4")

    return MODPACKAGES_PATTERN.sub(repl, s)

def rewrite_config(config, enabled_mods):
    with open(config, "r") as f:
        lines = [s.rstrip("\n") for s in f]

    with open(config, "w") as f:
        it = iter(lines)
        
        for line in it:
            print(line, file=f)
            if line.strip() == "[ModPackages]":
                break

        for line in it:
            if line.strip().startswith("["):
                print(line, file=f)
                break
            else:
                print(process_line(line, enabled_mods), file=f)

        for line in it:
            print(line, file=f)
