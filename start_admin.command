#!/bin/zsh
cd -- "${0:A:h}" || exit 1
print '관리자 화면: http://127.0.0.1:8320/?admin=true'
print '서버를 사용하는 동안 이 터미널 창을 열어두세요.'
exec python3 -m http.server 8320 --bind 127.0.0.1 --directory build/web
