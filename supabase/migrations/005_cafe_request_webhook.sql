-- Database Webhook: cafe_requests INSERT → notify-cafe-request Edge Function
-- Uses pg_net extension for HTTP calls from triggers

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.notify_cafe_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://rqlfyumzmpmhupjtroid.supabase.co/functions/v1/notify-cafe-request',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxbGZ5dW16bXBtaHVwanRyb2lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMzY4MjIsImV4cCI6MjA4NzcxMjgyMn0.PiivIIa-mjgOTLOH_suaAyllGQZRb8p-cYLi5gHpPXk'
    ),
    body    := jsonb_build_object(
      'type',   'INSERT',
      'table',  'cafe_requests',
      'record', row_to_json(NEW)
    )
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_cafe_request_inserted
  AFTER INSERT ON public.cafe_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_cafe_request();
