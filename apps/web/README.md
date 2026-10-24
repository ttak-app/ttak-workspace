# Ttak Web

React + TypeScript + Vite 기반의 정적 랜딩 페이지입니다.
Node.js 24, npm 11을 사용합니다. 의존성과 잠금 파일은 저장소 루트에서 관리합니다.

```sh
# 저장소 루트에서
npm ci
npm run dev:web
npm run lint:web
npm run build:web
npm run preview:web
```

개발 서버는 기본적으로 http://localhost:5173 에서 실행됩니다.
빌드 산출물은 `apps/web/dist`에 생성됩니다.
현재는 최소 시작 화면이며, 기존 상위 Ttak 폴더의 프로토타입은 이관하지 않았습니다.
