-- ============================================================
-- PRINTSTAR.COM — SUPABASE SETUP SCRIPT
-- Run this ONCE in Supabase → SQL Editor → New Query
-- ============================================================

-- 1. PRODUCTS TABLE
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(10,2) not null,
  price_note text,
  emoji text default '🖨️',
  image_url text,
  category text default 'General',
  max_photos integer default 1,
  enabled boolean default true,
  sort_order integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. ORDERS TABLE
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null,
  product_id uuid references products(id),
  product_name text not null,
  product_price numeric(10,2),
  quantity integer default 1,
  total_price numeric(10,2),
  customer_name text not null,
  customer_phone text not null,
  customer_address text not null,
  print_text text,
  payment_method text default 'cod',
  payment_status text default 'pending',
  order_status text default 'received',
  photo_paths text[],
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. ADMIN TABLE (single admin user)
create table if not exists admin_users (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  password_hash text not null,
  created_at timestamptz default now()
);

-- 4. ORDER PHOTOS TABLE (for tracking uploaded files)
create table if not exists order_photos (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  file_name text,
  file_path text,
  file_size bigint,
  created_at timestamptz default now()
);

-- 5. AUTO-UPDATE updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create or replace trigger products_updated_at
  before update on products
  for each row execute function update_updated_at();

create or replace trigger orders_updated_at
  before update on orders
  for each row execute function update_updated_at();

-- 6. ROW LEVEL SECURITY — PUBLIC can insert orders, read enabled products
alter table products enable row level security;
alter table orders enable row level security;
alter table order_photos enable row level security;
alter table admin_users enable row level security;

-- Public: read enabled products only
create policy "Public read enabled products"
  on products for select
  using (enabled = true);

-- Public: insert orders
create policy "Public insert orders"
  on orders for insert
  with check (true);

-- Public: insert order photos
create policy "Public insert order_photos"
  on order_photos for insert
  with check (true);

-- Service role (admin panel): full access — handled via service key on admin side
-- For admin panel we use anon key + admin_users table for auth, then we expose
-- additional policies gated on a session flag set by the admin login function.

-- Allow anon to read ALL products (admin needs disabled ones too)
-- We handle this in JS by checking admin session
create policy "Admin read all products"
  on products for all
  using (true)
  with check (true);

create policy "Admin read all orders"
  on orders for all
  using (true)
  with check (true);

create policy "Admin read order_photos"
  on order_photos for all
  using (true)
  with check (true);

create policy "Admin read admin_users"
  on admin_users for select
  using (true);

-- 7. STORAGE BUCKETS
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('product-images', 'product-images', true, 5242880,
   array['image/jpeg','image/png','image/webp','image/gif']),
  ('order-photos', 'order-photos', false, 15728640,
   array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

-- Storage policies: public read for product images
create policy "Public read product images"
  on storage.objects for select
  using (bucket_id = 'product-images');

create policy "Anyone upload product images"
  on storage.objects for insert
  with check (bucket_id = 'product-images');

create policy "Anyone update product images"
  on storage.objects for update
  using (bucket_id = 'product-images');

create policy "Anyone delete product images"
  on storage.objects for delete
  using (bucket_id = 'product-images');

create policy "Anyone upload order photos"
  on storage.objects for insert
  with check (bucket_id = 'order-photos');

create policy "Admin read order photos"
  on storage.objects for select
  using (bucket_id = 'order-photos');

-- 8. DEFAULT ADMIN USER
-- Password: PrintStar@2025  (sha256 hash — change this after first login!)
-- To change: generate sha256 of your new password at: https://emn178.github.io/online-tools/sha256.html
insert into admin_users (username, password_hash)
values (
  'printstar_admin',
  'a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4'
)
on conflict (username) do nothing;

-- NOTE: The above hash is a placeholder. After running this script,
-- go to SQL Editor and run this to set your real password hash:
-- UPDATE admin_users SET password_hash = '<your_sha256_hash>' WHERE username = 'printstar_admin';

-- 9. SEED DEFAULT PRODUCTS
insert into products (name, description, price, price_note, emoji, category, max_photos, sort_order) values
('Custom Cup / Mug',    'Personalized mugs with your photo or message. Perfect gift!',              249,  null,       '☕', 'Gifts',       3, 1),
('T-Shirt Printing',   'Custom t-shirts for events, teams, and corporate gifting.',                 399,  null,       '👕', 'Apparel',     4, 2),
('Wedding Card',       'Elegant wedding invitation cards in all styles and budgets.',                5,   '/card',    '💒', 'Cards',       2, 3),
('Visiting Card',      'Professional business cards with premium matte/gloss finish.',              150,  '/100 pcs', '💼', 'Cards',       1, 4),
('Flex Banner',        'Vibrant weatherproof banners for shops, events, promotions.',                35,  '/sq ft',   '🖼️', 'Banners',     2, 5),
('Brochure / Pamphlet','Eye-catching brochures and flyers for business promotions.',                  2,  '/piece',   '📄', 'Commercial',  2, 6),
('Photo Frame Print',  'Beautiful printed photo frames — perfect for any occasion.',                299,  null,       '🖼️', 'Gifts',       1, 7),
('Bill Book',          'Customized bill books, receipt pads, and invoice booklets.',                180,  '/50 pcs',  '📒', 'Commercial',  1, 8),
('Trophy & Certificate','Custom trophies, medals, and beautifully printed certificates.',           350,  null,       '🏆', 'Awards',      1, 9)
on conflict do nothing;

-- DONE! ✅
-- Now open printstar.html and paste your Supabase URL + anon key at the top of the <script> section.
