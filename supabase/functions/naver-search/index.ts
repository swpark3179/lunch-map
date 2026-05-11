import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, "");
}

function extractPlaceId(link: string): string | null {
  const match = link.match(/place[/](\d+)/);
  return match ? match[1] : null;
}

interface MenuItem {
  name: string;
  price: string;
  description: string;
  imageUrl: string;
}

async function fetchNaverMapMenus(placeId: string): Promise<MenuItem[]> {
  try {
    const res = await fetch(
      `https://map.naver.com/v5/api/sites/summary/${placeId}?lang=ko`,
      {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": "https://map.naver.com/",
          "Accept": "application/json",
        },
      }
    );

    if (!res.ok) return [];

    const data = await res.json();

    // 메뉴 데이터 위치: menuInfo.menus 또는 menus 배열
    const rawMenus: unknown[] =
      data?.menuInfo?.menus ?? data?.menus ?? [];

    return rawMenus.map((m: unknown) => {
      const menu = m as Record<string, unknown>;
      return {
        name: String(menu.name ?? ""),
        price: menu.price != null ? String(menu.price) : "",
        description: String(menu.description ?? ""),
        imageUrl: String(menu.images?.[0] ?? menu.imageUrl ?? ""),
      };
    }).filter((m) => m.name !== "");
  } catch {
    return [];
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { query } = await req.json();
    if (!query) {
      return new Response(JSON.stringify({ error: "query is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const clientId = Deno.env.get("NAVER_CLIENT_ID");
    const clientSecret = Deno.env.get("NAVER_CLIENT_SECRET");

    if (!clientId || !clientSecret) {
      return new Response(
        JSON.stringify({ error: "Naver API credentials not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const searchUrl = `https://openapi.naver.com/v1/search/local.json?query=${encodeURIComponent(query)}&display=5&sort=comment`;

    const naverRes = await fetch(searchUrl, {
      headers: {
        "X-Naver-Client-Id": clientId,
        "X-Naver-Client-Secret": clientSecret,
      },
    });

    if (!naverRes.ok) {
      return new Response(
        JSON.stringify({ error: `Naver API error: ${naverRes.status}` }),
        {
          status: naverRes.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const searchData = await naverRes.json();
    const items: Record<string, unknown>[] = searchData.items ?? [];

    // 이름이 가장 잘 매칭되는 항목 선택
    const nameLower = query.split(" ").slice(1).join(" ").toLowerCase(); // '거제 식당명' → '식당명'
    let best: Record<string, unknown> | null = null;
    for (const item of items) {
      const title = stripHtml(String(item.title ?? "")).toLowerCase();
      if (title.includes(nameLower) || nameLower.includes(title)) {
        best = item;
        break;
      }
    }
    best ??= items[0] ?? null;

    if (!best) {
      return new Response(JSON.stringify({ items: [] }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 장소 ID로 네이버 Map 메뉴 조회
    const placeId = extractPlaceId(String(best.link ?? ""));
    let menus: MenuItem[] = [];
    if (placeId) {
      menus = await fetchNaverMapMenus(placeId);
    }

    const result = {
      title: stripHtml(String(best.title ?? "")),
      category: String(best.category ?? ""),
      description: String(best.description ?? ""),
      telephone: String(best.telephone ?? ""),
      roadAddress: String(best.roadAddress ?? ""),
      link: String(best.link ?? ""),
      placeId,
      menus,
    };

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
