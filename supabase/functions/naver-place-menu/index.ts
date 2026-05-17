import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NaverMenuItem {
  name: string;
  price: number | null;
  category: string;
}

function extractPlaceId(link: string): string | null {
  if (!link) return null;
  const patterns = [
    /\/(?:place|restaurant|entry|cafe|hairshop|beautysalon)\/(\d+)/,
    /[?&](?:placeId|id|businessId)=(\d+)/,
    /place\.map\.naver\.com\/(\d+)/,
    /m\.place\.naver\.com\/[^/]+\/(\d+)/,
  ];
  for (const re of patterns) {
    const m = link.match(re);
    if (m?.[1]) return m[1];
  }
  return null;
}

function stripHtml(str: string): string {
  return String(str).replace(/<[^>]*>/g, "").trim();
}

function parsePrice(val: unknown): number | null {
  if (val == null) return null;
  const s = String(val).replace(/[^0-9]/g, "");
  if (s.length === 0) return null;
  const n = parseInt(s, 10);
  return isNaN(n) || n <= 0 ? null : n;
}

// HTML 안에 박혀있는 Next.js / Apollo 상태 JSON 을 추출한다.
function extractEmbeddedJson(html: string): unknown[] {
  const states: unknown[] = [];

  // 1) <script id="__NEXT_DATA__" type="application/json">{...}</script>
  const nextMatch = html.match(
    /<script[^>]*id=["']__NEXT_DATA__["'][^>]*>([\s\S]*?)<\/script>/,
  );
  if (nextMatch?.[1]) {
    try {
      states.push(JSON.parse(nextMatch[1]));
    } catch {
      /* ignore */
    }
  }

  // 2) window.__APOLLO_STATE__ = {...};
  const apolloMatch = html.match(
    /__APOLLO_STATE__\s*=\s*(\{[\s\S]*?\})\s*;[\s\S]*?<\/script>/,
  );
  if (apolloMatch?.[1]) {
    try {
      states.push(JSON.parse(apolloMatch[1]));
    } catch {
      /* ignore */
    }
  }

  // 3) window.__PLACE_STATE__ = {...};
  const placeStateMatch = html.match(
    /__PLACE_STATE__\s*=\s*(\{[\s\S]*?\})\s*;[\s\S]*?<\/script>/,
  );
  if (placeStateMatch?.[1]) {
    try {
      states.push(JSON.parse(placeStateMatch[1]));
    } catch {
      /* ignore */
    }
  }

  return states;
}

// JSON 트리를 재귀로 훑어서 메뉴 아이템처럼 보이는 객체들을 모은다.
// 응답 스키마가 자주 바뀌므로, "name 문자열 + 가격성 필드"가 있는 객체를
// 휴리스틱하게 메뉴로 본다.
function collectMenuObjects(state: unknown): any[] {
  const found: any[] = [];
  const seen = new Set<unknown>();

  const isMenuLike = (o: any): boolean => {
    if (!o || typeof o !== "object" || Array.isArray(o)) return false;
    if (typeof o.name !== "string" || o.name.trim().length === 0) return false;
    if (o.name.length > 80) return false; // 리뷰/설명 등 제외
    const hasPriceField =
      "price" in o ||
      "priceContent" in o ||
      "discountedPrice" in o ||
      "menuPrice" in o;
    if (!hasPriceField) return false;
    // 가격이 비어있는 메뉴도 가능하므로 필드 존재만 확인
    return true;
  };

  const walk = (node: any) => {
    if (node == null) return;
    if (typeof node !== "object") return;
    if (seen.has(node)) return;
    seen.add(node);

    if (Array.isArray(node)) {
      for (const child of node) walk(child);
      return;
    }

    if (isMenuLike(node)) {
      found.push(node);
    }
    for (const key of Object.keys(node)) {
      walk((node as any)[key]);
    }
  };

  walk(state);
  return found;
}

function dedupeMenus(items: NaverMenuItem[]): NaverMenuItem[] {
  const seen = new Set<string>();
  const out: NaverMenuItem[] = [];
  for (const m of items) {
    const key = `${m.name}__${m.price ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(m);
  }
  return out;
}

function toMenuItem(o: any): NaverMenuItem | null {
  const name = stripHtml(o.name ?? "");
  if (!name) return null;
  return {
    name,
    price: parsePrice(
      o.price ?? o.priceContent ?? o.discountedPrice ?? o.menuPrice,
    ),
    category: stripHtml(o.category ?? o.menuCategory ?? o.groupName ?? ""),
  };
}

const PLACE_CATEGORIES = ["restaurant", "cafe", "place"];

async function fetchMenusFromMobile(
  placeId: string,
): Promise<NaverMenuItem[]> {
  const headers = {
    "User-Agent":
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) " +
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 " +
      "Mobile/15E148 Safari/604.1",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
    "Referer": "https://m.place.naver.com/",
  };

  for (const category of PLACE_CATEGORIES) {
    const url =
      `https://m.place.naver.com/${category}/${placeId}/menu/list`;
    let res: Response;
    try {
      res = await fetch(url, { headers, redirect: "follow" });
    } catch {
      continue;
    }
    if (!res.ok) continue;

    const html = await res.text();
    if (!html || html.length < 500) continue;

    const states = extractEmbeddedJson(html);
    if (states.length === 0) continue;

    const menuObjects: any[] = [];
    for (const s of states) {
      menuObjects.push(...collectMenuObjects(s));
    }
    if (menuObjects.length === 0) continue;

    const items = menuObjects
      .map(toMenuItem)
      .filter((m): m is NaverMenuItem => m != null && m.name.length > 0);

    const deduped = dedupeMenus(items);
    if (deduped.length > 0) return deduped;
  }

  return [];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  try {
    const { query, lat, lng, naverLink, placeId: placeIdParam } =
      await req.json();

    const clientId = Deno.env.get("NAVER_CLIENT_ID");
    const clientSecret = Deno.env.get("NAVER_CLIENT_SECRET");

    // 클라이언트가 이미 연결된 POI 의 placeId 또는 naver_link 를 넘기면
    // Local Search 를 건너뛰고 곧장 상세 페이지를 스크레이프한다.
    let placeId: string | null =
      (typeof placeIdParam === "string" && placeIdParam.match(/^\d+$/)
        ? placeIdParam
        : null) ??
      (typeof naverLink === "string" ? extractPlaceId(naverLink) : null);

    if (!placeId) {
      if (!query || typeof query !== "string") {
        return new Response(
          JSON.stringify({ error: "query or placeId is required", menus: [] }),
          { status: 400, headers: jsonHeaders },
        );
      }

      if (!clientId || !clientSecret) {
        return new Response(
          JSON.stringify({
            error: "Naver credentials not configured",
            menus: [],
          }),
          { status: 500, headers: jsonHeaders },
        );
      }

      // ── Local Search 로 placeId 추출 (POI 미연결 식당용) ────────────
      const searchUrl =
        `https://openapi.naver.com/v1/search/local.json` +
        `?query=${encodeURIComponent("거제 " + query)}&display=5&sort=comment`;

      const searchRes = await fetch(searchUrl, {
        headers: {
          "X-Naver-Client-Id": clientId,
          "X-Naver-Client-Secret": clientSecret,
        },
      });

      if (!searchRes.ok) {
        return new Response(JSON.stringify({ menus: [], placeId: null }), {
          headers: jsonHeaders,
        });
      }

      const searchData = await searchRes.json();
      const items: any[] = searchData?.items ?? [];

      if (items.length === 0) {
        return new Response(JSON.stringify({ menus: [], placeId: null }), {
          headers: jsonHeaders,
        });
      }

      let bestItem = items[0];
      if (lat != null && lng != null && items.length > 1) {
        let minDist = Infinity;
        for (const item of items) {
          const iLat = parseInt(item.mapy ?? "0") / 1e7;
          const iLng = parseInt(item.mapx ?? "0") / 1e7;
          const dist = Math.pow(iLat - lat, 2) + Math.pow(iLng - lng, 2);
          if (dist < minDist) {
            minDist = dist;
            bestItem = item;
          }
        }
      }

      placeId = extractPlaceId(bestItem?.link ?? "");
      if (!placeId) {
        return new Response(JSON.stringify({ menus: [], placeId: null }), {
          headers: jsonHeaders,
        });
      }
    }

    // ── m.place.naver.com 메뉴 페이지에서 메뉴 추출 ─────────────────
    const menus = await fetchMenusFromMobile(placeId);

    return new Response(
      JSON.stringify({ menus, placeId }),
      { headers: jsonHeaders },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e), menus: [] }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
