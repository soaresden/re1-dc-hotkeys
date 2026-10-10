#!/bin/bash
for p in $(pgrep -x pcsx-redux) $(pgrep -x AppRun); do kill -9 $p 2>/dev/null; done
true
