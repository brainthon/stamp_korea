# 신규 우표 자동 등록 (2026-10-09)

## 실제 서버 작업
- Supabase pg_cron `stamp-catalog-daily`: 매일 한국시간 오전 9시 30분(UTC 00:30).
- pg_net → Edge Function `sync-stamp-catalog` → 공식 우표 DB 및 기존 신규 우표 알림 트리거.
- 컴퓨터 및 Codex 실행 여부와 무관하다. Supabase 프로젝트가 실행 중이어야 한다. 프로젝트 정지 중에는 실행되지 않는다.
- 첫 3페이지의 최근 우표를 조회하고 최신 300개 DB 원문 주소와 비교한다. 누락 자료는 실행당 최대 10개 등록하고 나머지는 다음날 처리한다. 오랜 기간 누락됐거나 3페이지보다 오래된 우표는 별도 전체 수집이 필요하다.
- 원문 상세정보·설명과 공식 이미지 URL을 저장한다. 이미지는 Storage에 복사하지 않는다.
- 이미지 HTTPS 응답 및 Content-Type, 번호·날짜·출처 호스트·원문 해시를 검증한다.
- 기존 자료를 덮어쓰지 않는 insert-only 방식. 기존 우표 정보 변경은 관리자 수정 대상이다.
- 실패 시 해당 실행의 신규 자료 전체 등록을 취소하고 다음 실행에서 재시도한다. 기존 우표는 변경하지 않는다.

## 권한 및 실행 이력
- 호출 토큰은 DB 안에서 무작위 생성하고 Vault에 저장한다. 클라이언트와 문서에 토큰 또는 서비스 키를 포함하지 않는다.
- 함수 자체에서 토큰 해시를 검증하므로 플랫폼 JWT 검사 대신 별도 서버 인증을 사용한다.
- 검증·실행·완료 RPC는 service_role만 호출 가능하며 PUBLIC/anon/authenticated는 실행할 수 없다.
- 동시에 하나의 scheduled_import만 실행한다. 15분 이상 멈춘 실행은 다음 시작 시 실패로 정리한다.
- `catalog_import_runs`: running/success/failed, 시각, 등록 수, 실패 단계. 기존 관리자 수집 이력 화면에서 확인 가능하다.
- `cron.job_run_details`: 예약 요청 기록. `net._http_response`: HTTP 응답(일시 보관). 예약 요청 성공과 실제 등록 성공은 각각 확인한다.

## 배포 파일
- supabase/catalog_auto_sync.sql
- supabase/functions/sync-stamp-catalog/index.ts
- supabase/functions/sync-stamp-catalog/portal.ts

수동 시험은 cron.job에 있는 동일한 net.http_post 명령을 SQL 에디터에서 실행한다. Vault 원문 토큰을 조회하거나 복사할 필요가 없다.

## 검증
실제 신규 우표 원문을 기존 Python 파서와 비교. 출처 호스트 변경·깨진 상세 페이지·빈 목록 거절. 무인증 요청 거절. 서버에서 예약 호출과 동일한 요청을 보내 신규 우표 등록 및 실행 이력 확인. 앱은 실행 시 클라우드 카탈로그를 다시 가져오며, 이미 실행 중인 앱은 재시작하여 최신 우표를 확인한다.

검증 결과: 서버 HTTP 200, 신규 1종(epost_3927) 등록, 동일 자료 재등록 0건. 기존 Codex 자동화는 PAUSED로 전환했다. 관리자 이력에는 첫 시험에서 발생한 DB 변수명 충돌 실패 1건과 수정 후 성공 기록이 남는다.
