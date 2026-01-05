-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.answers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL,
  author_id uuid NOT NULL,
  body text NOT NULL,
  evidence USER-DEFINED DEFAULT 'n_a'::evidence_level,
  sources jsonb DEFAULT '[]'::jsonb,
  is_accepted boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT answers_pkey PRIMARY KEY (id),
  CONSTRAINT answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id),
  CONSTRAINT answers_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.badges (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT badges_pkey PRIMARY KEY (id)
);
CREATE TABLE public.budget_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  nickname text,
  encrypted boolean NOT NULL DEFAULT false,
  data jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT budget_snapshots_pkey PRIMARY KEY (id),
  CONSTRAINT budget_snapshots_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity USER-DEFINED NOT NULL,
  entity_id uuid NOT NULL,
  author_id uuid NOT NULL,
  body text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT comments_pkey PRIMARY KEY (id),
  CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.content (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  type USER-DEFINED NOT NULL,
  title text NOT NULL,
  summary text,
  body text,
  evidence USER-DEFINED DEFAULT 'n_a'::evidence_level,
  visibility USER-DEFINED DEFAULT 'public'::visibility,
  sources jsonb DEFAULT '[]'::jsonb,
  region text,
  language text DEFAULT 'tr'::text,
  version integer DEFAULT 1,
  is_published boolean DEFAULT true,
  tsv tsvector,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT content_pkey PRIMARY KEY (id),
  CONSTRAINT content_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.content_tags (
  content_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  CONSTRAINT content_tags_pkey PRIMARY KEY (content_id, tag_id),
  CONSTRAINT content_tags_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.content(id),
  CONSTRAINT content_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id)
);
CREATE TABLE public.discussion_topics (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creator_id uuid NOT NULL,
  title text NOT NULL,
  body text,
  tags ARRAY DEFAULT ARRAY[]::text[],
  visibility USER-DEFINED DEFAULT 'public'::visibility,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT discussion_topics_pkey PRIMARY KEY (id),
  CONSTRAINT discussion_topics_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.engagements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL,
  practitioner_id uuid NOT NULL,
  requester_id uuid NOT NULL,
  state text NOT NULL DEFAULT 'accepted'::text CHECK (state = ANY (ARRAY['accepted'::text, 'scheduled'::text, 'completed'::text, 'cancelled'::text])),
  scheduled_at timestamp with time zone,
  completed_at timestamp with time zone,
  cancellation_reason text,
  audit jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  slot_id uuid,
  CONSTRAINT engagements_pkey PRIMARY KEY (id),
  CONSTRAINT engagements_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.offer_requests(id),
  CONSTRAINT engagements_practitioner_id_fkey FOREIGN KEY (practitioner_id) REFERENCES public.profiles(id),
  CONSTRAINT engagements_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.profiles(id),
  CONSTRAINT engagements_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.offer_slots(id)
);
CREATE TABLE public.entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  body text NOT NULL,
  images ARRAY DEFAULT ARRAY[]::text[],
  anonymous boolean DEFAULT false,
  visibility USER-DEFINED DEFAULT 'public'::visibility,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT entries_pkey PRIMARY KEY (id),
  CONSTRAINT entries_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.event_enrollments (
  event_id uuid NOT NULL,
  user_id uuid NOT NULL,
  status text DEFAULT 'going'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT event_enrollments_pkey PRIMARY KEY (event_id, user_id),
  CONSTRAINT event_enrollments_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT event_enrollments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  host_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  type USER-DEFINED NOT NULL CHECK (type = ANY (ARRAY['course'::content_type, 'webinar'::content_type, 'workshop'::content_type])),
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone,
  location text,
  capacity integer,
  tags ARRAY DEFAULT ARRAY[]::text[],
  visibility USER-DEFINED DEFAULT 'public'::visibility,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT events_pkey PRIMARY KEY (id),
  CONSTRAINT events_host_id_fkey FOREIGN KEY (host_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.forum_posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  topic_id uuid NOT NULL,
  author_id uuid NOT NULL,
  body text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT forum_posts_pkey PRIMARY KEY (id),
  CONSTRAINT forum_posts_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.discussion_topics(id),
  CONSTRAINT forum_posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.mentorship (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL,
  mentee_id uuid NOT NULL,
  topics ARRAY DEFAULT ARRAY[]::text[],
  status text DEFAULT 'pending'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT mentorship_pkey PRIMARY KEY (id),
  CONSTRAINT mentorship_mentor_id_fkey FOREIGN KEY (mentor_id) REFERENCES public.profiles(id),
  CONSTRAINT mentorship_mentee_id_fkey FOREIGN KEY (mentee_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  payload jsonb NOT NULL,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.offer_gifts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL,
  sponsor_id uuid NOT NULL,
  units integer NOT NULL DEFAULT 1,
  units_remaining integer NOT NULL DEFAULT 1,
  note text,
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'cancelled'::text, 'exhausted'::text, 'expired'::text])),
  valid_until timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  used integer NOT NULL DEFAULT 0,
  CONSTRAINT offer_gifts_pkey PRIMARY KEY (id),
  CONSTRAINT offer_gifts_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id),
  CONSTRAINT offer_gifts_sponsor_id_fkey FOREIGN KEY (sponsor_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.offer_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL,
  requester_id uuid NOT NULL,
  message text NOT NULL,
  preferred_times jsonb DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'accepted'::text, 'declined'::text, 'withdrawn'::text])),
  decline_reason text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT offer_requests_pkey PRIMARY KEY (id),
  CONSTRAINT offer_requests_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id),
  CONSTRAINT offer_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.offer_reviews (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL,
  engagement_id uuid NOT NULL UNIQUE,
  reviewer_id uuid NOT NULL,
  stars integer NOT NULL CHECK (stars >= 1 AND stars <= 5),
  comment text NOT NULL CHECK (length(TRIM(BOTH FROM comment)) > 0),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT offer_reviews_pkey PRIMARY KEY (id),
  CONSTRAINT offer_reviews_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id),
  CONSTRAINT offer_reviews_engagement_id_fkey FOREIGN KEY (engagement_id) REFERENCES public.engagements(id),
  CONSTRAINT offer_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.offer_slots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL,
  start_at timestamp with time zone NOT NULL,
  end_at timestamp with time zone NOT NULL,
  capacity integer NOT NULL DEFAULT 1 CHECK (capacity > 0),
  reserved integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'full'::text, 'cancelled'::text])),
  note text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT offer_slots_pkey PRIMARY KEY (id),
  CONSTRAINT offer_slots_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id)
);
CREATE TABLE public.offers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['legal'::text, 'psychological'::text, 'career'::text, 'it'::text, 'finance'::text, 'other'::text])),
  title text NOT NULL,
  description text,
  tags ARRAY DEFAULT '{}'::text[],
  fee_type text NOT NULL CHECK (fee_type = ANY (ARRAY['free'::text, 'paid'::text, 'sliding'::text])),
  languages ARRAY DEFAULT '{}'::text[],
  region text,
  availability jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT offers_pkey PRIMARY KEY (id),
  CONSTRAINT offers_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text UNIQUE,
  full_name text,
  avatar_url text,
  bio text,
  languages ARRAY DEFAULT ARRAY[]::text[],
  timezone text DEFAULT 'America/Los_Angeles'::text,
  country text,
  region text,
  roles ARRAY DEFAULT ARRAY['user'::role_kind],
  reputation integer DEFAULT 0,
  offers ARRAY DEFAULT ARRAY[]::text[],
  needs ARRAY DEFAULT ARRAY[]::text[],
  anon_allowed boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  display_name text,
  specialties ARRAY DEFAULT '{}'::text[],
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.project_applications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid,
  applicant_id uuid,
  message text,
  status text DEFAULT 'pending'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT project_applications_pkey PRIMARY KEY (id),
  CONSTRAINT project_applications_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id),
  CONSTRAINT project_applications_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.project_members (
  project_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text DEFAULT 'member'::text,
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT project_members_pkey PRIMARY KEY (project_id, user_id),
  CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id),
  CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.projects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  needed_roles ARRAY DEFAULT ARRAY[]::text[],
  region text,
  tags ARRAY DEFAULT ARRAY[]::text[],
  visibility USER-DEFINED DEFAULT 'public'::visibility,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT projects_pkey PRIMARY KEY (id),
  CONSTRAINT projects_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.questions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  asker_id uuid NOT NULL,
  title text NOT NULL,
  body text,
  tags ARRAY DEFAULT ARRAY[]::text[],
  visibility USER-DEFINED DEFAULT 'public'::visibility,
  accepted_answer_id uuid,
  tsv tsvector,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  sources jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT questions_pkey PRIMARY KEY (id),
  CONSTRAINT questions_asker_id_fkey FOREIGN KEY (asker_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.ratings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity USER-DEFINED NOT NULL,
  entity_id uuid NOT NULL,
  rater_id uuid NOT NULL,
  stars integer NOT NULL CHECK (stars >= 1 AND stars <= 5),
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ratings_pkey PRIMARY KEY (id),
  CONSTRAINT ratings_rater_id_fkey FOREIGN KEY (rater_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reporter_id uuid,
  entity USER-DEFINED NOT NULL,
  entity_id uuid NOT NULL,
  reason text,
  severity integer DEFAULT 1,
  state text DEFAULT 'open'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT reports_pkey PRIMARY KEY (id),
  CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.rfh (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL,
  title text NOT NULL,
  body text,
  tags ARRAY DEFAULT ARRAY[]::text[],
  sensitivity USER-DEFINED DEFAULT 'normal'::sensitivity,
  anonymous boolean DEFAULT false,
  status USER-DEFINED DEFAULT 'open'::rfh_status,
  region text,
  language text DEFAULT 'tr'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT rfh_pkey PRIMARY KEY (id),
  CONSTRAINT rfh_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.rfh_matches (
  rfh_id uuid NOT NULL,
  helper_id uuid NOT NULL,
  score numeric DEFAULT 0,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT rfh_matches_pkey PRIMARY KEY (rfh_id, helper_id),
  CONSTRAINT rfh_matches_rfh_id_fkey FOREIGN KEY (rfh_id) REFERENCES public.rfh(id),
  CONSTRAINT rfh_matches_helper_id_fkey FOREIGN KEY (helper_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.tags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  label text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT tags_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_badges (
  user_id uuid NOT NULL,
  badge_id uuid NOT NULL,
  granted_by uuid,
  granted_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_badges_pkey PRIMARY KEY (user_id, badge_id),
  CONSTRAINT user_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT user_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.badges(id),
  CONSTRAINT user_badges_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.views (
  entity USER-DEFINED NOT NULL,
  entity_id uuid NOT NULL,
  viewer_id uuid,
  viewed_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.wallet_accounts (
  user_id uuid NOT NULL,
  balance integer NOT NULL DEFAULT 100,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT wallet_accounts_pkey PRIMARY KEY (user_id),
  CONSTRAINT wallet_accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.wallet_txns (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  from_user uuid,
  to_user uuid,
  amount integer NOT NULL CHECK (amount > 0),
  reason text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT wallet_txns_pkey PRIMARY KEY (id),
  CONSTRAINT wallet_txns_from_user_fkey FOREIGN KEY (from_user) REFERENCES public.profiles(id),
  CONSTRAINT wallet_txns_to_user_fkey FOREIGN KEY (to_user) REFERENCES public.profiles(id)
);