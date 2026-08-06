/// Form validation, mirrored from the backend rules (sections 7.8, 8.2).
///
/// Client-side checks are only for fast feedback — the server validates again,
/// and its `fields` map is what a form finally trusts.
library;

class Validators {
  const Validators._();

  static final _email = RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
  static final _username = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  static String? required(String? value, {String field = 'این فیلد'}) {
    if (value == null || value.trim().isEmpty) return '$field را پر کنید.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'ایمیل را وارد کنید.';
    if (!_email.hasMatch(value.trim())) return 'قالب ایمیل درست نیست.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'رمز عبور را وارد کنید.';
    if (value.length < 8) return 'رمز عبور باید دست‌کم ۸ نویسه باشد.';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'نام کاربری را وارد کنید.';
    if (!_username.hasMatch(value.trim())) {
      return 'فقط حروف و ارقام انگلیسی و «_» — بین ۳ تا ۳۰ نویسه.';
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'نام و نام خانوادگی را کامل بنویسید.';
    }
    return null;
  }

  static String? confirm(String? value, String? other) {
    if (value != other) return 'دو رمز عبور یکسان نیستند.';
    return null;
  }

  static String? reviewText(String? value) {
    if (value == null || value.trim().isEmpty) return 'متن نظر نمی‌تواند خالی باشد.';
    if (value.trim().length > 4000) return 'متن نظر طولانی‌تر از حد مجاز است.';
    return null;
  }

  static String? listName(String? value) {
    if (value == null || value.trim().isEmpty) return 'نام فهرست را بنویسید.';
    if (value.trim().length > 80) return 'نام فهرست طولانی است.';
    return null;
  }
}
