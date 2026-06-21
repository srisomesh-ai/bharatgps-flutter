# Adding custom alert sounds

Place short sound files (1–5 seconds) into:
  android/app/src/main/res/raw/

Required files (lowercase, no spaces, letters/numbers/underscore only):
  siren.mp3
  horn.mp3
  chime.mp3
  alarm.mp3
  beep.mp3

Rules (Android resource naming):
- Only lowercase a-z, 0-9, underscore in the filename
- Extension: .mp3, .ogg, or .wav
- No README or .txt files in res/raw (the build will reject them)

"Default" uses the system sound and needs no file.
The app creates a notification channel for each sound automatically.

Free sources: notificationsounds.com, mixkit.co/free-sound-effects
