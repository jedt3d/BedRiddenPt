#!/usr/bin/env bash
# Fails if raw style values appear in Dart code outside lib/theme/.
# Every colour, spacing, radius and text style in lib/ comes from
# lib/theme/tokens.dart (generated from design/tokens.json).
#
# Usage: tool/check_tokens.sh [dir]   (default: lib, relative to the repo root)
#
# Flags, per file (calls may span lines; whole-line // comments are ignored):
#   Color(0x…)  Color.fromARGB(  Color.fromRGBO(   raw colours
#   Colors.…  CupertinoColors.…                       palette colours
#   fontSize: <number>                                raw text size
#   EdgeInsets*.…(… <number> …)                       raw spacing
#   BorderRadius*.…(… <number> …)  Radius.circular(<number>)   raw radius
set -euo pipefail

cd "$(dirname "$0")/.."
dir="${1:-lib}"

if [ ! -d "$dir" ]; then
  echo "check_tokens: no directory $dir" >&2
  exit 2
fi

# A number that is not part of an identifier such as AppSpace.s16.
num='(?<![A-Za-z0-9_.])-?[0-9]'

files=$(find "$dir" -name '*.dart' -not -path "$dir/theme/*" | sort)
[ -z "$files" ] && { echo "check_tokens: OK (no Dart files in $dir)"; exit 0; }

# shellcheck disable=SC2086
if perl -0777 -ne '
  BEGIN { $bad = 0 }
  my $src = $_;
  $src =~ s{^([ \t]*//[^\n]*)}{" " x length($1)}mge;   # blank out comment lines, keep offsets
  my @rules = (
    ["raw Color",            qr/\bColor\(\s*0x|\bColor\.from(?:ARGB|RGBO)\(/],
    ["palette colour",       qr/(?<![A-Za-z0-9_])(?:Cupertino)?Colors\./],
    ["numeric fontSize",     qr/\bfontSize\s*:\s*-?[0-9.]/],
    ["numeric EdgeInsets",   qr/\bEdgeInsets\w*\.\w+\([^)]*?'"$num"'/],
    ["numeric BorderRadius", qr/\bBorderRadius\w*\.\w+\([^)]*?'"$num"'/],
    ["numeric Radius",       qr/\bRadius\.(?:circular|elliptical)\(\s*-?[0-9]/],
  );
  for my $r (@rules) {
    my ($what, $re) = @$r;
    while ($src =~ /$re/g) {
      my $line = 1 + (substr($src, 0, $-[0]) =~ tr/\n//);
      my ($text) = (split /\n/, $_, -1)[$line - 1];
      $text =~ s/^\s+//;
      print "$ARGV:$line: $what: $text\n";
      $bad = 1;
    }
  }
  END { exit $bad }
' $files; then
  echo "check_tokens: OK"
else
  echo "check_tokens: FAILED. Use AppColors / AppSpace / AppRadius / AppText from lib/theme/tokens.dart." >&2
  exit 1
fi
