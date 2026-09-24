using UnityEngine;
namespace SummitValley {
 public class SummitValleyBootstrap:MonoBehaviour {
  public Color sky=new Color(.47f,.70f,.84f),snow=new Color(.92f,.96f,.98f),rock=new Color(.31f,.35f,.37f);
  void Awake(){Application.targetFrameRate=60;Screen.sleepTimeout=SleepTimeout.NeverSleep;var w=new GameObject("SUMMIT VALLEY WORLD");var t=w.AddComponent<SummitTerrain>();t.snowColor=snow;t.rockColor=rock;t.Build();BuildResort(w);BuildLight();var cam=new GameObject("Resort Camera").AddComponent<Camera>();cam.fieldOfView=42;cam.farClipPlane=180;cam.gameObject.AddComponent<SummitCamera>();}
  void BuildResort(GameObject w){BuildLift(w,new Vector3(-3,27),new Vector3(-3,-20),false);BuildLift(w,new Vector3(14,20),new Vector3(14,-19),true);for(int i=0;i<70;i++){float x=((i*31.7f)%100)-50,z=((i*47.3f)%100)-50;if(Mathf.Sqrt(x*x+z*z)<11)continue;var tr=w.GetComponent<SummitTerrain>();if(tr.Height(x,z)>23)continue;var p=GameObject.CreatePrimitive(PrimitiveType.Cylinder);p.transform.position=new Vector3(x,tr.Height(x,z)+.8f,z);p.transform.localScale=new Vector3(.6f,1.6f,.6f);p.GetComponent<Renderer>().material=Mat(i%6==0?new Color(.9f,.25f,.18f):new Color(.08f,.32f,.72f));p.name=i%6==0?"Snowboarder":"Skier";}}
  void BuildLift(GameObject w,Vector3 a,Vector3 b,bool gondola){var g=new GameObject(gondola?"Gondola Lift":"Chairlift");g.transform.SetParent(w.transform);var l=g.AddComponent<SummitLift>();l.a=a;l.b=b;l.gondola=gondola;}
  void BuildLight(){RenderSettings.ambientLight=new Color(.65f,.75f,.82f);RenderSettings.fog=true;RenderSettings.fogColor=sky;RenderSettings.fogDensity=.006f;var s=new GameObject("Alpine Sun").AddComponent<Light>();s.type=LightType.Directional;s.intensity=1.35f;s.transform.rotation=Quaternion.Euler(48,-35,0);}
  Material Mat(Color c){var m=new Material(Shader.Find("Standard"));m.color=c;return m;}
 }
}