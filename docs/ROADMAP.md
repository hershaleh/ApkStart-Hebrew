# מפת דרכים

## שלב 1 — תשתית בטוחה
- [x] מאגר עצמאי ונפרד מ-ApkStart.
- [x] ממשק Windows גרפי בעברית.
- [x] זיהוי תיקיית התקנה ותמיכה במבנה קבצים פרוס.
- [x] גיבוי מקדים ושחזור מותנה SHA-256.
- [x] חסימת שינוי MSIX ו-ASAR בשלב זה.
- [x] בדיקת תחביר PowerShell ותקינות JSON ב-GitHub Actions.

## שלב 2 — תרגום ממשק
- [x] מילון עברי חיצוני.
- [x] תרגום ראשוני של ממשק הבית והודעות נפוצות.
- [x] שכבת RTL ראשונית.
- [x] הרחבת מילון app.js להודעות תפעול, אבחון, רשת, שמע, אחסון והגדרות.
- [ ] הרחבת המילון לכל מחרוזות הממשק הראשי.
- [x] הרחבת תרגום תוויות סביבת ההרצה, הגדרות Android, קבצים, שילוב Windows, עדכונים ואודות.
- [x] תרגום הודעות נוספות להתקנת APK ולתהליך תיקון סביבת Android, תחת allowlist ייעודית.
- [x] תרגום הודעות נבחרות מתהליך Electron הראשי באמצעות allowlist ייעודית בקובץ נפרד.
- [x] הרחבת הודעות המעבר בין כיווני מסך, הפעלה מחדש ומעבר זמני למצב משולב.
- [x] הרחבת תרגום תוויות, תיאורים ובקרות בחלונות ההגדרות לפי מילון חיצוני.
- [x] הרחבת תרגום מסך ההגדרות הראשי: רזולוציות תצוגה, נתוני מחיצת Android, רשת, סביבת הרצה, מנהלי התקנים ומצב ריבוי חלונות.
- [x] תרגום כותרות חלון היישום הנפרד באמצעות allowlist ייעודית.
- [x] הפרדת תרגום shell.js ו-shell.html מרשימת התרגום הכללית.
- [x] allowlist נפרדת למחרוזות UI שנבדקו ב-app.js כדי למנוע שינוי מחרוזות פנימיות.
- [x] הרחבת תרגום הודעות מצב הריצה, מצב הרשת, נתוני האחסון וטקסטי חלון הפתיחה שנמצאו בסריקת app.js.
- [x] השלמת תרגום סטטוסי כרטיסי היישומים, תווית מצב 'פועל כעת', פעולת עצירת סביבת הריצה ותוויות מצב האופטימיזציה, תחת allowlist מפורשת.
- [x] השלמת תוויות סביבתיות וחיבוריות שנמצאו בסריקה נוספת של app.js: גרירת APK, מצב חלון עצמאי, מצב רשת/Wi-Fi/טיסה, האצת חומרה וקיצורי דרך.
- [x] תרגום תוויות ממשק האבחון האוטומטי, סיכומי מצב, מוני תקלות, כפתורי טיפול/מדריך והודעות פעולות תיקון, תחת allowlist ייעודית.
- [x] תרגום שמות קטגוריות, כותרות תקלות, הסברים ופרטי אבחון דינמיים מתוך src/core/autodebug.js באמצעות allowlist נפרדת, תוך שמירה על משתני התבניות והקוד הלוגי.
- [x] תרגום כותרות ממוספרות חסרות במדריך, כותרות משנה ותוויות טבלאות נבחרות.
- [ ] הרחבת הכיסוי לאחר סקירת מחרוזות נוספות.
- [x] תרגום כותרות, תוכן עניינים ומונחי ניווט במדריך הפנימי.
- [x] הוספת שכבת תרגום רחבה לכותרות, פעולות, מונחי אבחון והוראות נפוצות בגוף המדריך.
- [x] הרחבת תרגום לפסקאות הסבר, הוראות הפעלה, אבחון שמע, זמני הפעלה והודעות פתרון תקלות.
- [x] בדיקות ייעודיות לווידוא שמחרוזות גוף המדריך קיימות גם במילון וגם ב-allowlist.
- [x] הרחבת תרגום פסקאות שימוש, הסברים, אבחון ותיקון תקלות במדריך, עם allowlist ובדיקות כיסוי ייעודיות.
- [x] תרגום הוראות עדכון, שיתוף קבצים, ריבוי מופעים, אבחון אוטומטי וטבלת פתרון תקלות; נוספו בדיקות ייעודיות.
- [x] התאמת RTL ייעודית לחלון היישום הנפרד, כולל סרגל הכותרת וכפתורי החלון.
- [x] הרחבת RTL לחלון ההגדרות, גוף ההגדרות, ניווט הקטגוריות, שדות, קבוצות מתגים, תפריטי הקשר, הודעות Toast וחלונות פתיחה.
- [x] שמירת שדות טכניים, נתיבים, כתובות URL, קוד, פקודות וערכים מספריים בכיוון LTR באמצעות חריגים ממוקדים.
- [x] בדיקות סטטיות לווידוא כיסוי RTL ולשמירת חריגי LTR.
- [x] קובץ המדריך HTML נסרק ברשימת אישור ייעודית.
- [x] קוד הניתוב src/core/manual.js מוחרג משינוי טקסטואלי כדי לשמור על regex וכללי התאמה.

## שלב 3 — תאימות והפצה
- [ ] בדיקות בפועל מול Setup ו-Portable בגרסאות נתמכות.
- [ ] זיהוי עדכון ApkStart והתרעה כשהתרגום דורש התאמה.
- [ ] מנגנון תיקון/החלה מחדש לאחר עדכון.
- [ ] חבילת ZIP מוכנה לשימוש.
- [ ] EXE עצמאי להפעלה פשוטה, ללא דרישת Node.js.
- [ ] בדיקות שחזור אחרי עדכון תוכנה ושינוי ידני של קבצים.
- [ ] בחינת תמיכת MSIX במסלול נפרד שאינו פוגע בחתימה.
- [ ] בחינת ASAR באמצעות ספרייה ייעודית ובדיקות תקינות ארכיון.

## עקרונות
- לא משנים קובצי Android, APK מותקנים, מסדי נתונים או נתוני משתמש.
- לא מבצעים עקיפת חתימות או מנגנוני הגנה.
- לא מחילים תרגום אם מבנה הגרסה אינו מזוהה.
- כל קובץ שמשתנה מגובה, והשחזור בודק hash לפני החלפתו.


## Latest manual translation batch
- Expanded the reviewed Hebrew coverage for sections 6.7 (audio troubleshooting) and 6.8 (Microsoft Store / DLL startup failures).
- Added explicit tests requiring the new user-facing manual text to exist in the Hebrew dictionary and the dedicated manual allowlist.
- Technical commands, DLL names, paths, and inline code remain outside broad replacement; only reviewed literal text nodes are eligible.


## Startup troubleshooting coverage
- Added reviewed Hebrew text for the startup/window-attachment guidance in section 6.5 and the startup error quick-reference table in section 6.6.
- Extended validation to check each added phrase in the dictionary and the dedicated manual allowlist.


## System diagnostics and manual navigation
- Added Hebrew coverage for system diagnostic categories, built-in manual navigation, and the user actions that require BIOS or Windows configuration.
- Added explicit allowlist and Hebrew-text assertions for the new manual phrases.


## Data directories and feedback guidance
- Added Hebrew translations for the data-directory table, reset-data warning, diagnostic-report instructions, and manual print action.
- Added validation that each phrase exists in the dictionary, is Hebrew, and is included in the dedicated manual allowlist.


## Quick start and data-directory guide
- Expanded Hebrew coverage for the 30-second product overview, APK installation flow, per-app desktop shortcuts, native windows, file sharing, and data-directory labels.
- Added validation for all newly reviewed manual phrases in both the translation dictionary and the dedicated allowlist.
