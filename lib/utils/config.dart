class AppConfig {
  static const String supabaseUrl = "https://bybtvulwbvhhfketahlp.supabase.co"; // Add your Supabase URL here
  static const String supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5YnR2dWx3YnZoaGZrZXRhaGxwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1NTgyOTksImV4cCI6MjA5MDEzNDI5OX0.9rVAvKxmsb8ygC1HKm1MwselVyXsXaqtmxiGIJVpJok"; // Add your Supabase Anon Key here
  
  static bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
