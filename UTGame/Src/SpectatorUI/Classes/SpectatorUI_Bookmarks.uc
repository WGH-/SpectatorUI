/*
SpectatorUI
Copyright (C) 2014 Maxim "WGH" 
   
This program is free software; you can redistribute and/or modify 
it under the terms of the Open Unreal Mod License version 1.1.
*/
class SpectatorUI_Bookmarks extends Object
    perobjectconfig
    config(SpectatorUI_Bookmarks);

struct BookmarkStruct {
    var Name Name;
    var Vector Location;
    var Rotator Rotation;
    var float FOV;
};

var protected config array<BookmarkStruct> Bookmarks;

function bool LoadBookmark(out BookmarkStruct Bookmark) {
    local int i;

    i = Bookmarks.Find('Name', Bookmark.Name);
    if (i == INDEX_NONE) {
        return false;
    } else {
        Bookmark = Bookmarks[i];
        return true;
    }
}

function SaveBookmark(BookmarkStruct Bookmark) {
    local int i;

    i = Bookmarks.Find('Name', Bookmark.Name);
    if (i == INDEX_NONE) {
        Bookmarks.Add(1);
        i = Bookmarks.Length - 1;
    }
    Bookmarks[i] = Bookmark;

    SaveConfig();
}
