create table public.ways (
  id serial not null,
  customer_id uuid null,
  rider_id uuid null,
  pickup_location text not null,
  drop_location text not null,
  status text not null default 'pending'::text,
  remark text null,
  description text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  images text[] null default '{}'::text[],
  payment_type public.payment_type_enum null default 'prepaid'::payment_type_enum,
  who_paid public.who_paid_enum null default 'sender'::who_paid_enum,
  pay_status public.pay_status_enum null default 'prepaid'::pay_status_enum,
  rider_fee_status public.rider_fee_status_enum null default 'pending'::rider_fee_status_enum,
  delivery_charges numeric(12, 2) null default 0.00,
  rider_fee numeric(12, 2) null default 0.00,
  parcel_value numeric(12, 2) null default 0.00,
  amount_to_collect numeric(12, 2) null default 0.00,
  sender_payout_status public.sender_payout_status_enum null default 'pending'::sender_payout_status_enum,
  constraint ways_pkey primary key (id),
  constraint ways_customer_id_fkey foreign KEY (customer_id) references profiles (id),
  constraint ways_rider_id_fkey foreign KEY (rider_id) references profiles (id)
) TABLESPACE pg_default;

create trigger on_way_status_changed
after INSERT
or
update on ways for EACH row
execute FUNCTION handle_way_history ();

create trigger on_ways_updated BEFORE
update on ways for EACH row
execute FUNCTION handle_updated_at ();