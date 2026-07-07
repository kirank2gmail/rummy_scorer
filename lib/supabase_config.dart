// Fill these in from your own Supabase project -- this build environment
// has no network access to create a project or fetch these for you.
//
//   1. Create a project at https://supabase.com/dashboard
//   2. Go to Project Settings -> API. Copy:
//        - "Project URL"        -> supabaseUrl below
//        - "anon public" key    -> supabaseAnonKey below
//   3. Go to the SQL Editor, paste the contents of supabase/schema.sql
//      from this project's root, and run it once.
//   4. Go to Database -> Replication and confirm the `players`,
//      `config_defaults`, `games`, `rounds`, and `settlements` tables
//      are enabled for realtime (the schema script does this via
//      `alter publication supabase_realtime add table ...`, but it's
//      worth confirming in the dashboard).

class SupabaseConfig {
  static const supabaseUrl = 'https://diepngdhlqwitksmbkma.supabase.co/rest/v1/'; // e.g. https://xxxxxxxx.supabase.co
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRpZXBuZ2RobHF3aXRrc21ia21hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTY5OTUsImV4cCI6MjA5ODk5Mjk5NX0.Ksnjw2UOLhn9YjEKo77AWnFMZIxaRRdwz9xNeb7Aass';
}
