
```markdown
# 📦 Simple Delivery 

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/postgresql-4169e1?style=for-the-badge&logo=postgresql&logoColor=white)
![Open Source](https://img.shields.io/badge/Open_Source-Yes-success?style=for-the-badge)

**Simple Delivery** is a full-stack, SaaS-ready delivery management and logistics application. Built entirely with Flutter and Supabase, this project serves as a comprehensive example of how to build, scale, and secure a real-world multi-tenant application.

Whether you are a student learning about backend-as-a-service (BaaS), or a developer looking for a template to start a logistics startup, this repository contains the architectural patterns you need.

---

## ✨ Key Features

* **🔐 Multi-Tenant SaaS Architecture:** Built-in Row-Level Security (RLS) ensures that multiple delivery businesses can use the app simultaneously without ever seeing each other's data.
* **👥 Role-Based Access Control (RBAC):** Three distinct user roles:
  * **Admin:** Dispatchers who manage orders, assign riders, and view dashboard analytics.
  * **Rider:** On-the-ground personnel who update package statuses in real-time.
  * **Customer:** Senders/Receivers tracked seamlessly by phone number.
* **📊 Smart Admin Dashboard:** A beautifully designed, tiered dashboard highlighting actionable metrics (Pending/Active deliveries) with custom skeleton/shimmer loading animations.
* **🚚 Visual Delivery Pipeline:** Track packages through a strict operational flow (`Pending` → `Preparing` → `Assigned` → `Picked Up` → `Delivering` → `Delivered` → `Cancelled`).
* **📱 Phone-First Workflow:** Frictionless Autocomplete search boxes allow admins to assign riders and find customers instantly by name or phone number.

---

## 🛠️ Technology Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend:** [Supabase](https://supabase.com/)
  * **Database:** PostgreSQL
  * **Auth:** Supabase Auth (Email/Password & JWT manipulation)
  * **Compute:** Deno Edge Functions (For secure, server-side user creation)
* **UI/UX:** Custom animated app bars, Shimmer effects (No heavy 3rd-party dependencies!), and color-coded status chips.

---

## 🧠 What Students Will Learn

This codebase is highly commented and structured for educational purposes. By exploring this repository, you will learn:
1. **Supabase RLS (Row Level Security):** How to lock down a database using PostgreSQL policies and JWT metadata so users only see their own company's data.
2. **Advanced UI Building:** How to build custom `AppBars`, utilize `Sliver` layouts, and build dependency-free Shimmer loading screens.
3. **Relational Data in NoSQL-style:** How to write complex `.select('*, customer:profiles(...), rider:profiles(...)')` queries in Flutter.
4. **Data Seeding:** How to use PostgreSQL functions like `generate_series()` to mock thousands of realistic user profiles and delivery records.

---

## 🚀 Getting Started

Follow these steps to get the project running on your local machine.

### 1. Prerequisites
* Flutter SDK installed (v3.10+)
* A free [Supabase](https://supabase.com/) account
* Git

### 2. Supabase Setup
1. Create a new project in your Supabase dashboard.
2. Navigate to the **SQL Editor** and run the schema setup script found in `/database/01_schema.sql` (Note: Ensure your `companies`, `profiles`, and `ways` tables are created).
3. (Optional but Recommended) Run the dummy data seed script found in `/database/02_seed_data.sql` to instantly populate your dashboard with 50 customers, 10 riders, and 50 deliveries.

### 3. Flutter Setup
1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/simple-delivery.git](https://github.com/yourusername/simple-delivery.git)
   cd simple-delivery

```

2. Install dependencies:
```bash
flutter pub get

```


3. Connect your Supabase project:
   Open `lib/main.dart` (or your `.env` file) and replace the placeholder keys with your actual Supabase URL and Anon Key.
```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);

```


4. Run the app:
```bash
flutter run

```



---

## 🗄️ Database Schema Overview

The core of the application relies on three heavily integrated tables:

* `companies`: The SaaS tenants (businesses using the app).
* `profiles`: Extends Supabase Auth. Contains Name, Phone, Role, and `company_id`.
* `ways`: The core delivery record. Contains pickup/drop-off info, current status, and foreign keys linking to the `customer_id`, `rider_id`, and `company_id`.

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

*Designed with ❤️ for the Flutter & Supabase community.*

```
