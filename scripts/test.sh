#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
APP="$PWD/build/剪贴花园.app/Contents/MacOS/ClipGarden"
mkdir -p Deliverables
"$APP" --self-test | tee Deliverables/测试结果.txt
"$APP" --demo --screenshot "$PWD/Deliverables/主界面.png"
"$APP" --demo --consent-preview --screenshot "$PWD/Deliverables/首次确认.png"
"$APP" --demo --settings-preview --screenshot "$PWD/Deliverables/设置.png"
"$APP" --demo --detail-preview --screenshot "$PWD/Deliverables/预览.png"
