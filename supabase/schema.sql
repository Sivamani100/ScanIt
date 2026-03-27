-- BILL EASE PRODUCTION SCHEMA
-- SUPABASE POSTGRESQL

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";

-- 2. TABLES

-- SHOPS: Core business entity
create table if not exists public.shops (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    address text,
    owner_name text,
    upi_id text,
    phone text,
    email text,
    gst_number text,
    logo_url text,
    is_onboarded boolean default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- PROFILES: Link auth.users to shops
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    shop_id uuid references public.shops(id) on delete set null,
    full_name text,
    role text default 'owner', -- 'owner', 'staff'
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- PRODUCTS: Inventory management
create table if not exists public.products (
    id uuid primary key default uuid_generate_v4(),
    shop_id uuid references public.shops(id) on delete cascade not null,
    name text not null,
    description text,
    price decimal(12,2) not null default 0,
    mrp decimal(12,2),
    stock integer not null default 0,
    category_id text,
    category_name text,
    barcode text,
    hsn_code text,
    gst_percent decimal(5,2) default 0,
    image_url text,
    total_sold integer default 0,
    total_revenue decimal(12,2) default 0,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- CUSTOMERS: CRM system
create table if not exists public.customers (
    id uuid primary key default uuid_generate_v4(),
    shop_id uuid references public.shops(id) on delete cascade not null,
    name text,
    phone text not null,
    email text,
    address text,
    notes text,
    total_spent decimal(12,2) default 0,
    visit_count integer default 0,
    credit_balance decimal(12,2) default 0, -- Total amount owed by customer
    last_visit timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(shop_id, phone)
);

-- BILLS: Transaction headers
create table if not exists public.bills (
    id uuid primary key default uuid_generate_v4(),
    shop_id uuid references public.shops(id) on delete cascade not null,
    customer_id uuid references public.customers(id) on delete set null,
    bill_number text not null,
    customer_phone text,
    customer_name text,
    subtotal decimal(12,2) not null,
    gst_amount decimal(12,2) default 0,
    discount_amount decimal(12,2) default 0,
    total decimal(12,2) not null,
    amount_paid decimal(12,2) default 0, -- How much was paid at checkout
    balance_amount decimal(12,2) default 0, -- Outstanding balance (total - amount_paid)
    payment_method text not null default 'upi', -- 'upi', 'cash', 'card', 'partial', 'credit'
    payment_status text not null default 'pending', -- 'pending', 'paid', 'partial', 'cancelled'
    notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- BILL_ITEMS: Transaction line items
create table if not exists public.bill_items (
    id uuid primary key default uuid_generate_v4(),
    bill_id uuid references public.bills(id) on delete cascade not null,
    product_id uuid references public.products(id) on delete set null,
    product_name text not null,
    quantity decimal(10,2) not null,
    price decimal(12,2) not null,
    gst_percent decimal(5,2) default 0,
    discount_percent decimal(5,2) default 0,
    total decimal(12,2) not null
);

-- EXPENSES: Business cost tracking
create table if not exists public.expenses (
    id uuid primary key default uuid_generate_v4(),
    shop_id uuid references public.shops(id) on delete cascade not null,
    title text not null,
    amount decimal(12,2) not null,
    date timestamp with time zone default timezone('utc'::text, now()) not null,
    category text,
    description text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
alter table public.shops enable row level security;
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.bills enable row level security;
alter table public.bill_items enable row level security;
alter table public.expenses enable row level security;

-- 4. RLS POLICIES (Multi-tenant)

-- Profile Policy: Users can only see their own profile
create policy "Users can view own profile" on public.profiles
    for select using (auth.uid() = id);

-- Shop Policy: Users can see the shop they belong to
create policy "Users can view their shop" on public.shops
    for select using (
        id in (select shop_id from public.profiles where profiles.id = auth.uid())
    );

create policy "Owners can update their shop" on public.shops
    for update using (
        id in (select shop_id from public.profiles where profiles.id = auth.uid())
    );

-- Product Policy: Shop scoped
create policy "Users can manage their shop products" on public.products
    for all using (
        shop_id in (select shop_id from public.profiles where profiles.id = auth.uid())
    );

-- Customer Policy: Shop scoped
create policy "Users can manage their shop customers" on public.customers
    for all using (
        shop_id in (select shop_id from public.profiles where profiles.id = auth.uid())
    );

-- Bill Policy: Shop scoped
create policy "Users can manage their shop bills" on public.bills
    for all using (
        shop_id in (select shop_id from public.profiles where profiles.id = auth.uid())
    );

-- Bill Items Policy: Linked via Bill
create policy "Users can manage their shop bill items" on public.bill_items
    for all using (
        bill_id in (
            select id from public.bills 
            where shop_id in (select shop_id from public.profiles where profiles.id = auth.uid())
        )
    );

-- Expense Policy: Shop scoped
create policy "Users can manage their shop expenses" on public.expenses
    for all using (
        shop_id in (select shop_id from public.profiles where profiles.id = auth.uid())
    );

-- 5. FUNCTIONS & TRIGGERS

-- A. Automatically create a shop and profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
declare
    new_shop_id uuid;
    s_name text;
    s_phone text;
begin
    -- Extract from metadata or use defaults
    s_name := coalesce(new.raw_user_meta_data->>'shop_name', 'My New Shop');
    s_phone := coalesce(new.raw_user_meta_data->>'phone', '');

    -- Create a new shop for the user
    insert into public.shops (name, phone)
    values (s_name, s_phone)
    returning id into new_shop_id;

    -- Create the user profile linked to the shop
    insert into public.profiles (id, shop_id, full_name)
    values (new.id, new_shop_id, coalesce(new.raw_user_meta_data->>'full_name', s_name));
    
    return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- B. Update stock when a bill is created
create or replace function public.decrement_stock()
returns trigger as $$
begin
    update public.products
    set stock = stock - new.quantity
    where id = new.product_id;
    return new;
end;
$$ language plpgsql security definer;

create trigger on_bill_item_added
    after insert on public.bill_items
    for each row execute procedure public.decrement_stock();

-- C. Update customer stats when a bill is finalized
create or replace function public.update_customer_metrics()
returns trigger as $$
begin
    if new.customer_id is not null then
        update public.customers
        set 
            total_spent = total_spent + new.total,
            visit_count = visit_count + 1,
            credit_balance = credit_balance + new.balance_amount,
            last_visit = now()
        where id = new.customer_id;
    end if;
    return new;
end;
$$ language plpgsql security definer;

create trigger on_bill_finalized
    after insert on public.bills
    for each row execute procedure public.update_customer_metrics();

-- D. Update 'updated_at' timestamp
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger on_product_updated
    before update on public.products
    for each row execute procedure public.handle_updated_at();

-- 6. ANALYTICS VIEWS

-- Daily Sales Summary
create or replace view public.daily_sales_stats as
select 
    shop_id,
    date_trunc('day', created_at) as sale_date,
    count(id) as total_bills,
    sum(total) as gross_revenue,
    sum(gst_amount) as total_gst,
    sum(discount_amount) as total_discounts
from public.bills
group by shop_id, sale_date;

-- Product Performance
create or replace view public.product_performance as
select 
    p.shop_id,
    p.id as product_id,
    p.name as product_name,
    sum(bi.quantity) as units_sold,
    sum(bi.total) as revenue_generated
from public.products p
join public.bill_items bi on bi.product_id = p.id
group by p.shop_id, p.id, p.name;

-- 7. INDEXES FOR PERFORMANCE
create index if not exists idx_products_shop_search on public.products (shop_id, name, barcode);
create index if not exists idx_bills_shop_date on public.bills (shop_id, created_at desc);
create index if not exists idx_bill_items_bill_id on public.bill_items (bill_id);
create index if not exists idx_customers_shop_phone on public.customers (shop_id, phone);
create index if not exists idx_expenses_shop_date on public.expenses (shop_id, date desc);

-- 8. INTEGRITY CONSTRAINTS
alter table public.bills add constraint unique_bill_number_per_shop unique (shop_id, bill_number);
