-- ==========================================
-- Supabase Schema for ScanIt Retail Application
-- ==========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. Tables Creation
-- ==========================================

-- Shops Table
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    owner_name TEXT,
    upi_id TEXT,
    phone TEXT,
    email TEXT,
    pin TEXT DEFAULT '0000',
    logo_url TEXT,
    gst_number TEXT,
    is_onboarded BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Profiles Table (Links Auth Users to Shops)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL,
    role TEXT DEFAULT 'owner',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products Table
CREATE TABLE IF NOT EXISTS public.products (
    id TEXT PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    mrp NUMERIC,
    barcode TEXT,
    category_id TEXT NOT NULL,
    category_name TEXT,
    stock NUMERIC NOT NULL DEFAULT 0,
    hsn_code TEXT,
    gst_percent NUMERIC NOT NULL DEFAULT 0,
    image_url TEXT,
    total_sold NUMERIC DEFAULT 0,
    total_revenue NUMERIC DEFAULT 0,
    is_weight_based BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customers Table
CREATE TABLE IF NOT EXISTS public.customers (
    id TEXT PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    name TEXT,
    phone TEXT NOT NULL,
    email TEXT,
    total_spent NUMERIC DEFAULT 0,
    visit_count INTEGER DEFAULT 0,
    credit_balance NUMERIC DEFAULT 0,
    loyalty_points INTEGER DEFAULT 0,
    loyalty_tier TEXT DEFAULT 'bronze',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(shop_id, phone)
);

-- Bills (Invoices) Table
CREATE TABLE IF NOT EXISTS public.bills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    customer_id TEXT REFERENCES public.customers(id) ON DELETE SET NULL,
    bill_number TEXT NOT NULL,
    customer_phone TEXT,
    customer_name TEXT,
    subtotal NUMERIC NOT NULL,
    gst_amount NUMERIC NOT NULL,
    discount_amount NUMERIC NOT NULL,
    total NUMERIC NOT NULL,
    amount_paid NUMERIC DEFAULT 0,
    balance_amount NUMERIC DEFAULT 0,
    payment_method TEXT NOT NULL,
    payment_status TEXT NOT NULL,
    notes TEXT,
    pdf_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bill Items Table
CREATE TABLE IF NOT EXISTS public.bill_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    product_id TEXT REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    quantity NUMERIC NOT NULL,
    price NUMERIC NOT NULL,
    gst_percent NUMERIC NOT NULL,
    discount_percent NUMERIC NOT NULL,
    total NUMERIC NOT NULL
);

-- Expenses Table
CREATE TABLE IF NOT EXISTS public.expenses (
    id TEXT PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    amount NUMERIC NOT NULL,
    date TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- 2. Row Level Security (RLS)
-- ==========================================

ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Shops Policies
CREATE POLICY "Users can view their shop" ON public.shops FOR SELECT USING (id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid()));
CREATE POLICY "Owners can update their shop" ON public.shops FOR UPDATE USING (id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid()));
CREATE POLICY "Users can insert shops" ON public.shops FOR INSERT WITH CHECK (true);

-- Products Policies
CREATE POLICY "Users can manage their shop products" ON public.products FOR ALL USING (shop_id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid()));

-- Customers Policies
CREATE POLICY "Users can manage their shop customers" ON public.customers FOR ALL USING (shop_id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid()));

-- Bills Policies
CREATE POLICY "Users can manage their shop bills" ON public.bills FOR ALL USING (shop_id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid()));

-- Bill Items Policies
CREATE POLICY "Users can manage their shop bill items" ON public.bill_items FOR ALL USING (bill_id IN (SELECT id FROM public.bills WHERE shop_id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid())));

-- Expenses Policies
CREATE POLICY "Users can manage their shop expenses" ON public.expenses FOR ALL USING (shop_id IN (SELECT shop_id FROM public.profiles WHERE id = auth.uid()));


-- ==========================================
-- 3. Storage Buckets & Policies
-- ==========================================

-- Create Invoices Bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('Invoices', 'Invoices', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow Public Access for Invoices Storage
CREATE POLICY "Public Access for Invoices" 
ON storage.objects FOR ALL 
TO public
USING (bucket_id = 'Invoices')
WITH CHECK (bucket_id = 'Invoices');

-- ==========================================
-- 4. Triggers & Functions
-- ==========================================

-- Function to automatically update "updated_at" timestamps
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to relevant tables
CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function to automatically create a profile for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call profile creation on user signup
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
