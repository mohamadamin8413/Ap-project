🎵 AP Project (Music App)
A simple music management application that allows users to add local songs and manage playlists offline. The project includes song listing, playlist management, and a clean music player interface.

📌 Features

🎶 Add songs from device storage (Local)
📂 Manage and display playlists
🎵 Play songs with a clean music player interface
🔍 Search songs by title or artist
📱 Offline functionality for local music playback


📷 Screenshots
Ensure screenshots are in PNG format, 24-bit depth, with a recommended resolution of 1080x1920 or an aspect ratio of 9:16 to comply with Google Play requirements. Avoid transparency and use tools like GIMP or Photoshop to convert images if needed. If screenshots are not displaying, verify the file paths and ensure the images are in the repository's root directory or a designated screenshots folder.
Songs Page


Playlist Page


Music Player


Note: If screenshots fail to display, ensure the files exist in the ./screenshots/ directory and are correctly named. For Google Play uploads, convert images to JPEG if PNG issues persist.

🚀 Installation & Setup

Clone the repository:git clone https://github.com/mohamadamin8413/Ap-project.git


Navigate into the project folder:cd Ap-project


Open the project in Android Studio (or your preferred IDE).
Add the following dependencies to pubspec.yaml:dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.1.0
  on_audio_query: ^3.0.0
  just_audio: ^0.9.34
  flutter_spinkit: ^5.2.0
  path_provider: ^2.1.0


Ensure the following permissions are added to AndroidManifest.xml:<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>

For iOS, add to Info.plist:<key>NSAppleMusicUsageDescription</key>
<string>We need access to your music library to play songs.</string>


Run flutter pub get to install dependencies.
Build and run the app on an emulator or physical device.


🛠 Branches
This repository contains two main branches:

main → Latest stable version
master → Legacy branch (updates will be merged into main)


📖 Roadmap / Future Improvements

🎨 Improved UI/UX design
🔄 Support for importing/exporting playlists
📊 Song playback history
🎧 Equalizer settings for audio customization


👨‍💻 Developers

mohamadamin8413
MahdiehAbdorrahimi


🛠 Troubleshooting

Screenshots not displaying: Verify the image files exist in the ./screenshots/ directory and match the referenced paths. Ensure they are PNG or JPEG files with no transparency and correct bit depth (24-bit for PNG). Use Android Studio's Screen Capture tool to take screenshots with proper dimensions (e.g., 1080x1920).
Permission issues: Ensure storage permissions are granted on the device. For Android 13+, use READ_MEDIA_AUDIO permission.
Missing songs: Ensure the device has music files in supported formats (e.g., MP3) and that the app has storage access.
