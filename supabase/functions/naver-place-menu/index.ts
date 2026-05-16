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
  const match = link.match(/place\/(\d+)/);
  return match?.[1] ?? null;
}

function stripHtml(str: string): string {
  return str.replace(/<[^>]*>/g, "").trim();
}

function parsePrice(val: unknown): number | null {
  if (val == null) return null;
  const s = String(val).replace(/[^0-9]/g, "");
  const n = parseInt(s, 10);
  return isNaN(n) || n <= 0 ? null : n;
}

// Naver Place API 응답에서 메뉴 목록 추출 (여러 구조 대응)
function parseMenus(data: unknown): NaverMenuItem[] {
  try {
    const d = data as Record<string, unknown>;
    const result = d?.result as Record<string, unknown> | undefined;

    // 다양한 응답 구조 시도
    const raw: unknown[] =
      (result?.place as any)?.menus ??
      (result?.restaurant as any)?.menus ??
      (result as any)?.menus ??
      (d as any)?.menus ??
      [];

    if (!Array.isArray(raw) || raw.length === 0) return [];

    return raw
      .filter((m: any) => typeof m?.name === "string" && m.name.length > 0)
      .map((m: any) => ({
        name: stripHtml(m.name),
        price: parsePrice(m.price ?? m.priceContent ?? m.discountedPrice),
        category: stripHtml(m.category ?? m.menuCategory ?? ""),
      }))
      .filter((m) => m.name.length > 0);
  } catch {
    return [];
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  try {
    const { query, lat, lng } = await req.json();

    if (!query || typeof query !== "string") {
      return new Response(
        JSON.stringify({ error: "query is required", menus: [] }),
        { status: 400, headers: jsonHeaders }
      );
    }

    const clientId = Deno.env.get("NAVER_CLIENT_ID");
    const clientSecret = Deno.env.get("NAVER_CLIENT_SECRET");

    if (!clientId || !clientSecret) {
      return new Response(
        JSON.stringify({ error: "Naver credentials not configured", menus: [] }),
        { status: 500, headers: jsonHeaders }
      );
    }

    // ── Step 1: 네이버 Local Search로 Place ID 추출 ──────────────────
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
      return new Response(
        JSON.stringify({ menus: [], placeId: null }),
        { headers: jsonHeaders }
      );
    }

    const searchData = await searchRes.json();
    const items: any[] = searchData?.items ?? [];

    if (items.length === 0) {
      return new Response(
        JSON.stringify({ menus: [], placeId: null }),
        { headers: jsonHeaders }
      );
    }

    // 좌표가 있으면 가장 가까운 결과, 아니면 첫 번째
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

    const placeId = extractPlaceId(bestItem?.link ?? "");
    if (!placeId) {
      return new Response(
        JSON.stringify({ menus: [], placeId: null }),
        { headers: jsonHeaders }
      );
    }

    // ── Step 2: 네이버 Place 상세 API로 메뉴 조회 ───────────────────
    const placeUrl =
      `https://place.map.naver.com/place/api/detail` +
      `?placeType=S&businessId=${placeId}&lang=ko`;

    const placeRes = await fetch(placeUrl, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
          "AppleWebKit/537.36 (KHTML, like Gecko) " +
          "Chrome/124.0.0.0 Safari/537.36",
        "Referer": "https://map.naver.com/",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "ko-KR,ko;q=0.9",
      },
    });

    if (!placeRes.ok) {
      return new Response(
        JSON.stringify({ menus: [], placeId }),
        { headers: jsonHeaders }
      );
    }

    const placeData = await placeRes.json();
    const menus = parseMenus(placeData);

    return new Response(
      JSON.stringify({ menus, placeId }),
      { headers: jsonHeaders }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e), menus: [] }),
      { status: 500, headers: jsonHeaders }
    );
  }
});
