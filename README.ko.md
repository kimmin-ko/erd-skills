# db-erd

[English](README.md) | **한국어**

실제 운영 중인 데이터베이스에서 ERD를 생성하는 [Agent Skill](https://agentskills.io/home)입니다 — **Claude Code**와 **Codex**에서 사용할 수 있습니다.

단순히 다이어그램만 그리지 않습니다. 먼저 스키마의 외래키(FK) 그래프를 측정한 뒤, 실제로 읽을 수 있는 결과물을 선택합니다: 스키마가 작으면 단일 Mermaid 다이어그램, 크면 도메인별로 분리된 인터랙티브 뷰를 만듭니다.

## 왜 필요한가

테이블 100개를 다이어그램 하나에 그리면 아무도 읽을 수 없는 결과물이 나옵니다. 흔히 하는 조언인 "도메인별로 나눠라"는 정작 어려운 부분—*어떤* 도메인으로 나눌지—을 해결해주지 않습니다. 테이블 이름 접두사는 믿을 수 없습니다. 이 Skill은 도메인 경계를 FK 그래프로부터 도출하므로, 분리 결과가 실제 데이터 연결 구조를 반영합니다.

또한 어디에도 명확히 문서화되어 있지 않은 워크플로 지식도 함께 담고 있습니다. 예를 들어 [Liam ERD](https://liambx.com)는 MySQL DDL을 전혀 읽지 못해서 [tbls](https://github.com/k1LoW/tbls)를 중간 다리로 써야 한다는 점 등입니다. 자세한 내용은 [`references/tool-notes.md`](skills/db-erd/references/tool-notes.md)를 참고하세요.

## 설치

```bash
git clone https://github.com/kimmin-ko/erd-skills.git
cd erd-skills
./install.sh            # 두 에이전트 모두 설치; 하나만 원하면 --claude 또는 --codex
```

| 에이전트 | 설치 위치 |
|---|---|
| Claude Code | `~/.claude/skills/db-erd` (프로젝트 단위: `.claude/skills/`) |
| Codex | `~/.agents/skills/db-erd` (프로젝트 단위: `.agents/skills/`) |

두 에이전트 모두 동일한 `SKILL.md` 형식을 읽으므로, 디렉터리 하나로 양쪽을 모두 지원합니다. `./install.sh --uninstall`로 제거할 수 있습니다.

## 요구 사항

- [`tbls`](https://github.com/k1LoW/tbls) — `brew install tbls`
- `npx`를 사용할 수 있는 Node.js (Liam은 필요할 때 자동으로 받아옵니다)

## 사용법

에이전트에게 자연어로 요청하세요:

> mysql://localhost:3306/shop 데이터베이스의 ERD를 그려줘

또는 직접 호출: Claude Code에서는 `/db-erd`, Codex에서는 `/skills`.

지원하는 데이터베이스는 `tbls`가 지원하는 모든 것입니다: MySQL, PostgreSQL, MariaDB, SQLite, SQL Server, Redshift, BigQuery, Spanner. DSN만 바꾸면 됩니다.

## 결과물

측정 결과에 따라 다음 중 하나를 생성합니다:

- **작은 스키마** — 마크다운에 인라인으로 들어가는 Mermaid `erDiagram`. 버전 관리가 가능하고 어디서든 렌더링됩니다.
- **큰 스키마** — 도출된 도메인마다 하나씩 인터랙티브 줌 뷰가 들어 있는 `liam-erd/`, 그리고 컨텍스트 맵과 전체 뷰
- **선택 사항** — 테이블마다 페이지와 ER SVG가 포함된 `docs/schema/` 마크다운 (`tbls doc`)

여기에 더해 FK 그래프가 드러내는 문제들도 함께 검토합니다: 고아 테이블, 복합 UNIQUE가 빠진 조인 테이블, 기본값 `RESTRICT`로 남아 있는 FK, 타임스탬프 없는 상태(status) enum 등입니다.

## 직접 사용하기

스크립트는 에이전트 없이도 동작합니다:

```bash
export TBLS_DSN='mysql://user:pass@127.0.0.1:3306/dbname'
tbls out -t json -o tbls.json "$TBLS_DSN"

node skills/db-erd/scripts/gen-viewpoints.mjs tbls.json   # -> .tbls.yml
./skills/db-erd/scripts/build-erd.sh                      # -> liam-erd/
npx http-server -c-1 -p 8899 liam-erd                     # http://127.0.0.1:8899
```

`ERD_HUB_MIN=2`로 설정하면 더 많고 작은 도메인으로 분리됩니다. `.tbls.yml`은 자동 생성되지만 이후 직접 수정하는 것을 전제로 합니다 — 도메인 이름을 바꾸거나, 아직 너무 큰 도메인을 추가로 나눌 수 있습니다.

## 시크릿(비밀 정보)

`.tbls.yml`은 비밀번호를 평문으로 넣지 않고 `dsn: ${TBLS_DSN}` 형태로 생성되므로 커밋해도 안전합니다. 생성된 결과물(output)은 gitignore 처리되어 있으니, 커밋하지 말고 다시 생성하세요.

## 라이선스

MIT
