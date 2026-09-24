using UnityEngine;
namespace SummitValley {
 public class SummitLift:MonoBehaviour {
  public Vector3 a,b; public bool gondola; public float offset;
  void Start(){for(int i=0;i<9;i++){float t=i/8f;Vector3 p=Vector3.Lerp(a,b,t);p.y=FindY(p)+2.5f;var q=GameObject.CreatePrimitive(PrimitiveType.Cylinder);q.transform.SetParent(transform);q.transform.position=p;q.transform.localScale=new Vector3(.22f,2.5f,.22f);q.GetComponent<Renderer>().material=Mat(new Color(.07f,.09f,.11f));}var cable=new GameObject("Cable").AddComponent<LineRenderer>();cable.positionCount=24;cable.startWidth=.08f;cable.endWidth=.08f;cable.material=Mat(new Color(.03f,.04f,.05f));for(int i=0;i<24;i++){float t=i/23f;Vector3 p=Vector3.Lerp(a,b,t);p.y=FindY(p)+5.1f-1.2f*Mathf.Sin(t*Mathf.PI);cable.SetPosition(i,p);}for(int i=0;i<10;i++){var q=GameObject.CreatePrimitive(PrimitiveType.Cube);q.transform.SetParent(transform);q.transform.localScale=gondola?new Vector3(.9f,.55f,.75f):new Vector3(1,.16f,.42f);q.GetComponent<Renderer>().material=Mat(gondola?new Color(.85f,.9f,.92f):new Color(.12f,.14f,.16f));var c=q.AddComponent<SummitLiftCarrier>();c.a=a;c.b=b;c.offset=i/10f;}}
  float FindY(Vector3 p){return FindObjectOfType<SummitTerrain>().Height(p.x,p.z);}
  Material Mat(Color c){var m=new Material(Shader.Find("Standard"));m.color=c;return m;}
 }
}