# Dengue Analytics Mobile App v2

High-mark version with Figma-inspired UI, Random Forest prediction, local and global XAI, trend analysis, MOH risk map, notifications, and ranked intervention recommendations.

## Run

Backend first:
```bash
cd backend
.venv\Scripts\activate
python app.py
```

Frontend:
```bash
cd frontend
flutter pub get
flutter run
```

For Android emulator, API URL is already `http://10.0.2.2:5000`.
For real phone, edit `lib/services/api_service.dart` and replace it with your PC IP.
