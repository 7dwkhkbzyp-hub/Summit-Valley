# Unity build instructions

1. Open the `UnityProject` folder in Unity 2022.3 LTS.
2. Let Unity import the scripts.
3. In the Unity menu choose **Summit Valley → Build Prototype Scene**.
4. Open `Assets/Scenes/SummitValley.unity`.
5. Press Play to preview.
6. For browser testing install **WebGL Build Support** in Unity Hub.
7. Choose **Summit Valley → Build WebGL**.

Unity's official documentation confirms WebGL builds are made through File > Build Settings / WebGL and require the WebGL Build Support module. The generated WebGL folder must be hosted by a web server; it cannot simply be opened as a local file.

For the iPhone test, upload the complete generated WebGL build to GitHub Pages or another HTTPS host.

Note: Unity documents WebGL primarily for desktop browsers and does not officially support mobile WebGL, so iPhone Safari compatibility must be tested on the target device.