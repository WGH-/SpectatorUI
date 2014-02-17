import sys
import os
import subprocess
import argparse
import time
import json
import contextlib
import tempfile
from wsgiref.handlers import format_date_time 

import change_modpackages

UT3_DIRECTORY = r"C:\Program Files (x86)\Unreal Tournament 3"
#UT3_DIRECTORY = r"C:\Program Files (x86)\Steam\steamapps\common\Unreal Tournament 3"

def write_build_date(uci_file):
    with open(uci_file, "w") as f:
        print('const BUILD_TIME = %s;' % json.dumps(format_date_time(time.time())), file=f)

def run_ut3(args):
    ut3 = os.path.join(UT3_DIRECTORY, "Binaries", "ut3.com")
    args = [ut3] + list(args)

    subprocess.check_call(args)

def merge_packages(src, dst):
    # src must be unpublished
    # dst doesn't matter?

    # replace backslashes with forward slashes
    # even though they're not "native" separators on Windows
    # otherwise we'll end up in escaping hell
    src = src.replace("\\", "/")
    dst = dst.replace("\\", "/")

    run_ut3(["Editor.MergePackages", src, dst])

def cook_packages(packages):
    packages = list(packages)
    if packages:
        run_ut3(["Editor.CookPackages", "-platform=pc"] + packages)

@contextlib.contextmanager
def hide_file(filename):
    if os.path.exists(filename):
        new_filename = tempfile.mktemp()
        os.rename(filename, new_filename)
    else:
        new_filename = None

    try:
        yield
    finally:
        try:
            os.unlink(filename)
        except OSError:
            pass
        if new_filename:
            os.rename(new_filename, filename)

@contextlib.contextmanager
def hide_files(filenames):
    managers = map(hide_file, filenames)

    with contextlib.ExitStack() as stack:
        map(stack.enter_context, managers)
        yield

def build(mods, files_to_hide=[], merges=[], cooking=[]):
    assert all(os.path.splitext(mod)[1] == "" for mod in mods)
    assert all(os.path.splitext(path)[1] != "" for path in files_to_hide)
    assert all(os.path.splitext(path)[1] != "" for t in merges for path in t)
    assert all(os.path.splitext(mod)[1] == "" for mod in cooking)

    change_modpackages.rewrite_config("Config/UTEditor.ini", mods)

    with hide_files(files_to_hide):
        run_ut3(["make", "-full"])

        for src, dst in merges:
            merge_packages(src, os.path.abspath(dst))

        for mod in mods:
            run_ut3(["Editor.StripSource", mod])

    try:
        os.unlink("Published/CookedPC/GlobalPersistentCookerData.upk")
    except OSError:
        pass

    cook_packages(cooking)

    for mod in set(mods) - set(cooking):
        # cooking automatically moves mods to Published
        # if we skip cooking, we must move them manually
        os.rename(
            os.path.join("Unpublished/CookedPC/Script", "%s.u" % mod),
            os.path.join("Published/CookedPC/Script", "%s.u" % mod)
        )
