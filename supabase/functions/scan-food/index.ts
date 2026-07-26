// Supabase Edge Function: scan-food
// Deploy: supabase functions deploy scan-food
// Secrets needed:
//   supabase secrets set GEMINI_API_KEY=your_key
//   supabase secrets set USDA_API_KEY=your_key

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DAILY_SCAN_LIMIT = 5;

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
      },
    });
  }

  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json",
  };

  try {
    const { image_url, user_id } = await req.json();

    if (!image_url || !user_id) {
      return new Response(
        JSON.stringify({ status: "error", message: "Missing image_url or user_id" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Initialize Supabase with service role key (bypasses RLS for cache writes)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 1: Check daily scan limit
    // ──────────────────────────────────────────────────────────────────────────
    const today = new Date().toISOString().split("T")[0];

    const { data: usageRow } = await supabase
      .from("scan_usage")
      .select("scan_count")
      .eq("user_id", user_id)
      .eq("scan_date", today)
      .maybeSingle();

    const currentCount = usageRow?.scan_count ?? 0;

    if (currentCount >= DAILY_SCAN_LIMIT) {
      return new Response(
        JSON.stringify({
          status: "limit_reached",
          message: `Daily AI scan limit of ${DAILY_SCAN_LIMIT} reached. Resets at midnight.`,
        }),
        { headers: corsHeaders }
      );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 2: Call Gemini to identify food
    // ──────────────────────────────────────────────────────────────────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY")!;
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`;

    const geminiBody = {
      contents: [
        {
          parts: [
            {
              inline_data: {
                mime_type: "image/jpeg",
                // We pass URL to Gemini via a fileData part (Gemini can fetch URLs)
                // Use fileData for URL-based images
              },
            },
            {
              text: `You are a nutrition expert. Analyze this food image and identify each distinct food item visible.
For each item, estimate the portion weight in grams based on visual cues.
Return ONLY a valid JSON array, no explanation, no markdown:
[{"food_name": "chicken breast", "grams": 150}, {"food_name": "white rice", "grams": 200}]
Be specific. If it is a mixed dish, list the primary components.`,
            },
          ],
        },
      ],
      generation_config: { temperature: 0.1, max_output_tokens: 512 },
    };

    // Use Gemini's URL-based image input
    const geminiBodyWithUrl = {
      contents: [
        {
          parts: [
            {
              file_data: {
                mime_type: "image/jpeg",
                file_uri: image_url,
              },
            },
            {
              text: `You are a nutrition expert. Analyze this food image and identify each distinct food item visible.
For each item, estimate the portion weight in grams based on visual cues (plate size, utensils as reference).
Return ONLY a valid JSON array — no explanation, no markdown, no code block:
[{"food_name": "grilled chicken breast", "grams": 150}, {"food_name": "steamed broccoli", "grams": 80}]
Combine into a single dish name if it's a plated meal. Estimate realistically.`,
            },
          ],
        },
      ],
      generation_config: { temperature: 0.1, max_output_tokens: 512 },
    };

    const geminiResp = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiBodyWithUrl),
    });

    if (!geminiResp.ok) {
      const errText = await geminiResp.text();
      throw new Error(`Gemini API error: ${geminiResp.status} — ${errText}`);
    }

    const geminiData = await geminiResp.json();
    const rawText: string =
      geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";

    // Parse Gemini JSON output
    let foodItems: { food_name: string; grams: number }[] = [];
    try {
      const cleaned = rawText.trim().replace(/```json|```/g, "").trim();
      foodItems = JSON.parse(cleaned);
      if (!Array.isArray(foodItems)) foodItems = [];
    } catch {
      // Fallback: treat the whole response as a single item
      foodItems = [{ food_name: rawText.slice(0, 60), grams: 200 }];
    }

    if (foodItems.length === 0) {
      foodItems = [{ food_name: "Mixed meal", grams: 300 }];
    }

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 3: Check food cache for any of the identified items
    // ──────────────────────────────────────────────────────────────────────────
    const primaryItem = foodItems[0];
    const cacheQuery = primaryItem.food_name.split(" ").slice(0, 2).join(" ");

    const { data: cacheHit } = await supabase
      .from("food_cache")
      .select("*")
      .ilike("food_name", `%${cacheQuery}%`)
      .maybeSingle();

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 4: Fetch nutrition data (cache or USDA/OFF)
    // ──────────────────────────────────────────────────────────────────────────
    let nutritionPer100g: Record<string, number>;
    let dataSource = "gemini+usda";
    let combinedFoodName = foodItems.map((f) => f.food_name).join(" & ");
    const totalGrams = foodItems.reduce((sum, f) => sum + f.grams, 0);

    if (cacheHit) {
      // Use cached data
      nutritionPer100g = {
        calories: cacheHit.calories_per_100g ?? 0,
        protein: cacheHit.protein_per_100g ?? 0,
        carbs: cacheHit.carbs_per_100g ?? 0,
        fat: cacheHit.fat_per_100g ?? 0,
        vitamin_a: cacheHit.vitamin_a ?? 0,
        vitamin_c: cacheHit.vitamin_c ?? 0,
        vitamin_d: cacheHit.vitamin_d ?? 0,
        iron: cacheHit.iron ?? 0,
        calcium: cacheHit.calcium ?? 0,
        potassium: cacheHit.potassium ?? 0,
      };
      combinedFoodName = cacheHit.food_name;
      dataSource = "cache";
    } else {
      // Fetch from USDA for each item and aggregate weighted average
      nutritionPer100g = await fetchWeightedNutrition(foodItems);
      dataSource = "gemini+usda";

      // Save to cache (primary item only)
      const scale = totalGrams > 0 ? 100 / totalGrams : 1;
      await supabase.from("food_cache").insert({
        food_name: combinedFoodName,
        calories_per_100g: nutritionPer100g.calories * scale,
        protein_per_100g: nutritionPer100g.protein * scale,
        carbs_per_100g: nutritionPer100g.carbs * scale,
        fat_per_100g: nutritionPer100g.fat * scale,
        vitamin_a: nutritionPer100g.vitamin_a,
        vitamin_c: nutritionPer100g.vitamin_c,
        vitamin_d: nutritionPer100g.vitamin_d,
        iron: nutritionPer100g.iron,
        calcium: nutritionPer100g.calcium,
        potassium: nutritionPer100g.potassium,
        source: "usda",
      });
    }

    // Scale nutrition to actual portion grams
    const scale = totalGrams / 100;
    const finalNutrition = {
      calories: Math.round(nutritionPer100g.calories * scale),
      protein: Math.round(nutritionPer100g.protein * scale),
      carbs: Math.round(nutritionPer100g.carbs * scale),
      fat: Math.round(nutritionPer100g.fat * scale),
      vitamin_a: Math.round(nutritionPer100g.vitamin_a * scale),
      vitamin_c: Math.round(nutritionPer100g.vitamin_c * scale),
      vitamin_d: parseFloat((nutritionPer100g.vitamin_d * scale).toFixed(1)),
      iron: parseFloat((nutritionPer100g.iron * scale).toFixed(1)),
      calcium: Math.round(nutritionPer100g.calcium * scale),
      potassium: Math.round(nutritionPer100g.potassium * scale),
    };

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 5: Increment scan usage
    // ──────────────────────────────────────────────────────────────────────────
    await supabase.from("scan_usage").upsert(
      { user_id, scan_date: today, scan_count: currentCount + 1 },
      { onConflict: "user_id,scan_date" }
    );

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 6: Return result
    // ──────────────────────────────────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        status: "success",
        food_name: combinedFoodName,
        portion_grams: totalGrams,
        ...finalNutrition,
        source: dataSource,
        scans_remaining: DAILY_SCAN_LIMIT - (currentCount + 1),
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("scan-food error:", error);
    return new Response(
      JSON.stringify({
        status: "error",
        message: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500, headers: corsHeaders }
    );
  }
});

// ─── USDA nutrition fetch with Open Food Facts fallback ────────────────────────

async function fetchWeightedNutrition(
  items: { food_name: string; grams: number }[]
): Promise<Record<string, number>> {
  const usdaKey = Deno.env.get("USDA_API_KEY") ?? "DEMO_KEY";
  const aggregated: Record<string, number> = {
    calories: 0, protein: 0, carbs: 0, fat: 0,
    vitamin_a: 0, vitamin_c: 0, vitamin_d: 0,
    iron: 0, calcium: 0, potassium: 0,
  };

  for (const item of items) {
    const per100 = await queryUSDA(item.food_name, usdaKey) ??
                   await queryOpenFoodFacts(item.food_name) ??
                   estimateFallback(item.food_name);

    const scale = item.grams / 100;
    for (const key of Object.keys(aggregated)) {
      aggregated[key] += (per100[key] ?? 0) * scale;
    }
  }

  return aggregated;
}

async function queryUSDA(
  query: string,
  apiKey: string
): Promise<Record<string, number> | null> {
  try {
    const url = new URL("https://api.nal.usda.gov/fdc/v1/foods/search");
    url.searchParams.set("query", query);
    url.searchParams.set("pageSize", "1");
    url.searchParams.set("api_key", apiKey);

    const resp = await fetch(url.toString());
    if (!resp.ok) return null;
    const data = await resp.json();
    const foods = data.foods ?? [];
    if (foods.length === 0) return null;

    const nutrients: { nutrientName: string; unitName: string; value: number }[] =
      foods[0].foodNutrients ?? [];

    const result: Record<string, number> = {
      calories: 0, protein: 0, carbs: 0, fat: 0,
      vitamin_a: 0, vitamin_c: 0, vitamin_d: 0,
      iron: 0, calcium: 0, potassium: 0,
    };

    for (const n of nutrients) {
      const name = n.nutrientName.toLowerCase();
      const val = n.value ?? 0;
      if (name.includes("energy") && n.unitName.toLowerCase() === "kcal") result.calories = val;
      else if (name === "protein") result.protein = val;
      else if (name.includes("carbohydrate")) result.carbs = val;
      else if (name.includes("lipid") || name === "fat") result.fat = val;
      else if (name.includes("vitamin a")) result.vitamin_a = val;
      else if (name.includes("vitamin c")) result.vitamin_c = val;
      else if (name.includes("vitamin d")) result.vitamin_d = val;
      else if (name.includes("calcium")) result.calcium = val;
      else if (name.includes("iron")) result.iron = val;
      else if (name.includes("potassium")) result.potassium = val;
    }

    if (result.calories === 0) {
      result.calories = result.protein * 4 + result.carbs * 4 + result.fat * 9;
    }

    return result;
  } catch {
    return null;
  }
}

async function queryOpenFoodFacts(
  query: string
): Promise<Record<string, number> | null> {
  try {
    const url = new URL("https://world.openfoodfacts.org/cgi/search.pl");
    url.searchParams.set("search_terms", query);
    url.searchParams.set("json", "true");
    url.searchParams.set("page_size", "1");

    const resp = await fetch(url.toString());
    if (!resp.ok) return null;
    const data = await resp.json();
    const products = data.products ?? [];
    if (products.length === 0) return null;

    const n = products[0].nutriments ?? {};
    return {
      calories: n["energy-kcal_100g"] ?? 0,
      protein: n["proteins_100g"] ?? 0,
      carbs: n["carbohydrates_100g"] ?? 0,
      fat: n["fat_100g"] ?? 0,
      vitamin_a: (n["vitamin-a_100g"] ?? 0) * 1000,
      vitamin_c: (n["vitamin-c_100g"] ?? 0) * 1000,
      vitamin_d: (n["vitamin-d_100g"] ?? 0) * 1000,
      calcium: (n["calcium_100g"] ?? 0) * 1000,
      iron: (n["iron_100g"] ?? 0) * 1000,
      potassium: (n["potassium_100g"] ?? 0) * 1000,
    };
  } catch {
    return null;
  }
}

// Generic nutritional fallback based on food category keywords
function estimateFallback(name: string): Record<string, number> {
  const q = name.toLowerCase();
  if (q.includes("chicken") || q.includes("turkey"))
    return { calories: 165, protein: 31, carbs: 0, fat: 3.6, vitamin_a: 10, vitamin_c: 0, vitamin_d: 0.1, calcium: 15, iron: 1.0, potassium: 256 };
  if (q.includes("rice"))
    return { calories: 130, protein: 2.7, carbs: 28, fat: 0.3, vitamin_a: 0, vitamin_c: 0, vitamin_d: 0, calcium: 10, iron: 1.2, potassium: 35 };
  if (q.includes("salmon") || q.includes("fish"))
    return { calories: 208, protein: 22, carbs: 0, fat: 13, vitamin_a: 40, vitamin_c: 0, vitamin_d: 12, calcium: 12, iron: 0.8, potassium: 363 };
  if (q.includes("salad") || q.includes("vegetable"))
    return { calories: 50, protein: 2, carbs: 7, fat: 0.5, vitamin_a: 300, vitamin_c: 30, vitamin_d: 0, calcium: 50, iron: 1.0, potassium: 200 };
  if (q.includes("egg"))
    return { calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5, vitamin_a: 160, vitamin_c: 0, vitamin_d: 2.0, calcium: 56, iron: 1.8, potassium: 138 };
  return { calories: 200, protein: 8, carbs: 25, fat: 8, vitamin_a: 50, vitamin_c: 10, vitamin_d: 0.5, calcium: 50, iron: 1.5, potassium: 200 };
}
