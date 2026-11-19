#!/usr/bin/env bash
# Fails if raw style values appear in Dart code outside lib/theme/.
# Every colour, spacing, radius and text style in lib/ comes from
# lib/theme/tokens.dart (generated from design/tokens.json).
#
# Usage: tool/check_tokens.sh [dir]   (default: lib, relative to the repo root)
#
# Flags, per file (calls may span lines; whole-line // comments are ignored):
#   Color(<number>…)  Color.from…(  HSLColor.  HSVColor.   raw colours
#   Colors.…  CupertinoColors.…                            palette colours
#   fontSize: <expression with a number>                   raw text size
#   EdgeInsets*.…(… <number> …)                            raw spacing
#   BorderRadius*.…(… <number> …)  Radius.…(<number>)      raw radius
#   import 'package:flutter/material.dart'  Icons.…        Material (SPEC §2)
# Arguments are matched with balanced parentheses, so nested calls such as
# EdgeInsets.only(left: f(x), top: 8) are read to the end.
set -euo pipefail

cd "$(dirname "$0")/.."
dir="${1:-lib}"

if [ ! -d "$dir" ]; then
  echo "check_tokens: no directory $dir" >&2
  exit 2
fi

files=$(find "$dir" -name '*.dart' -not -path "$dir/theme/*" | sort)
[ -z "$files" ] && { echo "check_tokens: OK (no Dart files in $dir)"; exit 0; }

# shellcheck disable=SC2086
if perl -0777 -ne '
  BEGIN { $bad = 0 }
  my $src = $_;
  $src =~ s{^([ \t]*//[^\n]*)}{" " x length($1)}mge;   # blank out comment lines, keep offsets
  # A number that is not part of an identifier such as AppSpace.s16.
  my $num  = qr/(?<![A-Za-z0-9_.])-?[0-9]/;
  my $args = qr/(?<args>\((?:[^()]++|(?&args))*\))/;
  # A named-argument value: up to the next top-level comma or closing paren.
  my $expr = qr/(?<expr>(?:[^(),;]++|(?<p>\((?:[^()]++|(?&p))*\)))+)/;
  # [what, pattern, capture that must contain a number (or "" = any match)]
  my @rules = (
    ["raw Color",            qr/\bColor\(\s*-?[0-9]|\bColor\.from\w*\(|\bHS[LV]Color\./, ""],
    ["palette colour",       qr/(?<![A-Za-z0-9_])(?:Cupertino)?Colors\./, ""],
    ["Material import",      qr{\bimport\s+[\x27"]package:flutter/material\.dart[\x27"]}, ""],
    ["Material icon",        qr/(?<![A-Za-z0-9_])Icons\./, ""],
    ["numeric fontSize",     qr/\bfontSize\s*:\s*$expr/, "expr"],
    ["numeric EdgeInsets",   qr/\bEdgeInsets\w*\.\w+\s*$args/, "args"],
    ["numeric BorderRadius", qr/\bBorderRadius\w*\.\w+\s*$args/, "args"],
    ["numeric Radius",       qr/\bRadius\.\w+\s*$args/, "args"],
  );
  for my $r (@rules) {
    my ($what, $re, $cap) = @$r;
    while ($src =~ /$re/g) {
      next if $cap ne "" && $+{$cap} !~ $num;
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
