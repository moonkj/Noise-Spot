// Supabase Edge Function: notify-cafe-request
// Triggered by Database Webhook when a new row is inserted into cafe_requests.
//
// Setup:
// 1. Deploy: supabase functions deploy notify-cafe-request
// 2. Set secrets:
//    supabase secrets set RESEND_API_KEY=re_xxxx
//    supabase secrets set ADMIN_EMAIL=your@email.com
// 3. Supabase 대시보드 → Database → Webhooks → "Create a new hook"
//    Table: cafe_requests / Event: INSERT
//    URL: https://<project-ref>.supabase.co/functions/v1/notify-cafe-request
//    Add header: Authorization: Bearer <service_role_key>

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    const body = await req.json();
    // Database Webhook sends { type, table, record, old_record }
    const record = body.record;
    if (!record) return new Response("no record", { status: 400 });

    const adminEmail = Deno.env.get("ADMIN_EMAIL") ?? "";
    const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";

    if (!adminEmail || !resendApiKey) {
      console.error("Missing ADMIN_EMAIL or RESEND_API_KEY secret");
      return new Response("config error", { status: 500 });
    }

    const cafeName = record.cafe_name ?? "(이름 없음)";
    const address = record.address ?? "-";
    const note = record.note ?? "-";
    const createdAt = record.created_at ?? "";

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: "Cafe Vibe <onboarding@resend.dev>",
        to: [adminEmail],
        subject: `[Cafe Vibe] 새 카페 추가 요청: ${cafeName}`,
        html: `
          <h2>새 카페 추가 요청이 접수되었습니다</h2>
          <table style="border-collapse:collapse;width:100%;max-width:500px">
            <tr><td style="padding:8px;border:1px solid #eee;font-weight:bold">카페 이름</td><td style="padding:8px;border:1px solid #eee">${cafeName}</td></tr>
            <tr><td style="padding:8px;border:1px solid #eee;font-weight:bold">주소</td><td style="padding:8px;border:1px solid #eee">${address}</td></tr>
            <tr><td style="padding:8px;border:1px solid #eee;font-weight:bold">메모</td><td style="padding:8px;border:1px solid #eee">${note}</td></tr>
            <tr><td style="padding:8px;border:1px solid #eee;font-weight:bold">접수 시각</td><td style="padding:8px;border:1px solid #eee">${createdAt}</td></tr>
          </table>
          <p style="margin-top:16px">앱 설정 → 관리자 → 카페 추가 요청 목록에서 승인/거절할 수 있습니다.</p>
        `,
      }),
    });

    const data = await res.json();
    console.log("Resend response:", JSON.stringify(data));
    return new Response(JSON.stringify(data), { status: res.ok ? 200 : 500 });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
