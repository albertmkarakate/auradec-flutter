import 'package:flutter/material.dart';

const kBrandOrange  = Color(0xFFFF5C1A);
const kBrandGold    = Color(0xFFF5B32A);
const kBrandGreen   = Color(0xFF29F89E);
const kBrandCoral   = Color(0xFFFF4D6A);

const kBg0 = Color(0xFF060507);
const kBg1 = Color(0xFF0E0B13);
const kBg2 = Color(0xFF17121F);

const kFg1 = Color(0xFFECE5D8);
const kFg2 = Color(0xFF9E8FA0);
const kFg3 = Color(0xFF5C4F60);

const kBorder = Color(0xFF2A1F30);

/// Audio file extensions Namida-style
const kAudioExtensions = {
  'mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus',
  'wav', 'wma', 'ape', 'alac', 'mka', 'm4b',
};

/// SharedPreferences keys
const kPrefTracks           = 'auradec_tracks_v2';
const kPrefSettings         = 'auradec_settings_v2';
const kPrefExcludedPaths    = 'auradec_excluded_paths';
const kPrefCheckedFolders   = 'auradec_checked_folders';
const kPrefScannedOnce      = 'auradec_scanned_once';
const kPrefRatings          = 'auradec_ratings';
const kPrefPlaylists        = 'auradec_playlists';
const kPrefRepeat           = 'auradec_repeat';
const kPrefShuffle          = 'auradec_shuffle';
const kPrefVolume           = 'auradec_volume';
