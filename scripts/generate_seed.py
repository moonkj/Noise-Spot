#!/usr/bin/env python3
"""
Naver Local Search API → assets/seed/brand_cafes.json 시드 생성기.

사용법:
    export NAVER_CLIENT_ID=발급받은_ID
    export NAVER_CLIENT_SECRET=발급받은_SECRET
    pip install requests
    python3 scripts/generate_seed.py

API 등록: https://developers.naver.com/apps/#/register
→ 검색 API → 지역(로컬) 체크 → Client ID/Secret 발급

출력: assets/seed/brand_cafes.json
  - SeedService.seedIfNeeded() 가 앱 최초 설치 시 Supabase에 upsert
"""

import json
import os
import re
import time
from html import unescape

try:
    import requests
except ImportError:
    print("❌ requests 패키지가 없습니다. 먼저 실행하세요: pip install requests")
    raise SystemExit(1)

# ── 브랜드 15종 ──────────────────────────────────────────────────────────────
BRANDS = [
    "스타벅스",
    "투썸플레이스",
    "이디야커피",
    "메가커피",
    "할리스커피",
    "컴포즈커피",
    "파스쿠찌",
    "탐앤탐스",
    "커피빈",
    "엔제리너스",
    "폴바셋",
    "블루보틀",
    "카페베네",
    "빽다방",
    "드롭탑",
]

# 브랜드명 → 타이틀 매칭에 쓸 최소 키워드 (짧은 이름 포함)
BRAND_MATCH: dict[str, list[str]] = {
    "스타벅스": ["스타벅스"],
    "투썸플레이스": ["투썸"],
    "이디야커피": ["이디야"],
    "메가커피": ["메가커피", "메가mgc"],
    "할리스커피": ["할리스"],
    "컴포즈커피": ["컴포즈"],
    "파스쿠찌": ["파스쿠찌"],
    "탐앤탐스": ["탐앤탐"],
    "커피빈": ["커피빈", "coffee bean"],
    "엔제리너스": ["엔제리너스"],
    "폴바셋": ["폴바셋"],
    "블루보틀": ["블루보틀", "blue bottle"],
    "카페베네": ["카페베네", "caffe bene"],
    "빽다방": ["빽다방"],
    "드롭탑": ["드롭탑"],
}

# ── 16개 지역 ─────────────────────────────────────────────────────────────────
REGIONS = [
    "서울 강남구",
    "서울 마포구 홍대",
    "서울 종로구",
    "서울 강동구",
    "부산 서면",
    "대구 동성로",
    "인천 부평",
    "광주 충장로",
    "대전 둔산",
    "울산 삼산",
    "수원 영통",
    "성남 판교",
    "청주 성안길",
    "전주 객사",
    "제주 연동",
    "고양 일산",
]

NAVER_URL = "https://openapi.naver.com/v1/search/local.json"
OUTPUT_PATH = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "assets", "seed", "brand_cafes.json")
)


def clean_html(text: str) -> str:
    return unescape(re.sub(r"<[^>]+>", "", text))


def extract_place_id(link: str) -> str | None:
    """네이버 지도 URL에서 place ID 추출 — 없으면 None."""
    # https://map.naver.com/v5/entry/place/1234567890
    m = re.search(r"/place/(\d+)", link)
    return m.group(1) if m else None


def search_local(
    query: str, client_id: str, client_secret: str, display: int = 5
) -> list[dict]:
    headers = {
        "X-Naver-Client-Id": client_id,
        "X-Naver-Client-Secret": client_secret,
    }
    params = {"query": query, "display": display, "sort": "random"}
    try:
        resp = requests.get(NAVER_URL, headers=headers, params=params, timeout=10)
        resp.raise_for_status()
        return resp.json().get("items", [])
    except Exception as e:
        print(f"  [WARN] '{query}' 검색 실패: {e}")
        return []


def is_brand_match(title: str, brand: str) -> bool:
    title_lower = title.lower()
    for kw in BRAND_MATCH.get(brand, [brand]):
        if kw.lower() in title_lower:
            return True
    return False


def main() -> None:
    client_id = os.environ.get("NAVER_CLIENT_ID", "").strip()
    client_secret = os.environ.get("NAVER_CLIENT_SECRET", "").strip()

    if not client_id or not client_secret:
        print("❌ 환경변수를 설정하세요:")
        print("   export NAVER_CLIENT_ID=발급받은_ID")
        print("   export NAVER_CLIENT_SECRET=발급받은_SECRET")
        raise SystemExit(1)

    total = len(BRANDS) * len(REGIONS)
    done = 0
    spots_by_id: dict[str, dict] = {}

    print(f"🔍 {len(BRANDS)}개 브랜드 × {len(REGIONS)}개 지역 = {total}쿼리 시작...")

    for brand in BRANDS:
        for region in REGIONS:
            query = f"{region} {brand}"
            items = search_local(query, client_id, client_secret, display=5)

            for item in items:
                title = clean_html(item.get("title", ""))
                mapx = item.get("mapx")
                mapy = item.get("mapy")
                link = item.get("link", "")
                address = item.get("roadAddress") or item.get("address", "")

                if not title or not mapx or not mapy:
                    continue

                # 브랜드명 포함 여부 확인
                if not is_brand_match(title, brand):
                    continue

                try:
                    lng = int(mapx) * 1e-7
                    lat = int(mapy) * 1e-7
                except (ValueError, TypeError):
                    continue

                # 한국 좌표 범위 검증 (WGS84)
                if not (33.0 <= lat <= 38.5 and 124.0 <= lng <= 132.0):
                    continue

                place_id = extract_place_id(link) or f"{title}||{address}"

                if place_id not in spots_by_id:
                    spots_by_id[place_id] = {
                        "name": title,
                        "naver_place_id": place_id,
                        "lat": round(lat, 7),
                        "lng": round(lng, 7),
                    }

            done += 1
            if done % 30 == 0 or done == total:
                print(f"  진행: {done}/{total} | 누적 스팟: {len(spots_by_id)}개")

            # 네이버 API 초당 10건 제한 대응
            time.sleep(0.11)

    spots = list(spots_by_id.values())
    output = {
        "version": 1,
        "description": (
            f"Brand cafe seed data — {len(spots)} spots from Naver Local Search. "
            "Generated by scripts/generate_seed.py"
        ),
        "spots": spots,
    }

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ 완료! {len(spots)}개 브랜드 카페 → {OUTPUT_PATH}")
    print("   다음: flutter build ios --release ... → xcrun devicectl install ...")


if __name__ == "__main__":
    main()
