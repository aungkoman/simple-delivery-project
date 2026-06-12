# Simple Delivery Project


## Tasks

- [ ] phone number should be unique

https://supabase.com/dashboard/project/nhyeutkgxyiqcxrfojcq/sql/e3647eba-39f6-45e5-86b1-22e3c45bc212

supabase with aungkoman's github connected.flutter run


I/flutter ( 7854): FCM Device Token: d7lTAa0BRVujeZVJL6NePL:APA91bEP6PlMN1TmRqev0gSWgJFa7fRH7bqea-Psu6_t2slw63INetPzBlD2sEg6h0S3PHY7hrjxhgeQUR-GVOo_KenOZKj4zeVyZwZzVgHeevjhLEFDjRY


🚨 Crucial Supabase Architecture Warning
Because you are calling supabase.auth.signUp() from the client app to automatically create the new customer account, Supabase will automatically log the Admin out and log in as the newly created custome



## 2026-06-12 Township and Pricing on Ways

So we can automatically assign rider ,
add deadline of way,

most fields should be optional.

- [x] Image Feature added to Way create, edit in Admin Panel
- [x] Image slideshow, listing in Way Detail 

- [ ] need to store rider changes history also. way မှာ ဘာပြောင်းပြောင်း သိမ်းထားနိုင်မယ့် table တစ်ခု။ log အတွက်။ ဘယ်သူပြောင်းသွားတယ် ဆိုတာကအစ။ နှစ်ခုပြောင်းရင် နှစ်ခုပေါ့။ 
- [ ] pickup , dropoff မှာ township , address , contact info (person + phone) ဒါတွေလိုမယ်။ အပြည့်အစုံ ထည့်ချင်ထည့်။ 
- [ ] new premium green/grey design


## 2026-06-10 Demo Account


https://appdistribution.firebase.dev/i/ec16135bd7a44fdb

Simple Delivery App

Admin
Phone : 0912345
Password : password


Rider
Phone : 091234567890
Password : password



## App Icon

```bash
dart run flutter_launcher_icons
```
## 2026-06-09 Final Polish

- [ ] Screen တစ်ခုချင်းစီ ရှင်းရန်။ customer ကို မေ့ထားလိုက်။ Platform Owner နဲ့ Rider သုံးဖို့ပဲ။


## Way တစ်ခုမှာ ဘာတွေထည့်ကြမလဲ?

- [ ] way id , human readable, datetime and serial no.


```bash
flutter build web
```
ိ
## 2026-06-05 Data Entry

- [ ] admin panel - new way entry. ( should user account created or just profile is enough ? )
- [ ] just decide, 
d

- [x] Login Page ပြင်ရန်။


### Phone No update လုပ်နိုင်ရန်။


## 2026-06-04 Tasks

- [x] Phone No ဖြင့် account ဖောက်ရန်။ login ဝင်ရန်
- [ ] ပါစယ် ပေးပို့ လက်ခံ အချက်အလက် ထည့်သွင်းရန်။
- [ ] Way ID ထုတ်ရန်။
- [ ] pickup / drop off ->  personal information, contact and lat, lng 
- [ ] add pricing
- [ ] created_at နဲ့ updated_at ထည့်ပြရန်

## ဘာတွေ လိုသေးလဲ?

- [ ] user self management
- [ ] Row Level Security (RLS) ဖွင့်ရန်။


## ဘာတွေ သုံးလို့ ရပြီလဲ?


### Customer

- [ ] Register
- [ ] Login
- [ ] Dashboard
- [ ] Way Create
- [ ] Way Detail
- [ ] Profile Update
- [ ] Logout


### Rider

- [ ] Login
- [ ] Dashboard
- [ ] Way Listing
- [ ] Way Detail
- [ ] Way status update

### Admin

- [ ] Login
- [ ] Dashboard
- [ ] User Management
- [ ] Way Management