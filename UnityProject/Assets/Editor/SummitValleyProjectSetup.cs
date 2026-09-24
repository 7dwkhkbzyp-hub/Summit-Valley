#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEditor.SceneManagement;
using System.IO;

namespace SummitValley.EditorTools {
 public static class SummitValleyProjectSetup {
  [MenuItem("Summit Valley/Build Prototype Scene")]
  public static void BuildScene(){
   var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
   var root=new GameObject("SUMMIT VALLEY");
   root.AddComponent<SummitValleyBootstrap>();
   var dir="Assets/Scenes";if(!Directory.Exists(dir))Directory.CreateDirectory(dir);
   EditorSceneManager.SaveScene(scene,dir+"/SummitValley.unity");
   AssetDatabase.SaveAssets();AssetDatabase.Refresh();
   Debug.Log("Summit Valley scene created. Press Play to preview.");
  }

  [MenuItem("Summit Valley/Build WebGL")]
  public static void BuildWebGL(){
   if(!Directory.Exists("../WebGLBuild"))Directory.CreateDirectory("../WebGLBuild");
   var options=new BuildPlayerOptions{
    scenes=new[]{"Assets/Scenes/SummitValley.unity"},
    locationPathName="../WebGLBuild",
    target=BuildTarget.WebGL,
    options=BuildOptions.None
   };
   BuildPipeline.BuildPlayer(options);
  }
 }
}
#endif
