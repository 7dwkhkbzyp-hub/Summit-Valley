using UnityEngine;
namespace SummitValley {
 public class SummitValleyBootstrap:MonoBehaviour {
  public Color sky=new Color(.47f,.70f,.84f),snow=new Color(.92f,.96f,.98f),rock=new Color(.31f,.35f,.37f);
  void Awake(){Application.targetFrameRate=60;Screen.sleepTimeout=SleepTimeout.NeverSleep;var w=new GameObject("SUMMIT VALLEY WORLD");var t=w.AddComponent<SummitTerrain>();t.snowColor=snow;t.rockColor=rock;t.Build();BuildResort(w,t);BuildLight();var cam=new GameObject("Resort Camera").AddComponent<Camera>();cam.fieldOfView=42;cam.farClipPlane=180;cam.gameObject.AddComponent<SummitCamera>();}
  void BuildResort(GameObject w,SummitTerrain t){
   AddPiste(w,t,new[]{new Vector3(-18,0,18),new Vector3(-13,0,7),new Vector3(-8,0,-10)},Color.green,"Green Piste");
   AddPiste(w,t,new[]{new Vector3(8,0,20),new Vector3(5,0,8),new Vector3(1,0,-14)},new Color(.12f,.42f,1),"Blue Piste");
   AddPiste(w,t,new[]{new Vector3(17,0,17),new Vector3(13,0,5),new Vector3(9,0,-16)},Color.red,"Red Piste");
   AddPiste(w,t,new[]{new Vector3(-3,0,26),new Vector3(-2,0,10),new Vector3(-4,0,-19)},Color.white,"Black Piste");
   BuildLift(w,new Vector3(-3,27),new Vector3(-3,-20),false);BuildLift(w,new Vector3(14,20),new Vector3(14,-19),true);
   SummitBuildings.Chalet(new Vector3(-3,29),1.2f,t,"Main Alpine Lodge");SummitBuildings.Chalet(new Vector3(10,27),.85f,t,"Mountain Cafe");SummitBuildings.Chalet(new Vector3(22,17),.75f,t,"Hotel");
   for(int i=0;i<70;i++){float x=((i*31.7f)%100)-50,z=((i*47.3f)%100)-50;if(Mathf.Sqrt(x*x+z*z)<11||t.Height(x,z)>23)continue;var p=GameObject.CreatePrimitive(PrimitiveType.Cylinder);p.name=i%6==0?"Snowboarder":"Skier";p.transform.position=new Vector3(x,t.Height(x,z)+.75f,z);p.transform.localScale=new Vector3(.32f,.9f,.32f);p.GetComponent<Renderer>().material=Mat(i%6==0?new Color(.9f,.25f,.18f):new Color(.08f,.32f,.72f));var guest=p.AddComponent<SummitGuest>();guest.index=i;guest.snowboarder=i%6==0;}
  }
  void AddPiste(GameObject w,SummitTerrain t,Vector3[] p,Color c,string name){var g=new GameObject(name);g.transform.SetParent(w.transform);var q=g.AddComponent<SummitPiste>();q.points=p;q.color=c;q.Build(t);}
  void BuildLift(GameObject w,Vector3 a,Vector3 b,bool gondola){var g=new GameObject(gondola?"Gondola Lift":"Chairlift");g.transform.SetParent(w.transform);var l=g.AddComponent<SummitLift>();l.a=a;l.b=b;l.gondola=gondola;}
  void BuildLight(){RenderSettings.ambientLight=new Color(.65f,.75f,.82f);RenderSettings.fog=true;RenderSettings.fogColor=sky;RenderSettings.fogDensity=.006f;var s=new GameObject("Alpine Sun").AddComponent<Light>();s.type=LightType.Directional;s.intensity=1.35f;s.transform.rotation=Quaternion.Euler(48,-35,0);}
  Material Mat(Color c){var m=new Material(Shader.Find("Standard"));m.color=c;return m;}
 }
}