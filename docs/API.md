# مرجع API

این فایل از روی `docs/openapi.json` ساخته شده است. نسخهٔ تعاملی و همیشه به‌روز روی
<http://localhost:8000/docs> بالا می‌آید و شرح کامل پارامترها و مدل‌ها آنجاست.

همهٔ مسیرها با `/api/v1` شروع می‌شوند. احراز هویت با سربرگ `Authorization: Bearer <token>` انجام می‌شود.

## شکل خطاها

هر خطا، از هر مسیری، یک ساختار دارد:

```json
{ "error": { "status": 404, "code": "TITLE_NOT_FOUND", "message": "…", "detail": "tt0000000" } }
```

خطاهای اعتبارسنجی یک کلید `fields` هم دارند تا فرم بتواند پیام را زیر همان ورودی نشان دهد.

## سلامت سرویس

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `GET` | `/api/v1/health` | وضعیت سرویس | — |

## احراز هویت

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | ثبت‌نام کاربر جدید | — |
| `POST` | `/api/v1/auth/login` | ورود به حساب کاربری | — |
| `POST` | `/api/v1/auth/refresh` | تمدید نشست | — |
| `POST` | `/api/v1/auth/logout` | خروج امن | — |
| `POST` | `/api/v1/auth/password/forgot` | درخواست بازیابی رمز عبور | — |
| `POST` | `/api/v1/auth/password/reset` | ثبت رمز عبور تازه | — |

## کاربران

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `GET` | `/api/v1/users/me` | اطلاعات پروفایل خودم | — |
| `PATCH` | `/api/v1/users/me` | ویرایش پروفایل | — |
| `POST` | `/api/v1/users/me/password` | تغییر رمز عبور | — |
| `POST` | `/api/v1/users/me/avatar` | بارگذاری تصویر پروفایل | — |
| `GET` | `/api/v1/users/me/stats` | آمار فعالیت کاربر | — |
| `GET` | `/api/v1/users/{username}` | پروفایل عمومی یک کاربر | — |
| `PUT` | `/api/v1/users/{username}/follow` | دنبال کردن کاربر | — |
| `DELETE` | `/api/v1/users/{username}/follow` | لغو دنبال کردن | — |

## فیلم و سریال

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `GET` | `/api/v1/titles/search` | جست‌وجوی فیلم و سریال | — |
| `GET` | `/api/v1/titles/people` | پیشنهاد نام بازیگر و کارگردان | — |
| `GET` | `/api/v1/titles/discover` | ردیف‌های صفحهٔ اصلی | — |
| `GET` | `/api/v1/titles/recommended` | پیشنهادهای شخصی‌سازی‌شده | — |
| `GET` | `/api/v1/titles/{imdb_id}` | جزئیات فیلم یا سریال | — |
| `GET` | `/api/v1/titles/{imdb_id}/seasons` | فهرست فصل‌های یک سریال | — |
| `GET` | `/api/v1/titles/{imdb_id}/seasons/{season}/episodes` | قسمت‌های یک فصل | — |

## فهرست تماشا

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `PUT` | `/api/v1/titles/{imdb_id}/status` | ثبت وضعیت تماشا | — |
| `DELETE` | `/api/v1/titles/{imdb_id}/status` | حذف وضعیت تماشا | — |
| `PUT` | `/api/v1/titles/{imdb_id}/favorite` | افزودن به علاقه‌مندی‌ها | — |
| `DELETE` | `/api/v1/titles/{imdb_id}/favorite` | حذف از علاقه‌مندی‌ها | — |
| `PUT` | `/api/v1/titles/{imdb_id}/episodes/{episode_id}/watch` | علامت‌گذاری یک قسمت به‌عنوان دیده‌شده | — |
| `DELETE` | `/api/v1/titles/{imdb_id}/episodes/{episode_id}/watch` | برداشتن علامت دیده‌شدن یک قسمت | — |
| `PUT` | `/api/v1/titles/{imdb_id}/seasons/{season}/watch` | علامت‌گذاری کل یک فصل | — |
| `DELETE` | `/api/v1/titles/{imdb_id}/seasons/{season}/watch` | برداشتن علامت کل یک فصل | — |
| `GET` | `/api/v1/titles/{imdb_id}/progress` | درصد پیشرفت تماشا | — |
| `GET` | `/api/v1/watchlist` | فهرست تماشای من | — |
| `GET` | `/api/v1/watchlist/favorites` | آثار موردعلاقه | — |

## امتیاز و نظر

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `POST` | `/api/v1/titles/{imdb_id}/rating` | ثبت یا ویرایش امتیاز | — |
| `DELETE` | `/api/v1/titles/{imdb_id}/rating` | حذف امتیاز | — |
| `GET` | `/api/v1/titles/{imdb_id}/reviews` | نظرهای ثبت‌شده برای یک اثر | — |
| `POST` | `/api/v1/titles/{imdb_id}/reviews` | ثبت نظر | — |
| `DELETE` | `/api/v1/reviews/{review_id}` | حذف نظر خودم | — |
| `POST` | `/api/v1/reports` | گزارش نظر نامناسب | — |
| `GET` | `/api/v1/reviews/mine` | همهٔ نظرهای من | — |

## فهرست‌های شخصی

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `GET` | `/api/v1/lists` | فهرست‌های من | — |
| `POST` | `/api/v1/lists` | ساخت فهرست تازه | — |
| `GET` | `/api/v1/lists/{list_id}` | جزئیات یک فهرست | — |
| `PATCH` | `/api/v1/lists/{list_id}` | ویرایش فهرست | — |
| `DELETE` | `/api/v1/lists/{list_id}` | حذف فهرست | — |
| `POST` | `/api/v1/lists/{list_id}/items` | افزودن اثر به فهرست | — |
| `DELETE` | `/api/v1/lists/{list_id}/items/{imdb_id}` | حذف اثر از فهرست | — |

## اجتماعی

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `GET` | `/api/v1/feed` | فعالیت کاربرانی که دنبال می‌کنید | — |
| `GET` | `/api/v1/titles/{imdb_id}/chat` | تاریخچهٔ گفت‌وگوی یک اثر | — |
| `POST` | `/api/v1/titles/{imdb_id}/chat` | ارسال پیام در گفت‌وگوی یک اثر | — |

## مدیریت سیستم

| متد | مسیر | کار | ورود لازم |
|---|---|---|---|
| `GET` | `/api/v1/admin/users` | فهرست کاربران | — |
| `PATCH` | `/api/v1/admin/users/{user_id}` | فعال/غیرفعال کردن کاربر یا تغییر نقش | — |
| `GET` | `/api/v1/admin/reviews` | همهٔ نظرها | — |
| `DELETE` | `/api/v1/admin/reviews/{review_id}` | حذف نظر نامناسب | — |
| `GET` | `/api/v1/admin/reports` | گزارش‌های کاربران | — |
| `PATCH` | `/api/v1/admin/reports/{report_id}` | رسیدگی به یک گزارش | — |
| `GET` | `/api/v1/admin/titles` | اطلاعات ذخیره‌شدهٔ فیلم‌ها و سریال‌ها | — |
| `POST` | `/api/v1/admin/titles/{imdb_id}/refresh` | به‌روزرسانی اجباری اطلاعات یک اثر از IMDb | — |
| `DELETE` | `/api/v1/admin/titles/{imdb_id}` | پاک کردن اثر از حافظهٔ سرور | — |
| `GET` | `/api/v1/admin/stats` | آمار کلی سامانه | — |

## وب‌سوکت

| مسیر | کار |
|---|---|
| `/api/v1/titles/{imdb_id}/chat/ws?token=<access_token>` | اتاق گفت‌وگوی زندهٔ هر اثر (بخش ۱۳) |
