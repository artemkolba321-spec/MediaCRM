-- MediaCRM Database Schema
-- Supabase / PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users profile table (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON profiles FOR SELECT
  USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Platform channels
CREATE TABLE platform_channels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL,
  name TEXT NOT NULL,
  slug TEXT,
  description TEXT,
  avatar_url TEXT,
  platform_id TEXT,
  platform_token TEXT,
  api_key TEXT,
  status TEXT DEFAULT 'disconnected',
  last_sync_at TIMESTAMP WITH TIME ZONE,
  subscriber_count INTEGER DEFAULT 0,
  auto_sync BOOLEAN DEFAULT true,
  sync_interval_minutes INTEGER,
  error TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE platform_channels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own channels" ON platform_channels FOR ALL
  USING (auth.uid() = user_id);

-- Financial operations
CREATE TABLE financial_operations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  status TEXT DEFAULT 'completed',
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT DEFAULT 'RUB',
  original_amount TEXT,
  original_currency TEXT,
  category TEXT DEFAULT 'other',
  description TEXT,
  channel_id UUID REFERENCES platform_channels(id),
  partner_id UUID REFERENCES partners(id),
  advertiser_id UUID REFERENCES advertisers(id),
  publication_id UUID REFERENCES publications(id),
  date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE financial_operations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own finances" ON financial_operations FOR ALL
  USING (auth.uid() = user_id);

-- Partners
CREATE TABLE partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  company TEXT,
  contact_person TEXT,
  email TEXT,
  phone TEXT,
  website TEXT,
  notes TEXT,
  status TEXT DEFAULT 'pending',
  promo_code TEXT,
  referral_link TEXT,
  referred_clients INTEGER DEFAULT 0,
  total_commission NUMERIC(15,2) DEFAULT 0,
  paid_commission NUMERIC(15,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, promo_code)
);

ALTER TABLE partners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own partners" ON partners FOR ALL
  USING (auth.uid() = user_id);

-- Funnels
CREATE TABLE funnels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE funnels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own funnels" ON funnels FOR ALL
  USING (auth.uid() = user_id);

-- Funnel stages
CREATE TABLE funnel_stages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  funnel_id UUID REFERENCES funnels(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  "order" INTEGER NOT NULL,
  color TEXT
);

ALTER TABLE funnel_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own funnel stages" ON funnel_stages FOR ALL
  USING (EXISTS (SELECT 1 FROM funnels WHERE funnels.id = funnel_stages.funnel_id AND funnels.user_id = auth.uid()));

-- Funnel deals
CREATE TABLE funnel_deals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  funnel_id UUID REFERENCES funnels(id) ON DELETE CASCADE NOT NULL,
  stage_id UUID REFERENCES funnel_stages(id) ON DELETE CASCADE NOT NULL,
  contact_name TEXT NOT NULL,
  contact_email TEXT,
  contact_phone TEXT,
  notes TEXT,
  expected_value NUMERIC(15,2),
  expected_close_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  moved_at TIMESTAMP WITH TIME ZONE
);

ALTER TABLE funnel_deals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own funnel deals" ON funnel_deals FOR ALL
  USING (EXISTS (SELECT 1 FROM funnels WHERE funnels.id = funnel_deals.funnel_id AND funnels.user_id = auth.uid()));

-- Contacts
CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  company TEXT,
  type TEXT DEFAULT 'other',
  source TEXT,
  notes TEXT,
  tags TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own contacts" ON contacts FOR ALL
  USING (auth.uid() = user_id);

-- Publications
CREATE TABLE publications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL,
  channel_id UUID REFERENCES platform_channels(id),
  platform_post_id TEXT,
  title TEXT NOT NULL,
  content TEXT,
  image_url TEXT,
  url TEXT,
  published_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE publications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own publications" ON publications FOR ALL
  USING (auth.uid() = user_id);

-- Publication stats
CREATE TABLE publication_stats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  publication_id UUID REFERENCES publications(id) ON DELETE CASCADE NOT NULL,
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  comments INTEGER DEFAULT 0,
  shares INTEGER DEFAULT 0,
  reach INTEGER,
  impressions INTEGER,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL
);

ALTER TABLE publication_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own publication stats" ON publication_stats FOR ALL
  USING (EXISTS (SELECT 1 FROM publications WHERE publications.id = publication_stats.publication_id AND publications.user_id = auth.uid()));

-- Analytics snapshots
CREATE TABLE analytics_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  channel_id UUID REFERENCES platform_channels(id),
  metric TEXT NOT NULL,
  value NUMERIC(15,4) NOT NULL,
  date DATE NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL
);

ALTER TABLE analytics_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own analytics" ON analytics_snapshots FOR ALL
  USING (auth.uid() = user_id);

-- Tasks
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  priority TEXT DEFAULT 'medium',
  status TEXT DEFAULT 'todo',
  category TEXT,
  channel_id UUID REFERENCES platform_channels(id),
  publication_id UUID REFERENCES publications(id),
  partner_id UUID REFERENCES partners(id),
  advertiser_id UUID REFERENCES advertisers(id),
  due_date DATE,
  reminder_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own tasks" ON tasks FOR ALL
  USING (auth.uid() = user_id);

-- Advertisers
CREATE TABLE advertisers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  company_name TEXT NOT NULL,
  contact_person TEXT,
  email TEXT,
  phone TEXT,
  website TEXT,
  notes TEXT,
  status TEXT DEFAULT 'inactive',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE advertisers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own advertisers" ON advertisers FOR ALL
  USING (auth.uid() = user_id);

-- Ad campaigns
CREATE TABLE ad_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  advertiser_id UUID REFERENCES advertisers(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'planned',
  budget NUMERIC(15,2) NOT NULL,
  paid_amount NUMERIC(15,2),
  currency TEXT DEFAULT 'RUB',
  channel_ids TEXT[],
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE ad_campaigns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own ad campaigns" ON ad_campaigns FOR ALL
  USING (auth.uid() = user_id);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  read BOOLEAN DEFAULT false,
  related_id TEXT,
  related_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own notifications" ON notifications FOR ALL
  USING (auth.uid() = user_id);

-- User settings
CREATE TABLE user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  email TEXT,
  theme TEXT DEFAULT 'dark',
  timezone TEXT DEFAULT 'Asia/Novosibirsk',
  currency TEXT DEFAULT 'RUB',
  email_notifications BOOLEAN DEFAULT true,
  push_notifications BOOLEAN DEFAULT true,
  sync_notifications BOOLEAN DEFAULT true,
  financial_notifications BOOLEAN DEFAULT true,
  task_notifications BOOLEAN DEFAULT true,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own settings" ON user_settings FOR ALL
  USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX idx_platform_channels_user ON platform_channels(user_id);
CREATE INDEX idx_financial_operations_user ON financial_operations(user_id);
CREATE INDEX idx_financial_operations_date ON financial_operations(date);
CREATE INDEX idx_partners_user ON partners(user_id);
CREATE INDEX idx_funnels_user ON funnels(user_id);
CREATE INDEX idx_funnel_stages_funnel ON funnel_stages(funnel_id);
CREATE INDEX idx_funnel_deals_funnel ON funnel_deals(funnel_id);
CREATE INDEX idx_contacts_user ON contacts(user_id);
CREATE INDEX idx_publications_user ON publications(user_id);
CREATE INDEX idx_publications_platform ON publications(platform);
CREATE INDEX idx_analytics_snapshots_user ON analytics_snapshots(user_id);
CREATE INDEX idx_analytics_snapshots_date ON analytics_snapshots(date);
CREATE INDEX idx_tasks_user ON tasks(user_id);
CREATE INDEX idx_advertisers_user ON advertisers(user_id);
CREATE INDEX idx_ad_campaigns_user ON ad_campaigns(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, read);
